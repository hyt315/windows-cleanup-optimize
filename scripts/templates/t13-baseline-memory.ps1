# 模板 13：baseline-memory（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 13 节。

# 实时内存状态
New-Item -ItemType Directory -Path "$env:TEMP\wco" -Force | Out-Null   # v2.0：输出统一放 %TEMP%\wco
$mem = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
$freeGB = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
$usedGB = $totalGB - $freeGB
$usedPct = [math]::Round($usedGB / $totalGB * 100, 1)
"物理内存: 总 $totalGB GB / 可用 $freeGB GB / 已用 $usedGB GB ($usedPct%)"

# Top 10 内存占用进程
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 |
    Format-Table Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} -AutoSize

# 提交字节（虚拟内存）
Get-Counter '\Memory\Committed Bytes' | Select-Object -ExpandProperty CounterSamples |
    Select-Object CookedValue, Path

# 导出基线（用于泄漏检测对比）
$baselineFile = "$env:TEMP\wco\memory_baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} |
    Export-Csv $baselineFile -NoTypeInformation
"基线已记录: $baselineFile"
