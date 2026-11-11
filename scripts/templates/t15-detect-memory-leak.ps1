# 模板 15：detect-memory-leak（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 15 节。只读（只在 %TEMP%\wco 写采样文件）。
# v2.1：先读取"上一次"的基线文件，再写本次快照；按进程 Id + 名称逐个对比专用内存（Private Bytes）。
#       没有上一次基线时只保存本次快照，过一段时间（如 30 分钟）再运行即可对比。
param(
    [double]$ThresholdMB = 50,
    [string]$Dir = (Join-Path $env:TEMP 'wco')
)
New-Item -ItemType Directory -Path $Dir -Force | Out-Null   # v2.0：输出统一放 %TEMP%\wco

# === 1. 先找上一次的基线（必须在写新文件之前）===
$previous = Get-ChildItem -LiteralPath $Dir -Filter 'memory_baseline_*.csv' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$baseline = @()
if ($previous) { $baseline = @(Import-Csv -LiteralPath $previous.FullName) }

# === 2. 采集本次快照 ===
$current = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne 0 } | ForEach-Object {
    [pscustomobject]@{
        Name       = $_.ProcessName
        Id         = $_.Id
        Private_MB = [math]::Round($_.PrivateMemorySize64 / 1MB, 1)
        WS_MB      = [math]::Round($_.WorkingSet64 / 1MB, 1)
    }
})

# === 3. 与上一次基线对比 ===
if (-not $previous) {
    "没有找到上一次的基线（$Dir\memory_baseline_*.csv），本次只保存快照。"
} elseif ($baseline.Count -eq 0) {
    "上一次的基线文件为空或无法读取：$($previous.FullName)，本次只保存快照。"
} else {
    $minutes = [math]::Round(((Get-Date) - $previous.LastWriteTime).TotalMinutes, 0)
    $hasPrivate = ($null -ne $baseline[0].PSObject.Properties['Private_MB'])
    $col = if ($hasPrivate) { 'Private_MB' } else { 'WS_MB' }
    "对比基线: $($previous.Name)（约 $minutes 分钟前） | 指标: $(if ($hasPrivate) { '专用内存 Private Bytes' } else { '工作集（旧基线没有专用内存列，如模板 13 生成的基线）' }) | 阈值: +$ThresholdMB MB"
    $byKey = @{}
    foreach ($c in $current) { $byKey["$($c.Id)|$($c.Name)"] = $c }
    $leaks = foreach ($b in $baseline) {
        $now = $byKey["$($b.Id)|$($b.Name)"]
        if (-not $now) { continue }                       # 进程已退出或 Id 被其他进程复用
        $before = [double]$b.$col
        $after = [double]$now.$col
        $delta = [math]::Round($after - $before, 1)
        if ($delta -gt $ThresholdMB) {
            [PSCustomObject]@{
                Name        = $b.Name
                Id          = $b.Id
                Baseline_MB = $before
                Current_MB  = $after
                Delta_MB    = $delta
            }
        }
    }
    $leaks = @($leaks)
    if ($leaks.Count -gt 0) {
        "以下进程两次采样间内存增长超过 $ThresholdMB MB（单次增长不等于泄漏，建议再隔一段时间运行，看是否持续上涨）："
        $leaks | Sort-Object Delta_MB -Descending | Format-Table -AutoSize
    } else {
        "未发现内存增长超过 $ThresholdMB MB 的进程"
    }
}

# === 4. 保存本次快照，作为下一次的基线 ===
$baselineFile = Join-Path $Dir "memory_baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$current | Export-Csv -LiteralPath $baselineFile -NoTypeInformation -Encoding UTF8
"本次快照已记录到: $baselineFile"
Write-Host '请等待 30 分钟左右后再次运行本脚本进行对比。'
