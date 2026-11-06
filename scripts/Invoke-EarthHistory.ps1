[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Executable,
 [Parameter(Mandatory)][double]$South,
 [Parameter(Mandatory)][double]$West,
 [Parameter(Mandatory)][double]$North,
 [Parameter(Mandatory)][double]$East,
 [ValidateRange(1,23)][int]$Zoom=18,
 [Parameter(Mandatory)][string]$OutputDirectory,
 [ValidateSet('Query','Download')][string]$Mode='Query',
 [string]$Date,
 [string]$Proxy=''
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $Executable -PathType Leaf)) { throw 'Executable not found.' }
if ($South -ge $North -or $West -ge $East -or $South -lt -90 -or $North -gt 90 -or $West -lt -180 -or $East -gt 180) { throw 'Invalid bounding box.' }
if ($Mode -eq 'Download') {
 if (!$Date) { throw 'Download requires Date (yyyy/MM/dd).' }
 $parsedDate=[datetime]::ParseExact($Date,'yyyy/MM/dd',[cultureinfo]::InvariantCulture)
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$base=Split-Path -Parent (Resolve-Path -LiteralPath $Executable).Path
$names=@('HTTP_PROXY','HTTPS_PROXY','GDAL_DATA','PROJ_LIB','GEHistoricalImagery_Cache')
$old=@{}
foreach ($name in $names) { $old[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
try {
 $env:HTTP_PROXY=$Proxy; $env:HTTPS_PROXY=$Proxy
 $env:GDAL_DATA=$base; $env:PROJ_LIB=$base
 $env:GEHistoricalImagery_Cache=Join-Path $OutputDirectory 'cache'
 $culture=[cultureinfo]::InvariantCulture
 $sw=$South.ToString($culture)+','+$West.ToString($culture)
 $ne=$North.ToString($culture)+','+$East.ToString($culture)
 $common=@("--lower-left=$sw","--upper-right=$ne","--zoom=$Zoom",'--parallel=4')
 if ($Mode -eq 'Query') {
  $target=Join-Path $OutputDirectory 'availability.geojson'
  if (Test-Path -LiteralPath $target) { throw 'Availability output already exists; use a new output directory.' }
  & $Executable availability @common "--output=$target" -q 2>&1 | Tee-Object -FilePath (Join-Path $OutputDirectory 'availability.log')
  if (!(Test-Path -LiteralPath $target)) { throw 'No availability output produced.' }
  $features=(Get-Content -LiteralPath $target -Raw | ConvertFrom-Json).features
  $features | ForEach-Object { $_.properties } | Sort-Object image_date -Descending | Export-Csv (Join-Path $OutputDirectory 'dates.csv') -NoTypeInformation -Encoding utf8
 } else {
  $target=Join-Path $OutputDirectory ('Earth_'+$parsedDate.ToString('yyyyMMdd')+"_z$Zoom.tif")
  if (Test-Path -LiteralPath $target) { throw 'Image output already exists; use a new output directory.' }
  & $Executable download @common "--date=$Date" --exact-date --co=COMPRESS=LZW --co=PHOTOMETRIC=RGB "--output=$target" 2>&1 | Tee-Object -FilePath (Join-Path $OutputDirectory 'download.log')
  $log=Get-Content -LiteralPath (Join-Path $OutputDirectory 'download.log') -Raw
  if ($log -match 'An error occurred|GDAL Failure' -or !(Test-Path -LiteralPath $target)) { throw 'Download/save failed; inspect log.' }
  Add-Type -AssemblyName System.Drawing
  $image=[System.Drawing.Image]::FromFile($target)
  try { [pscustomobject]@{File=$target;Width=$image.Width;Height=$image.Height;Bytes=(Get-Item -LiteralPath $target).Length;GeoTagsPresent=($image.PropertyIdList -contains 34735)} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'verification.json') -Encoding utf8 } finally { $image.Dispose() }
 }
} finally {
 foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$old[$name],'Process') }
}

