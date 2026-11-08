# Google Earth 历史影像工作流技能

先查询目标区域有哪些历史影像日期，再按指定日期下载并整理为有地理参考的 GeoTIFF。这个 agent skill 将 [GEHistoricalImagery](https://github.com/Mbucari/GEHistoricalImagery) 命令行工具融入 Codex、Pi 等支持技能的助手工作流，帮助用户从影像可用性检查走到可核验的下载结果。

它适合需要快速检查历史影像日期、下载一处或多处区域影像、制作多期对照底图，或将结果交给 Python GIS 流程继续处理的遥感与地理信息任务。技能提供任务判断、命令调用和结果核验步骤；实际影像查询及下载由上游客户端和影像服务完成。

## 什么时候选 Google Earth 历史影像

当你需要先回答“这个位置有哪些日期可选”，再选择某个日期下载时，这个工作流很合适。影像覆盖和日期取决于具体位置、地图级别及上游索引；输入一个日期不代表每个瓦片都有该日数据。默认日期匹配还可能选择邻近日期，因此需要严格多期对比时，应使用精确日期选项并检查下载日志、瓦片完整性与影像分辨率。

常见任务包括：

- 查询研究区在指定地图级别下的历史影像日期与覆盖情况。
- 下载指定日期的影像并拼接为带空间参考的 GeoTIFF。
- 对多个日期分别下载，检查缺失瓦片后进行变化对比。
- 将区域影像输出到 Python GIS 或遥感分析流程中，并保留日期与来源记录。

如果任务重点是按 Esri World Imagery Wayback 发布版本筛选底图，或需要估算 Wayback 元数据中的拍摄年份覆盖，可同时查看 [`esri-wayback-download`](https://github.com/UWPK/esri-wayback-download)。两者数据来源和日期含义不同；组合使用时请分别记录来源、日期及补洞情况。

## 工作流程

- 确认区域范围、日期需求、地图级别、输出目录和是否需要严格匹配日期。
- 检查本机对应操作系统和 CPU 架构的 GEHistoricalImagery 客户端及 GDAL 运行环境；安装器可为支持的平台获取匹配的上游客户端。
- 运行 `availability` 查询，保存 GeoJSON 并检查日期、级别、来源与完整性字段。索引记录表示有可用性线索，不代表下载已成功。
- 根据查询结果选择日期。需要严格对比时使用 `--exact-date`；若接受邻近日期替代，应在结果说明中标明。检查日志中是否有缺瓦片或较低级别替代。
- 运行 `download` 下载并拼接 GeoTIFF，保留命令输出和日志。解码后的 RGB 无损压缩需同时指定 `COMPRESS=LZW` 和 `PHOTOMETRIC=RGB`；这不会消除上游 JPEG 图像已有的压缩损失。
- 检查输出文件是否存在、可读取、空间参考和仿射变换是否合理，并核对预期瓦片数、缺块和预览图。
- 汇报查询日期数量、实际下载结果、使用日期、级别、坐标范围、空间信息检查和未覆盖部分。

## 使用方式

在支持 agent skills 的助手中安装本仓库的技能目录，开启新会话后说明区域、想检查或下载的日期、输出位置和精度要求。例如：

> 查询这个区域在 2018 到 2022 年间可用的 Google Earth 历史影像日期，输出日期清单。对比前先确认每个日期的瓦片覆盖；下载 2020 年 6 月 15 日的精确日期版本，保留日志并检查 GeoTIFF 的 CRS、范围和缺块。

先查询可用日期，再下载小范围样本，是确认服务访问与结果质量的推荐起点。技能入口见 [`SKILL.md`](SKILL.md)，平台与命令参数示例见[跨平台配置](references/platforms.md)。原生 CLI 不需要 PowerShell；仓库也保留可选的 PowerShell 7 辅助脚本。

## 安装运行环境

完整克隆或下载仓库后，准备 Python 3.10+，在仓库目录执行：

```bash
# macOS / Linux
python3 scripts/setup.py

# Windows（也可使用 python scripts/setup.py）
py -3 scripts/setup.py
```

安装器创建仓库内的独立 Python 环境，安装 GeoTIFF 检查依赖，并实际执行小型 GeoTIFF 读写测试；它也会为支持的系统和处理器架构下载上游客户端、核对发布包 SHA-256，并检查客户端能否启动。安装结果写入 `local-runtime.json`。`.venv`、`.runtime` 和该本机文件不可提交或复制到别的电脑；在每台电脑上分别运行安装器。

安装需要网络连接和所选目录的写入权限。安装器保留 TLS 验证，不会关闭 macOS 系统安全功能。Google Earth 下载由第三方客户端访问上游服务完成；Windows ARM64 当前没有对应的原生上游发布包，安装器会明确报告不支持，而不会自动选用其他架构版本。完整安装参数见 `python scripts/setup.py --help`。

## 命令行示例

以下示例展示调用格式。请先根据实际区域查询可用日期，并用安装后验证过的客户端路径替换 `GEHistoricalImagery`：

```bash
GEHistoricalImagery availability \
  --lower-left=39.89883,116.39156 \
  --upper-right=39.90783,116.40326 \
  --zoom=18 --parallel=4 --output=availability.geojson -q

GEHistoricalImagery download \
  --lower-left=39.89883,116.39156 \
  --upper-right=39.90783,116.40326 \
  --zoom=18 --parallel=4 --date=2024/12/07 --exact-date \
  --co=COMPRESS=LZW --co=PHOTOMETRIC=RGB --output=earth.tif

gdalinfo -json earth.tif
```

命令中的日期仅用于展示参数格式，不能据此推断该区域存在相应影像。请先检查 availability 输出，并确认已安装版本支持所用参数。对边界多边形可使用上游 CLI 支持的区域文件；可选 PowerShell 辅助脚本当前面向矩形范围。

## 产出与核验

工作流通常生成可用日期 GeoJSON、带空间参考的 GeoTIFF、运行日志和检查摘要。根据任务，还可生成地图预览、多个日期的独立影像以及缺失瓦片记录。索引条目数、成功下载图像数和区域覆盖率是不同指标，应分开报告。

元数据可读取只是必要检查的一部分。对完整交付还应检查像元是否可读、坐标系与范围、请求的地图级别、每日期瓦片完整性、邻近日期替代和低级别回退。技能不能仅凭 HTTP 成功状态或 GeoTIFF 文件存在就认定影像完整。

## 数据使用与边界

本项目依赖第三方客户端及其访问的上游历史影像服务，不代表 Google 官方 API，也不承诺服务接口、覆盖范围、历史日期或下载配额稳定。Google Pro 会员不是上游工具文档所列的必要条件，但实际访问仍受服务状态、网络、区域覆盖及适用条款约束。请勿将索引日期等同于全区完整影像日期，也勿将地图级别直接等同于原始传感器分辨率。

影像通常是已解码的 RGB 底图，不应描述为原始传感器数据或辐射定标产品。公开展示、再分发和研究使用前，请核对影像提供方与上游服务的最新条款，并保留要求的来源署名。第三方客户端遵循其自己的许可。

**项目代码与文档采用 MIT License，版权声明为 UWPK。**许可证仅适用于本仓库中由项目维护者创作并有权许可的代码与文档，不包括 Google Earth 影像、任何影像瓦片、上游服务、GEHistoricalImagery 客户端或其他第三方材料。影像和服务的使用、署名、展示及再分发仍须遵守各自权利人的条款；本项目不授予这些内容的额外权利。

## 平台与验证

自动安装与运行检查已覆盖 Windows x64、macOS Apple Silicon 和 Intel Mac。维护环境完成过一次小范围在线查询、精确日期单瓦片下载及 GeoTIFF 读取验证；这不是对所有地区、日期、网络环境或大范围下载的保证。Linux 可按照上游客户端与 GDAL 的系统/架构兼容性要求配置，需自行确认运行依赖。Windows ARM64 当前缺少上游原生发布包。

## 相关链接

- [技能入口与任务规则](SKILL.md)
- [跨平台安装与命令示例](references/platforms.md)
- [上游 GEHistoricalImagery 项目](https://github.com/Mbucari/GEHistoricalImagery)
- [Google Earth 历史影像技能的 Esri Wayback 伙伴项目](https://github.com/UWPK/esri-wayback-download)