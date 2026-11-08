# 模板 9：verify-report（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 9 节。

# 对每个扫描过的盘分别获取清理后可用空间
$drives = @("C", "D")  # 根据实际扫描的盘列表调整
foreach ($letter in $drives) {
    $afterFree = [math]::Round((Get-PSDrive $letter).Free / 1GB, 2)
    Write-Host "$letter 盘清理后可用: $afterFree GB"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
    .IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# 非管理员时提权执行（会弹 UAC，需提前告知用户）：
Start-Process powershell -Verb RunAs -Wait -ArgumentList
    '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\...\clean_admin.ps1'
