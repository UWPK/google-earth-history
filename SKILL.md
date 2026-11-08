---
name: google-earth-history
description: Query and download dated Google Earth historical imagery as georeferenced GeoTIFF with GEHistoricalImagery. Use for historical satellite or aerial images, date coverage checks, and multi-date change comparisons.
---

# Google Earth historical imagery

Use Mbucari/GEHistoricalImagery to query dated coverage and download tiles into GeoTIFF. Google Pro membership is not a documented prerequisite. This is a third-party client; successful downloads depend on service access and data coverage.

## Setup

Use Windows, macOS or Linux with a compatible GEHistoricalImagery runtime and GDAL installation. Read [references/platforms.md](references/platforms.md) when installing or changing platforms. Native CLI use needs no PowerShell; the optional helper requires PowerShell 7 on any supported desktop OS. Supply paths and optional proxy explicitly.

## Workflow

- Confirm or infer area, requested dates, level, and output directory. State assumed location. Distinguish a radius circle from a square extending the radius in four directions.
- Reuse the verified executable when available. Otherwise query GitHub latest release, select a release matching the host OS and CPU architecture, and extract under a user-writable tools directory; if no compatible asset exists, follow upstream build instructions and verify native GDAL dependencies before proceeding. Do not overwrite an existing installation silently.
- Preserve the installed GDAL/PROJ environment. Set GDAL_DATA and PROJ_DATA only to actual data directories when runtime discovery requires them; use PROJ_LIB only for legacy installations. Set GEHistoricalImagery_Cache to a writable cache. Invoke the native executable from the available shell without Windows batch wrappers.
- Run `availability` at the requested level, write GeoJSON, inspect feature properties `image_date`, `zoom_level`, `provider`, `iscomplete`. An index record is only availability evidence.
- Pick an available date according to user intent. Use `--exact-date` for dated comparisons. Default nearest-date matching can substitute dates; document any deliberate substitution. Missing tiles may also use lower levels; inspect logs and coverage before claiming full-resolution completion.
- Run `download`, preserve logs, require all expected tiles and successful save. For lossless storage of decoded RGB use BOTH `--co=COMPRESS=LZW --co=PHOTOMETRIC=RGB`. Setting only LZW fails with the default YCbCr setting. This does not reverse source JPEG loss.
- Check actual TIFF exists and decodes, record dimensions and georeferencing; create a preview if practical. Report index counts separately from downloaded images, requested zoom separately from native source resolution. Retain a failed artifact marked incomplete if one was created.

Optionally use the cross-platform PowerShell 7 helper `scripts/Invoke-EarthHistory.ps1` for repeatable queries and downloads. It requires an existing executable, explicit bounding coordinates, and a unique output directory; Query only queries, Download requires a date. For polygons use upstream `--region-file` KML/KMZ; the helper implements rectangles only.

## Mechanism and limits

The client queries the Google Earth historical imagery index, resolves dated tiles covering the area at a given level, downloads and decodes them, mosaics them, and uses GDAL to write georeferencing and optionally reproject. Avoid promising a supported public Google API or service stability. HTTP 200 alone does not establish valid image data. CLI zoom accepts 1-23; upstream docs say Google Earth practically caps at 21 and Wayback at 20. Actual date/level coverage varies. Retain source attribution and assess applicable imagery permissions for publication or redistribution.

Upstream references:
- https://github.com/Mbucari/GEHistoricalImagery
- https://github.com/Mbucari/GEHistoricalImagery/blob/master/docs/availability.md
- https://github.com/Mbucari/GEHistoricalImagery/blob/master/docs/download.md


The helper accepts executable paths or commands on PATH, preserves proxy and GDAL settings, checks native exit codes, and uses gdalinfo JSON for raster structure validation. Download mode requires gdalinfo. Metadata validation does not establish complete pixel coverage.

## Automated Windows/macOS setup

For a fresh installation run `python scripts/setup.py` (macOS often `python3`,
Windows optionally `py -3`). Read generated `local-runtime.json` for the verified
Python and native client paths. Keep `.venv`, `.runtime` and local-runtime.json
local to this machine. Do not copy paths or credentials from another computer.
The setup verifies real GeoTIFF IO and the optional native client's help; follow
with a bounded online availability/download check before claiming data access.
