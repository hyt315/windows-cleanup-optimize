# 模板 22：analyze-winsxs（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 22 节。

# 1. 分析 WinSxS 可回收空间与是否建议清理（纯只读排查）
function Measure-WinSxS {
    Write-Host "=== 正在分析 WinSxS 组件存储库（耗时约 1-3 分钟）===" -ForegroundColor Cyan
    Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
}

# 2. 执行标准安全回收（仅清理被取代的旧版本，保留当前 LCU 回滚能力）
# 🚨 警告：严禁追加 /ResetBase 参数！否则当前所有已安装累积更新将永久无法卸载回退。
function Start-SafeComponentCleanup {
    Write-Host "=== 执行 WinSxS 标准安全清理（安全保留回滚点）===" -ForegroundColor Yellow
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
}
