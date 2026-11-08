#requires -Version 7.0
$ErrorActionPreference='Stop'
$helper=Join-Path $PSScriptRoot '../scripts/Invoke-EarthHistory.ps1'
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('earth-history-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$fake=Join-Path $testRoot 'fake-client.ps1'
@'
$target=($args | Where-Object { $_ -like '--output=*' }) -replace '^--output=',''
if ($env:EARTH_TEST_FAIL -eq '1') { $global:LASTEXITCODE=7; return }
if ($args[0] -eq 'availability') {
 '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"image_date":"2024-12-07"},"geometry":null}]}' | Set-Content -LiteralPath $target
} else { 'fixture' | Set-Content -LiteralPath $target }
$global:LASTEXITCODE=0
'@ | Set-Content -LiteralPath $fake
$gdal=Join-Path $testRoot 'fake-gdal.ps1'
@'
'{"size":[256,256],"coordinateSystem":{"wkt":"EPSG:4326"},"geoTransform":[0,1,0,1,0,-1],"bands":[{}, {}, {}]}'
$global:LASTEXITCODE=0
'@ | Set-Content -LiteralPath $gdal
$previous=$env:HTTPS_PROXY
$previousFail=$env:EARTH_TEST_FAIL
try {
 $env:EARTH_TEST_FAIL='0'
 $env:HTTPS_PROXY='http://example.invalid:1234'
 $common=@{Executable=$fake;South=0;West=0;North=1;East=1}
 $query=Join-Path $testRoot 'query with spaces'
 & $helper @common -OutputDirectory $query -Proxy 'http://override.invalid:4321'
 if (!(Test-Path -LiteralPath (Join-Path $query 'dates.csv'))) { throw 'Query CSV missing' }
 if ($env:HTTPS_PROXY -ne 'http://example.invalid:1234') { throw 'Proxy not restored' }
 $caught=$false
 try { & $helper @common -OutputDirectory $query } catch { $caught=$true }
 if (!$caught) { throw 'Existing output was overwritten' }
 $download=Join-Path $testRoot 'download'
 & $helper @common -OutputDirectory $download -Mode Download -Date '2024/12/07' -GdalInfo $gdal
 $report=Get-Content -LiteralPath (Join-Path $download 'verification.json') -Raw | ConvertFrom-Json
 if ($report.Width -ne 256 -or $report.Bands -ne 3) { throw 'Raster report invalid' }
 $env:EARTH_TEST_FAIL='1'
 $caught=$false
 try { & $helper @common -OutputDirectory (Join-Path $testRoot 'failed') -Proxy '' } catch { $caught=$true }
 if (!$caught) { throw 'Native failure was not propagated' }
 if ($env:HTTPS_PROXY -ne 'http://example.invalid:1234') { throw 'Proxy not restored after failure' }
 $caught=$false
 try { & $helper @common -OutputDirectory (Join-Path $testRoot 'date') -Mode Download -Date 'invalid' -GdalInfo $gdal } catch { $caught=$true }
 if (!$caught) { throw 'Invalid date accepted' }
 Write-Output 'PASS: query, spaces, overwrite protection, download report, failure propagation, environment restoration, invalid date'
 Write-Output "Fixtures retained at $testRoot"
} finally {
 $env:HTTPS_PROXY=$previous
 $env:EARTH_TEST_FAIL=$previousFail
}
