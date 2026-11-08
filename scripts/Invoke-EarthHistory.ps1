#requires -Version 7.0
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
 [string]$Proxy,
 [string]$GdalInfo='gdalinfo'
)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$command=Get-Command $Executable -ErrorAction Stop | Select-Object -First 1
$Executable=$command.Source
if (@($South,$West,$North,$East).Where({[double]::IsNaN($_) -or [double]::IsInfinity($_)}).Count -or $South -ge $North -or $West -ge $East -or $South -lt -90 -or $North -gt 90 -or $West -lt -180 -or $East -gt 180) { throw 'Invalid bounding box; split antimeridian-crossing regions.' }
if ($Mode -eq 'Download') {
 if (!$Date) { throw 'Download requires Date (yyyy/MM/dd).' }
 $parsedDate=[datetime]::ParseExact($Date,'yyyy/MM/dd',[cultureinfo]::InvariantCulture)
 $GdalInfo=(Get-Command $GdalInfo -ErrorAction Stop | Select-Object -First 1).Source
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory=(Resolve-Path -LiteralPath $OutputDirectory).Path
$names=@('HTTP_PROXY','HTTPS_PROXY','GEHistoricalImagery_Cache')
$old=@{}
foreach ($name in $names) { $old[$name]=[Environment]::GetEnvironmentVariable($name,'Process') }
try {
 if ($PSBoundParameters.ContainsKey('Proxy')) { $env:HTTP_PROXY=$Proxy; $env:HTTPS_PROXY=$Proxy }
 $env:GEHistoricalImagery_Cache=Join-Path $OutputDirectory 'cache'
 $culture=[cultureinfo]::InvariantCulture
 $sw=$South.ToString($culture)+','+$West.ToString($culture)
 $ne=$North.ToString($culture)+','+$East.ToString($culture)
 $common=@("--lower-left=$sw","--upper-right=$ne","--zoom=$Zoom",'--parallel=4')
 if ($Mode -eq 'Query') {
  $target=Join-Path $OutputDirectory 'availability.geojson'
  if (Test-Path -LiteralPath $target) { throw 'Availability output already exists; use a new output directory.' }
  $global:LASTEXITCODE=0
  & $Executable availability @common "--output=$target" -q 2>&1 | Tee-Object -FilePath (Join-Path $OutputDirectory 'availability.log')
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $target)) { throw 'Availability failed; inspect log.' }
  $data=Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
  if ($data.type -ne 'FeatureCollection' -or $null -eq $data.features) { throw 'Invalid availability GeoJSON.' }
  $data.features | ForEach-Object { $_.properties } | Sort-Object image_date -Descending | Export-Csv (Join-Path $OutputDirectory 'dates.csv') -NoTypeInformation -Encoding utf8
 } else {
  $target=Join-Path $OutputDirectory ('Earth_'+$parsedDate.ToString('yyyyMMdd')+"_z$Zoom.tif")
  if (Test-Path -LiteralPath $target) { throw 'Image output already exists; use a new output directory.' }
  $global:LASTEXITCODE=0
  & $Executable download @common "--date=$Date" --exact-date --co=COMPRESS=LZW --co=PHOTOMETRIC=RGB "--output=$target" 2>&1 | Tee-Object -FilePath (Join-Path $OutputDirectory 'download.log')
  if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $target)) { throw 'Download/save failed; inspect log.' }
  $global:LASTEXITCODE=0
  $metadata=& $GdalInfo -json $target 2> (Join-Path $OutputDirectory 'gdalinfo.log')
  if ($LASTEXITCODE -ne 0) { throw 'GDAL could not open the output.' }
  $info=($metadata -join "`n") | ConvertFrom-Json
  if ($info.size.Count -ne 2 -or $info.size[0] -le 0 -or $info.size[1] -le 0 -or !$info.coordinateSystem.wkt -or $info.geoTransform.Count -ne 6 -or $info.bands.Count -lt 3) { throw 'Missing raster dimensions, RGB bands or georeferencing.' }
  [pscustomobject]@{File=$target;Width=$info.size[0];Height=$info.size[1];Bytes=(Get-Item -LiteralPath $target).Length;Bands=$info.bands.Count;CRS=$info.coordinateSystem.wkt;GeoTransform=$info.geoTransform;Validation='GDAL metadata open; pixel coverage and completeness require separate checks'} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $OutputDirectory 'verification.json') -Encoding utf8
 }
} finally {
 foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$old[$name],'Process') }
}
