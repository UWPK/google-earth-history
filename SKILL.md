---
name: google-earth-history
description: Query and download dated Google Earth historical imagery as georeferenced GeoTIFF with GEHistoricalImagery. Use for historical satellite or aerial images, date coverage checks, and multi-date change comparisons.
---

# Google Earth historical imagery

Use Mbucari/GEHistoricalImagery to query dated coverage and download tiles into GeoTIFF. Google Pro membership is not a documented prerequisite. This is a third-party client; successful downloads depend on service access and data coverage.

## Setup

Install PowerShell 7 and obtain GEHistoricalImagery from upstream releases. Supply the executable path, writable output directory, and optional proxy explicitly.

## Workflow

1. Confirm or infer area, requested dates, level, and output directory. State assumed location. Distinguish a radius circle from a square extending the radius in four directions.
2. Reuse the verified executable when available. Otherwise query GitHub latest release, download Windows x64 ZIP with PowerShell, and expand under the user's workspace tools directory. Do not overwrite an existing installation silently.
3. Set GDAL_DATA and PROJ_LIB to the executable directory; set GEHistoricalImagery_Cache to a writable cache. Invoke the executable directly from PowerShell, avoiding its batch wrapper.
4. Run `availability` at the requested level, write GeoJSON, inspect feature properties `image_date`, `zoom_level`, `provider`, `iscomplete`. An index record is only availability evidence.
5. Pick an available date according to user intent. Use `--exact-date` for dated comparisons. Default nearest-date matching can substitute dates; document any deliberate substitution. Missing tiles may also use lower levels; inspect logs and coverage before claiming full-resolution completion.
6. Run `download`, preserve logs, require all expected tiles and successful save. For lossless storage of decoded RGB use BOTH `--co=COMPRESS=LZW --co=PHOTOMETRIC=RGB`. Setting only LZW fails with the default YCbCr setting. This does not reverse source JPEG loss.
7. Check actual TIFF exists and decodes, record dimensions and georeferencing; create a preview if practical. Report index counts separately from downloaded images, requested zoom separately from native source resolution. Retain a failed artifact marked incomplete if one was created.

Use `scripts/Invoke-EarthHistory.ps1` for repeatable queries and downloads. It requires an existing executable, explicit bounding coordinates, and a unique output directory; Query only queries, Download requires a date. For polygons use upstream `--region-file` KML/KMZ; the helper implements rectangles only.

## Mechanism and limits

The client queries the Google Earth historical imagery index, resolves dated tiles covering the area at a given level, downloads and decodes them, mosaics them, and uses GDAL to write georeferencing and optionally reproject. Avoid promising a supported public Google API or service stability. HTTP 200 alone does not establish valid image data. CLI zoom accepts 1-23; upstream docs say Google Earth practically caps at 21 and Wayback at 20. Actual date/level coverage varies. Retain source attribution and assess applicable imagery permissions for publication or redistribution.

Upstream references:
- https://github.com/Mbucari/GEHistoricalImagery
- https://github.com/Mbucari/GEHistoricalImagery/blob/master/docs/availability.md
- https://github.com/Mbucari/GEHistoricalImagery/blob/master/docs/download.md

