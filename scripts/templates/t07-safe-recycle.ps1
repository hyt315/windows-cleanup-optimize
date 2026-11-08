# 模板 7：safe-recycle（v2.0：改为调用公共模块，默认只演练，加 -Apply 才执行）
# 用法：
#   .\t07-safe-recycle.ps1 -Path "$env:LOCALAPPDATA\npm-cache" -Label "npm 缓存"          # 演练
#   .\t07-safe-recycle.ps1 -Path "$env:LOCALAPPDATA\npm-cache" -Label "npm 缓存" -Apply   # 执行
# v2.0 新增预检：所在卷没有回收站（U 盘、网络盘）、回收站设为直接删除、体积超过回收站上限时一律拒绝，
# 因为这三种情况下"移入回收站"实际会变成永久删除。
param(
    [Parameter(Mandatory)][string[]]$Path,
    [string]$Label,
    [switch]$Apply
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force
$results = foreach ($p in $Path) { Invoke-WcoRecycle -Path $p -Label ($(if ($Label) { $Label } else { $p })) -Apply:$Apply }
$results | Format-Table Label, SizeMB, Status, Reason -AutoSize -Wrap
if ($Apply) {
    $undo = Export-WcoUndo
    Write-Host "变更记录：$((Get-WcoSession).Ledger)"
    Write-Host "回退说明：$undo（回收站项从回收站还原）"
    Write-Host '提醒：移入回收站不释放空间，确认无误后再清空回收站。'
}
