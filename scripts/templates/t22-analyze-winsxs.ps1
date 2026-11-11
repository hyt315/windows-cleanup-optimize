# 模板 22：analyze-winsxs（v2.1：默认只分析；清理需 -Cleanup -Apply 且管理员）
# 用法：
#   .\t22-analyze-winsxs.ps1                     # 只读分析（DISM /AnalyzeComponentStore，需管理员）
#   .\t22-analyze-winsxs.ps1 -Cleanup            # 演练：说明将执行什么，不改动
#   .\t22-analyze-winsxs.ps1 -Cleanup -Apply     # 管理员 + 用户明确同意后：标准清理 /StartComponentCleanup
# 🚨 严禁 /ResetBase：会让当前已安装的累积更新永久无法卸载回退。本模板不提供、也不接受该参数。
# 标准清理本身不可回退（被取代的旧组件删除后无法恢复），但保留当前更新的卸载能力。
param(
    [switch]$Cleanup,
    [switch]$Apply
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# 1. 分析 WinSxS 可回收空间与是否建议清理（纯只读排查）
function Measure-WinSxS {
    Write-Host "=== 正在分析 WinSxS 组件存储库（只读，耗时约 1-3 分钟）===" -ForegroundColor Cyan
    if (-not (Test-WcoAdmin)) {
        Write-Host '  查询失败（需管理员）：DISM 分析需要以管理员身份运行。' -ForegroundColor Yellow
        return
    }
    Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
}

# 2. 执行标准安全回收（仅清理被取代的旧版本，保留当前 LCU 回滚能力）
function Start-SafeComponentCleanup {
    param([switch]$Apply)
    $cmd = 'Dism.exe /Online /Cleanup-Image /StartComponentCleanup'
    if ($Apply) {
        if (-not (Test-WcoAdmin)) {
            Write-Host "[Blocked] 需要以管理员身份运行，未执行：$cmd" -ForegroundColor Red
            return
        }
        Write-Host "=== 执行 WinSxS 标准安全清理（不带 /ResetBase）===" -ForegroundColor Yellow
        Dism.exe /Online /Cleanup-Image /StartComponentCleanup
        if ($LASTEXITCODE -eq 0) {
            [void](Add-WcoChange -Kind other -Target 'WinSxS StartComponentCleanup' -Risk MEDIUM -Note '被取代的旧组件已删除，无法自动回退；当前累积更新仍可卸载')
            Write-Host "变更记录：$((Get-WcoSession).Ledger)"
        } else {
            Write-Host "[Failed] DISM 退出码 $LASTEXITCODE" -ForegroundColor Red
        }
    } else {
        Write-Host "[DryRun] 将执行：$cmd（不带 /ResetBase）。未做任何改动；确认后加 -Apply 并以管理员身份运行。" -ForegroundColor Cyan
    }
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host '仅支持 Windows。' -ForegroundColor Red
} else {
    Measure-WinSxS
    if ($Cleanup) { Start-SafeComponentCleanup -Apply:$Apply }
    elseif ($Apply) { Write-Host '-Apply 需与 -Cleanup 搭配；本次只做了分析。' }
}
