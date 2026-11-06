# Platform setup

The skill instructions work on Windows, macOS and Linux. Actual imagery execution requires a compatible upstream client and native GDAL runtime. Check the current [upstream release assets and build instructions](https://github.com/Mbucari/GEHistoricalImagery); match OS and CPU (x64/arm64), and never assume every combination has a prebuilt package.

| Platform | Runtime setup |
| --- | --- |
| Windows | Use a compatible upstream Windows package. Invoke its executable directly. For the helper, install PowerShell 7 and make gdalinfo available on PATH. |
| macOS | Check Intel/Apple Silicon compatibility. Use an upstream package when available or follow upstream source-build instructions with GDAL installed through a compatible package environment. |
| Linux | Check CPU and glibc/musl compatibility. Use an appropriate upstream package or build from source with native GDAL dependencies. Headless operation is supported by the workflow. |

GDAL can be supplied by the OS package manager or a conda-forge environment. Avoid mixing GDAL binaries, PROJ libraries and data from different installations. Verify `gdalinfo --version` and the client's `--help` before network work. Preserve existing GDAL_DATA, PROJ_DATA and PROJ_LIB; configure missing data paths only after identifying the installation layout. On Unix, grant execute permission to a downloaded client only when required and authorized.

## Native CLI (any platform)

Run these single-line argument lists with the installed executable name or quoted path; PowerShell paths need its `&` call operator. Unix shells can invoke the executable directly.

```text
GEHistoricalImagery availability --lower-left=39.89883,116.39156 --upper-right=39.90783,116.40326 --zoom=18 --parallel=4 --output=availability.geojson -q
GEHistoricalImagery download --lower-left=39.89883,116.39156 --upper-right=39.90783,116.40326 --zoom=18 --parallel=4 --date=2024/12/07 --exact-date --co=COMPRESS=LZW --co=PHOTOMETRIC=RGB --output=earth.tif
gdalinfo -json earth.tif
```

The date above illustrates syntax; query availability first. Confirm CLI options against the installed version. Use new output paths and preserve logs. Configure HTTP_PROXY/HTTPS_PROXY in the process environment only when needed.

## Optional PowerShell helper (all three platforms)

```text
pwsh -NoProfile -File scripts/Invoke-EarthHistory.ps1 -Executable GEHistoricalImagery -South 39.89883 -West 116.39156 -North 39.90783 -East 116.40326 -OutputDirectory outputs/query
pwsh -NoProfile -File scripts/Invoke-EarthHistory.ps1 -Executable GEHistoricalImagery -South 39.89883 -West 116.39156 -North 39.90783 -East 116.40326 -OutputDirectory outputs/download -Mode Download -Date 2024/12/07
```

Use `-Executable` with the actual executable or PATH command, `-GdalInfo` for a custom gdalinfo location, and `-Proxy` only to override inherited settings. Rectangles crossing the antimeridian must be split. Helper validation opens raster metadata; verify pixels, tile completeness and masks separately.
