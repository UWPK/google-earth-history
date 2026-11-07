# google-earth-history

适用于 Windows、macOS 和 Linux 的遥感影像代理技能。

基于 GEHistoricalImagery 查询与下载历史影像。可以直接在原生 shell 调用上游 CLI，也提供适用于三平台的 PowerShell 7 辅助脚本，使用 gdalinfo 验证空间元数据。需要兼容当前操作系统与 CPU 的上游客户端和 GDAL。

## 安装

将仓库内容放入代理支持的技能目录，如 ~/.codex/skills/google-earth-history，保留完整目录结构，再开启新会话。已有同名技能时可使用独立配置环境，避免覆盖。

## 使用

在对话中指定技能名、区域、日期、输出目录和分辨率。代理先检查运行环境和服务可用性。

[技能入口](SKILL.md) · [跨平台配置与示例](references/platforms.md)

## 验证范围

当前维护环境为 Windows。跨平台说明避免固定盘符、Windows 图像组件及固定代理；macOS/Linux 的完整在线影像下载尚需各平台实机验收。

## 数据与署名

影像服务和第三方依赖遵循各自使用条款，保留提供方署名与来源。记录日期含义、覆盖率、缺失情况和验证范围。仓库不附带影像、凭据或第三方可执行程序。

辅助脚本的离线行为测试：pwsh -NoProfile -File tests/Test-Helper.ps1。测试使用模拟客户端和模拟 GDAL，覆盖流程控制；真实影像和 GDAL 读取需另行验收。

## Windows / macOS 自动准备

先安装 Python 3.10+，下载或克隆完整仓库。在仓库目录执行：

```text
python scripts/setup.py
```

macOS 通常使用 `python3 scripts/setup.py`；Windows 可使用 `py -3 scripts/setup.py`。
脚本创建仓库内 `.venv`、安装运行依赖并真实读写小型 GeoTIFF，写出本机 `local-runtime.json`。
这些本机文件不应提交或复制到其他电脑。重复运行复用已有环境。
未指定证书时，使用系统 curl 经 HTTPS 获取 Mozilla CA 包供 pip 使用；不会修改系统证书。
可用 `--plan` 预览，`--env` 指定其他独立环境，`--ca-bundle` 指定可信 CA；不会关闭 TLS 验证。
Python 缺失、无法联网或证书配置有误时会明确失败，需要先修复相应前置条件。

GitHub Actions 会在 Windows x64、macOS Apple Silicon 和 Intel runner 安装真实依赖。
CI 成功只代表安装及运行检查，不证明所有地区/日期的在线影像可用。

Google Earth 安装器还会从上游 v0.7.1 下载匹配架构客户端，核对 Release SHA-256，
保留 GDAL 动态库/数据布局并执行 `--help`。使用 `--client <已有可执行文件>` 可复用安装；
无需 PowerShell。Windows ARM64 暂无原生 Release，安装器会明确停止，不自动选择 x64 模拟。
macOS 如出现系统安全拦截，请按系统正常流程确认官方客户端，不要关闭系统安全功能。
