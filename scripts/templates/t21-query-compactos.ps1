# 模板 21：query-compactos（v2.1：默认只查询；启用 / 回退需 -Apply 且管理员）
# 用法：
#   .\t21-query-compactos.ps1                    # 只读查询当前状态
#   .\t21-query-compactos.ps1 -Enable            # 演练：说明将执行什么，不改动
#   .\t21-query-compactos.ps1 -Enable -Apply     # 管理员 + 用户明确同意后：启用 CompactOS（/compactos:always）
#   .\t21-query-compactos.ps1 -Disable -Apply    # 回退为未压缩（/compactos:never）
# 能省多少因机器而异（微软在测试镜像上约 2.75–3.7 GB，不是保证值）；对性能通常影响很小，
# 低速 CPU 或机械硬盘上可能略慢。只在 C 盘确实紧张、用户同意后做（MEDIUM）。
# 依据：https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os
param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Apply
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# 1. 查询系统当前 CompactOS 压缩状态（纯只读）
function Get-CompactOSState {
    Write-Host "=== CompactOS 状态查询（只读）===" -ForegroundColor Cyan
    if (-not (Test-WcoAdmin)) { Write-Host '  提示：部分系统上查询也需要管理员；若下方报拒绝访问，请以管理员身份重试。' }
    compact.exe /compactos:query
}

# 2/3. 启用或回退（改系统状态，仅在 -Apply 且管理员时执行）
function Set-CompactOSState {
    param([ValidateSet('always', 'never')][string]$Mode, [switch]$Apply)
    $cmd = "compact.exe /compactos:$Mode"
    $undoMode = if ($Mode -eq 'always') { 'never' } else { 'always' }
    if ($Apply) {
        if (-not (Test-WcoAdmin)) {
            Write-Host "[Blocked] 需要以管理员身份运行，未执行：$cmd" -ForegroundColor Red
            return
        }
        Write-Host "=== 正在执行：$cmd（耗时约 3-10 分钟）===" -ForegroundColor Yellow
        compact.exe "/compactos:$Mode"
        if ($LASTEXITCODE -eq 0) {
            [void](Add-WcoChange -Kind other -Target 'CompactOS' -After $Mode -Undo "compact.exe /compactos:$undoMode" -Risk MEDIUM -Note 'CompactOS 状态切换')
            Write-Host "变更记录：$((Get-WcoSession).Ledger)"
            Write-Host "回退脚本：$(Export-WcoUndo)"
        } else {
            Write-Host "[Failed] compact.exe 退出码 $LASTEXITCODE" -ForegroundColor Red
        }
    } else {
        Write-Host "[DryRun] 将执行：$cmd（撤销：compact.exe /compactos:$undoMode）。未做任何改动；确认后加 -Apply 并以管理员身份运行。" -ForegroundColor Cyan
    }
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host '仅支持 Windows。' -ForegroundColor Red
} else {
    Get-CompactOSState
    if ($Enable -and $Disable) { Write-Host '-Enable 与 -Disable 不能同时使用。' -ForegroundColor Red }
    elseif ($Enable) { Set-CompactOSState -Mode always -Apply:$Apply }
    elseif ($Disable) { Set-CompactOSState -Mode never -Apply:$Apply }
    elseif ($Apply) { Write-Host '-Apply 需与 -Enable 或 -Disable 搭配；本次只做了查询。' }
}
