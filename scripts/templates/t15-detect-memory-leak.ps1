# 模板 15：detect-memory-leak（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 15 节。

# === 第一次运行：记录基线 ===
New-Item -ItemType Directory -Path "$env:TEMP\wco" -Force | Out-Null   # v2.0：输出统一放 %TEMP%\wco
$baselineFile = "$env:TEMP\wco\memory_baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} |
    Export-Csv $baselineFile -NoTypeInformation
"基线已记录到: $baselineFile"
Write-Host "请等待 30 分钟后再次运行对比脚本。"

# === 第二次运行：找出泄漏进程 ===
# 读取最新的基线文件
$latestBaseline = Get-ChildItem "$env:TEMP\wco\memory_baseline_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestBaseline) {
    $baseline = Import-Csv $latestBaseline.FullName
    $current = Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}}
    $leaks = $baseline | ForEach-Object {
        $now = $current | Where-Object { $_.Name -eq $_.Name -and $_.Id -eq $_.Id }
        if ($now -and ($now.WS_MB - $_.WS_MB) -gt 50) {
            [PSCustomObject]@{
                Name = $_.Name
                Id = $_.Id
                Baseline_MB = $_.WS_MB
                Current_MB = $now.WS_MB
                Delta_MB = $now.WS_MB - $_.WS_MB
            }
        }
    }
    $leaks | Sort-Object Delta_MB -Descending | Format-Table -AutoSize
}
