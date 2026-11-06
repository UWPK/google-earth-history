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
