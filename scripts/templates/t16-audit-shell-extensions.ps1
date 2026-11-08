# 模板 16：audit-shell-extensions（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 16 节。

# === 1. 已知良性基线（Microsoft 自带 + 用户主动安装）===
# 用户装过 WPS、DeskGo（Tencent 桌面整理）、NVIDIA，所以这些的 shell 扩展是预期内
$expectedGood = @(
    'FileSyncEx','EncryptionMenu','EPP','Sharing','WorkFolders',           # 系统
    'New','NvCplDesktopContext','EnhancedStorageShell',                    # 系统
    'Open With kwpsshellext','Open With qingshellext',                    # WPS
    'QingNseContextMenu','qkdesktopshellext',                              # WPS
    'CF444751-60FC-48B8-AC0F-363063EB2A9E',                                 # DeskGo (CDeskmgrShellMenu)
    # === Win11 新增系统组件（v1.5.0 补充）===
    'Previous Versions','PreviousVersions',                                # 文件属性 → 以前的版本
    'Portable Devices','PortableDevices',                                  # U盘/手机右键
    'CD Burning','CDBurning',                                              # 光盘刻录
    'Search','ModernSharing','PinTo','PinToStart',                         # Win11 通用
    'Microsoft','OneDrive','Defender','Windows','Shell','Explorer'         # 通用 Microsoft
)

# === 2. 已知流氓 / bloatware shell 扩展关键词（与 bloatware-catalog.md 对齐）===
$bloatwarePatterns = @('360','2345','HaoZip','KuaiZip','FlashCenter',
                       'SogouService','QQPCMgr','LDSMain','BaiduNetdisk',
                       'MojingWallpaper','HaoZhuoDao','TodayHot','NewsPush',
                       'Meitu','AlibabaProtect','KSafe','KXETray')

# === 3. 收集所有 CLSID（用精确路径，不要通配）===
$allClsids = @()
$roots = @(
    'HKLM:\Software\Classes\Directory\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Drive\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\shellex\ContextMenuHandlers'
)
foreach ($root in $roots) {
    Get-ChildItem $root -EA SilentlyContinue | ForEach-Object {
        $allClsids += (Split-Path $_.PSPath -Leaf)
    }
}
$allClsids = $allClsids | Where-Object { $_ -match '^\{[\w-]+\}$' } | Select-Object -Unique

# === 4. CLSID 解析 + 命中检测 ===
$finding = @{ 'Good' = @(); 'Bloatware' = @(); 'Unknown' = @() }
foreach ($c in $allClsids) {
    $nm = (Get-ItemProperty "HKLM:\Software\Classes\$c" -EA SilentlyContinue)."(default)"
    $inproc = (Get-ItemProperty "HKLM:\Software\Classes\$c\InprocServer32" -EA SilentlyContinue)."(default)"
    $locsvr = (Get-ItemProperty "HKLM:\Software\Classes\$c\LocalServer32" -EA SilentlyContinue)."(default)"
    $impl  = if ($inproc) { $inproc } elseif ($locsvr) { $locsvr } else { '?' }
    $bag = [PSCustomObject]@{ CLSID = $c; Name = $nm; Impl = $impl }

    # 判断是否已知良性
    $isGood = $false
    foreach ($g in $expectedGood) {
        if ($c -like "*$g*" -or "$nm" -like "*$g*") { $isGood = $true; break }
    }
    # 判断是否匹配 bloatware
    $isBloat = $false
    foreach ($b in $bloatwarePatterns) {
        if ($impl -match $b -or "$nm" -match $b) { $isBloat = $true; break }
    }
    if ($isBloat) { $finding.Bloatware += $bag }
    elseif ($isGood) { $finding.Good += $bag }
    else { $finding.Unknown += $bag }
}

# === 5. 输出 ===
Write-Host "===== 良性 Shell 扩展 ====="
$finding.Good | ForEach-Object { Write-Host ("  {0,-40} {1}" -f $_.CLSID, $_.Name) }

Write-Host ""
Write-Host "===== 警告 疑似 bloatware ====="
if ($finding.Bloatware.Count -eq 0) { Write-Host "  （无）" }
$finding.Bloatware | ForEach-Object { Write-Host ("  {0,-40} {1}  -> {2}" -f $_.CLSID, $_.Name, $_.Impl) }

Write-Host ""
Write-Host "===== 未知 / 待定 ====="
$finding.Unknown | ForEach-Object { Write-Host ("  {0,-40} {1}  -> {2}" -f $_.CLSID, $_.Name, $_.Impl) }

# === 6. 可选：列出 HKLM Approved 白名单（很少，主要用于诊断）===
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" -EA SilentlyContinue |
    Get-Member -MemberType NoteProperty | Where-Object Name -notmatch '^(PS|Provider)' |
    ForEach-Object { Write-Host ("Approved: {0}" -f $_.Name) }
