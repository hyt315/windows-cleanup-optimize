# 模板 9：verify-report —— 清理后核对各盘剩余空间（只读）
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File t09-verify-report.ps1 [-Drive C,D]
# 说明见 references/scan-scripts.md 第四节。

param([string[]]$Drive)

if (-not $Drive) {
    $Drive = Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue |
        Where-Object { $null -ne $_.Used -and ($_.Used + $_.Free) -gt 0 } |
        ForEach-Object Name
}
foreach ($letter in $Drive) {
    $d = Get-PSDrive $letter -EA SilentlyContinue
    if (-not $d) { Write-Host "$letter 盘不存在，跳过"; continue }
    Write-Host ("{0} 盘可用: {1:N2} GB" -f $letter, ($d.Free / 1GB))
}
Write-Host "提醒：移入回收站的文件仍占空间，清空回收站后才真正释放。"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "当前为普通权限。需要管理员才能做的项，请先告诉用户会弹 UAC，再用下面的方式单独提权运行："
    Write-Host "  Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<脚本绝对路径>','-OutDir','<报告绝对路径>'"
}
