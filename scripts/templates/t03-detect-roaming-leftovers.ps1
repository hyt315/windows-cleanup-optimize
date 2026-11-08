# 模板 3：detect-roaming-leftovers（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 3 节。

# Step 1: 扫描 Roaming 目录
$roamingResults = @()
Get-ChildItem $env:APPDATA -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($null -eq $size) { $size = 0 }
    $roamingResults += [PSCustomObject]@{
        Name     = $_.Name
        SizeMB   = [math]::Round($size / 1MB, 2)
        FullPath = $_.FullName
        LastWrite = $_.LastWriteTime.ToString("yyyy-MM")
    }
}

# Step 2: 读取已安装应用（注册表 + 开始菜单）
$installedNames = @()
# HKLM 64-bit
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# HKLM 32-bit
Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# HKCU
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# 开始菜单快捷方式名称
$startMenuNames = @()
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
    ForEach-Object { $startMenuNames += $_.BaseName }
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
    ForEach-Object { $startMenuNames += $_.BaseName }

# Step 3: 交叉比对 — 模糊匹配 Roaming 目录名与已安装应用名
$installedLower = ($installedNames + $startMenuNames) | ForEach-Object { $_.ToLower() } | Select-Object -Unique

foreach ($dir in $roamingResults) {
    $dirLower = $dir.Name.ToLower()
    $match = $installedLower | Where-Object { $_ -match [regex]::Escape($dirLower) -or $dirLower -match [regex]::Escape($_) }
    if ($match) {
        $dir | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'INSTALLED'
    } else {
        $dir | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'RESIDUAL'
    }
}

# 输出分类结果
Write-Host "=== 已卸载软件的残留（可安全清理）==="
$roamingResults | Where-Object { $_.Status -eq 'RESIDUAL' -and $_.SizeMB -gt 0 } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB, LastWrite -AutoSize

Write-Host "`n=== 正在使用的软件（不要动）==="
$roamingResults | Where-Object { $_.Status -eq 'INSTALLED' } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB -AutoSize
