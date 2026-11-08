# 模板 14：show-power-visual（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 14 节。

# 当前电源计划
powercfg /getactivescheme

# 可用电源计划列表
powercfg /list

# 切换到高性能
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# 启用隐藏的"卓越性能"计划（管理员）
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

# TRIM 检查
fsutil behavior query DisableDeleteNotify

# Defender 排除列表（管理员）
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
