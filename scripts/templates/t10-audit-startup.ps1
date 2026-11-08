# 模板 10：audit-startup（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 10 节。

# === HKCU/HKLM Run 扫描 ===
foreach ($key in @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)) {
    if (Test-Path $key) {
        Get-ItemProperty $key -EA SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                ForEach-Object { "自启: $($_.Name) = $($_.Value)" }
        }
    }
}

# === 启动文件夹扫描 ===
foreach ($sp in @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)) {
    if (Test-Path $sp) {
        Get-ChildItem $sp -File -EA SilentlyContinue | ForEach-Object { "$($_.FullName)" }
    }
}

# === 计划任务扫描（启用状态）===
Get-ScheduledTask -EA SilentlyContinue |
    Where-Object { $_.State -ne 'Disabled' } |
    ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo -EA SilentlyContinue
        "任务: $($_.TaskName) | 状态: $($_.State) | 上次: $(if($info.LastRunTime){$info.LastRunTime.ToString('MM-dd HH:mm')}else{'从未'})"
    }
