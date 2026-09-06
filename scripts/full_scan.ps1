<#
.SYNOPSIS
    windows-cleanup-optimize 一键全量扫描脚本
.DESCRIPTION
    按 SKILL.md 阶段 0-A "全量扫描模式" 执行，一次性跑完所有 18 个模板。
    输出三段式报告：按档位 + 按类型 + 按来源模板。
    自动反推用户画像（家庭/开发者/游戏玩家/笔记本/OEM）。

.PARAMETER OutDir
    报告输出目录，默认 $env:USERPROFILE

.EXAMPLE
    .\full_scan.ps1
    # 输出：C:\Users\<user>\full_scan_<timestamp>.txt

.NOTES
    作者：windows-cleanup-optimize 团队
    版本：v1.6.0（2026-09 增加 AI 模型缓存与 WSL 稀疏扫描、Quick 模式）
    依赖：Windows 10/11 + PowerShell 5.1+ + 标准命令行工具（powercfg）
#>

param(
    [string]$OutDir = "$env:USERPROFILE",
    [switch]$Quick
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$report = Join-Path $OutDir "full_scan_$ts.txt"
$script:lines  = @()
$script:findings = @()

function Log($s) { $script:lines += $s; Write-Host $s }
function Get-DirSize($p) {
    if (-not (Test-Path $p)) { return 0 }
    $s = (Get-ChildItem $p -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum
    if ($null -eq $s) { 0 } else { $s }
}
function MB($b) { if ($null -eq $b -or $b -eq 0) { '0 MB' } else { '{0:N1} MB' -f ($b/1MB) } }
function GB($b) { if ($null -eq $b -or $b -eq 0) { '0 MB' } else { '{0:N2} GB' -f ($b/1GB) } }

function Add-Finding($tpl, $type, $level, $path, $size, $lastWrite, $note) {
    $script:findings += [PSCustomObject]@{
        Template = $tpl; Type = $type; Level = $level
        Path = $path; SizeMB = [math]::Round($size/1MB, 1)
        LastWrite = $lastWrite; Note = $note
    }
}

Log "===== windows-cleanup-optimize 全量扫描 ====="
Log "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log "机器: $env:COMPUTERNAME / $env:USERNAME"
Log "系统: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"
Log ""

# ===== [T9] 磁盘基准 =====
Log "=== [T9] 磁盘基准 ==="
Get-PSDrive C,D,E -EA SilentlyContinue | ForEach-Object {
    $u=[math]::Round($_.Used/1GB,2); $f=[math]::Round($_.Free/1GB,2)
    $t=$u+$f; $p=if($t -gt 0){[math]::Round($u/$t*100,1)}else{0}
    Log ("  {0}盘: {1} GB 已用 / {2} GB 剩余 / {3}% ({4} GB 总)" -f $_.Name,$u,$f,$p,$t)
}
Log ""

# ===== [T1] 用户目录分层 =====
$layers = @(
    @{L='USERPROFILE';P=$env:USERPROFILE;ThresholdMB=30;Tpl='T1a'},
    @{L='AppData\Local';P=$env:LOCALAPPDATA;ThresholdMB=50;Tpl='T1b'},
    @{L='AppData\Roaming';P=$env:APPDATA;ThresholdMB=30;Tpl='T1c'},
    @{L='AppData\Local\Programs';P="$env:LOCALAPPDATA\Programs";ThresholdMB=30;Tpl='T1d'}
)
foreach ($layer in $layers) {
    Log "=== [$($layer.Tpl)] $($layer.L) Top 20 ==="
    if (Test-Path $layer.P) {
        $rows = @()
        Get-ChildItem $layer.P -Directory -Force -EA SilentlyContinue | ForEach-Object {
            $s = Get-DirSize $_.FullName
            if ($s -ge ($layer.ThresholdMB * 1MB)) {
                $rows += [PSCustomObject]@{ N=$_.Name; S=$s; LW=$_.LastWriteTime }
            }
        }
        $rows | Sort-Object S -Descending | Select-Object -First 20 | ForEach-Object {
            Log ("  {0,-8}  {1,-50}  写 {2:yyyy-MM-dd}" -f (MB $_.S), $_.N, $_.LW)
        }
    }
    Log ""
}

# ===== [T2] 非系统盘 =====
Log "=== [T2] 非系统盘根目录 ==="
foreach ($letter in @('D','E','F')) {
    $root = "${letter}:\"
    if (-not (Test-Path $root)) { continue }
    Log "  --- ${letter} 盘 ---"
    $rows = @()
    Get-ChildItem $root -Directory -Force -EA SilentlyContinue | ForEach-Object {
        $s = Get-DirSize $_.FullName
        if ($s -ge 100MB) {
            $hidden = if ($_.Attributes -match 'Hidden') { ' [H]' } else { '' }
            $rows += [PSCustomObject]@{ N="$($_.Name)$hidden"; S=$s; LW=$_.LastWriteTime }
        }
    }
    $rows | Sort-Object S -Descending | Select-Object -First 15 | ForEach-Object {
        Log ("    {0,-8}  {1,-50}  写 {2:yyyy-MM-dd}" -f (MB $_.S), $_.N, $_.LW)
    }
}
Log ""

# ===== [T5] 更新包残留（A/B/C/D 四项必跑）=====
Log "=== [T5] 更新包残留（4 项必跑）==="

# T5A: AppData 下 update/updater 类
foreach ($base in @($env:LOCALAPPDATA, $env:APPDATA)) {
    Get-ChildItem $base -Directory -Force -EA SilentlyContinue |
        Where-Object { $_.Name -match 'update|updater|patch|installer|pending' } | ForEach-Object {
            $s = Get-DirSize $_.FullName
            if ($s -ge 30MB) {
                Log ("  [T5A] {0,-8}  {1}  (写 {2:yyyy-MM-dd})" -f (MB $s), $_.Name, $_.LastWriteTime)
                Add-Finding 'T5A' '更新包残留' '🟢' $_.FullName $s $_.LastWriteTime.ToString('yyyy-MM-dd') '更新器缓存，可移回收站'
            }
        }
}

# T5B: 安装目录下 update/updater 子目录
$progBases = @("C:\Program Files", "C:\Program Files (x86)", "$env:LOCALAPPDATA\Programs")
foreach ($pb in $progBases) {
    if (-not (Test-Path $pb)) { continue }
    Get-ChildItem $pb -Directory -Force -EA SilentlyContinue | ForEach-Object {
        foreach ($sub in @('Update','updater','pending','updateTemp')) {
            $p = Join-Path $_.FullName $sub
            if ((Test-Path $p) -and ((Get-DirSize $p) -gt 20MB)) {
                $s = Get-DirSize $p
                Log ("  [T5B] {0,-8}  {1}\{2}" -f (MB $s), $_.Name, $sub)
            }
        }
    }
}

# T5C: 系统级缓存
$sysDirs = @(
    @{N='Win Update Download';P='C:\Windows\SoftwareDistribution\Download'},
    @{N='Win Update DeliveryOpt';P='C:\Windows\SoftwareDistribution\DeliveryOptimization'},
    @{N='NVIDIA';P='C:\NVIDIA'},
    @{N='AMD';P='C:\AMD'},
    @{N='Intel';P='C:\Intel'}
)
foreach ($d in $sysDirs) {
    if (Test-Path $d.P) {
        $s = Get-DirSize $d.P
        if ($s -gt 50MB) { Log "  [T5C] $($d.N): $(GB $s)" }
    }
}

# T5D: Downloads / Temp 中 >50MB 安装包
$dl = "$env:USERPROFILE\Downloads"
if (Test-Path $dl) {
    Get-ChildItem $dl -File -Force -EA SilentlyContinue | Where-Object { $_.Length -gt 50MB } |
        Sort-Object Length -Descending | Select-Object -First 20 | ForEach-Object {
            Log ("  [T5D-Downloads] {0,-8}  {1}" -f (MB $_.Length), $_.Name)
        }
}
$tempPath = "$env:LOCALAPPDATA\Temp"
if (Test-Path $tempPath) {
    Get-ChildItem $tempPath -File -Force -EA SilentlyContinue | Where-Object { $_.Length -gt 50MB } |
        Sort-Object Length -Descending | Select-Object -First 10 | ForEach-Object {
            Log ("  [T5D-Temp] {0,-8}  {1}" -f (MB $_.Length), $_.Name)
        }
}
Log ""

# ===== [T5E] AI 模型缓存与虚拟磁盘 =====
Log "=== [T5E] AI 模型缓存与虚拟磁盘 ==="
$aiTargets = @(
    @{N='Ollama Models'; P="$env:USERPROFILE\.ollama\models"; Note='Ollama本地模型，可通过OLLAMA_MODELS环境变量官方迁移D盘'},
    @{N='Hugging Face Cache'; P="$env:USERPROFILE\.cache\huggingface"; Note='HF模型与数据缓存，可通过HF_HOME环境变量官方迁移D盘'},
    @{N='ModelScope Cache'; P="$env:USERPROFILE\.cache\modelscope"; Note='魔搭模型缓存，可通过MODELSCOPE_CACHE环境变量官方迁移D盘'},
    @{N='PyTorch Cache'; P="$env:USERPROFILE\.cache\torch"; Note='PyTorch预训练权重缓存，可通过TORCH_HOME环境变量官方迁移D盘'},
    @{N='Python uv Cache'; P="$env:LOCALAPPDATA\uv\cache"; Note='uv包管理器缓存，可运行uv cache prune修剪或UV_CACHE_DIR迁移'},
    @{N='Android AVD Emulators'; P="$env:USERPROFILE\.android\avd"; Note='安卓虚拟设备镜像，可通过ANDROID_AVD_HOME官方迁移D盘'}
)
foreach ($item in $aiTargets) {
    if (Test-Path $item.P) {
        $s = Get-DirSize $item.P
        if ($s -ge 50MB) {
            Log ("  [T5E-AI] {0,-8}  {1}  (写 {2:yyyy-MM-dd})" -f (MB $s), $item.N, (Get-Item $item.P).LastWriteTime)
            Add-Finding 'T5E' 'AI与虚拟化缓存' '🟡' $item.P $s (Get-Item $item.P).LastWriteTime.ToString('yyyy-MM-dd') $item.Note
        }
    }
}
# VHDX 虚拟磁盘扫描（WSL2 / Docker）
$pkgDir = "$env:LOCALAPPDATA\Packages"
if (Test-Path $pkgDir) {
    Get-ChildItem $pkgDir -Filter "*.vhdx" -Recurse -Force -EA SilentlyContinue | ForEach-Object {
        if ($_.Length -ge 100MB) {
            Log ("  [T5E-VHDX] {0,-8}  {1}" -f (GB $_.Length), $_.FullName)
            Add-Finding 'T5E' 'AI与虚拟化缓存' '🟡' $_.FullName $_.Length $_.LastWriteTime.ToString('yyyy-MM-dd') 'WSL2/Docker虚拟磁盘，可通过wsl --manage --set-sparse true启用自动缩容或compact压缩'
        }
    }
}
Log ""

# ===== [T3] Roaming 残留 vs 已安装 =====
Log "=== [T3] Roaming 残留 vs 已安装列表 ==="
$installed = @()
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installed += $_.DisplayName }
Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installed += $_.DisplayName }
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installed += $_.DisplayName }
$installedLower = ($installed | ForEach-Object { $_.ToLower() } | Select-Object -Unique)

Get-ChildItem $env:APPDATA -Directory -Force -EA SilentlyContinue | ForEach-Object {
    $s = Get-DirSize $_.FullName
    if ($s -lt 10MB) { return }
    $dL = $_.Name.ToLower()
    $m = $installedLower | Where-Object { $_ -match [regex]::Escape($dL) -or $dL -match [regex]::Escape($_) } | Select-Object -First 1
    if ($m) {
        Log ("  [✅INSTALLED] {0,-8}  {1}" -f (MB $s), $_.Name)
    } else {
        Log ("  [🟢RESIDUAL]  {0,-8}  {1,-40}  (写 {2:yyyy-MM})" -f (MB $s), $_.Name, $_.LastWriteTime)
        Add-Finding 'T3' 'Roaming残留' '🟢' $_.FullName $s $_.LastWriteTime.ToString('yyyy-MM') '与已安装列表不匹配'
    }
}
Log ""

# ===== [T4] 安装目录残留 =====
Log "=== [T4] 安装目录残留 (C:/D:/Program Files) ==="
$knownSys = @('common files','windows nt','internet explorer','windows defender','microsoft shared','windows media player','reference assemblies','msbuild','dotnet','windows kits','windowsapps','modifiablewindowsapps','windows powershell')
$progBases2 = @("C:\Program Files", "C:\Program Files (x86)", "D:\Program Files", "D:\Program Files (x86)", "$env:LOCALAPPDATA\Programs")
foreach ($pb in $progBases2) {
    if (-not (Test-Path $pb)) { continue }
    Get-ChildItem $pb -Directory -Force -EA SilentlyContinue | ForEach-Object {
        $dL = $_.Name.ToLower()
        if ($knownSys -contains $dL) { return }
        $s = Get-DirSize $_.FullName
        if ($s -lt 30MB) { return }
        $m = $installedLower | Where-Object { $_ -match [regex]::Escape($dL) -or $dL -match [regex]::Escape($_) } | Select-Object -First 1
        if ($m) {
            Log ("  [✅INSTALLED] {0,-8}  {1}" -f (MB $s), $_.Name)
        } else {
            Log ("  [🟢RESIDUAL]  {0,-8}  {1,-40}  ({2})" -f (MB $s), $_.Name, $_.FullName)
            Add-Finding 'T4' '安装目录残留' '🟢' $_.FullName $s $_.LastWriteTime.ToString('yyyy-MM-dd') '与已安装列表不匹配，需人工核对 LastWrite'
        }
    }
}
Log ""

# ===== [T17] 本地 AI 框架缓存 =====
Log "=== [T17] 本地 AI / 开发框架缓存 ==="
$aiTargets = @(
    @{L='Ollama';P="$env:USERPROFILE\.ollama\models"},
    @{L='HuggingFace';P="$env:USERPROFILE\.cache\huggingface"},
    @{L='Trae-CN 隐藏';P="$env:USERPROFILE\.trae-cn"},
    @{L='TRAE SOLO CN';P="$env:APPDATA\TRAE SOLO CN"},
    @{L='WorkBuddy 数据';P="$env:LOCALAPPDATA\Programs\WorkBuddy"},
    @{L='Qoder 国际';P="$env:APPDATA\Qoder"},
    @{L='QoderWork CN';P="$env:APPDATA\QoderWork CN"},
    @{L='QoderCN';P="$env:APPDATA\QoderCN"},
    @{L='Qoder stable';P="$env:APPDATA\com.qoder.app.stable"},
    @{L='Qoder CN stable';P="$env:APPDATA\com.qodercn.app.stable"},
    @{L='OpenCode';P="$env:LOCALAPPDATA\Programs\OpenCode"},
    @{L='Antigravity';P="$env:LOCALAPPDATA\Programs\antigravity"},
    @{L='Codex CLI';P="$env:USERPROFILE\.codex"},
    @{L='Gemini CLI';P="$env:USERPROFILE\.gemini"},
    @{L='CherryStudio';P="$env:USERPROFILE\.cherrystudio"},
    @{L='HanaAgent';P="$env:LOCALAPPDATA\Programs\HanaAgent"},
    @{L='ZCode 工作';P="$env:USERPROFILE\.zcode"},
    @{L='本地 Python';P="$env:LOCALAPPDATA\Programs\Python"}
)
foreach ($t in $aiTargets) {
    if (Test-Path $t.P) {
        $s = Get-DirSize $t.P
        if ($s -ge 5MB) {
            Log ("  [T17] {0,-8}  {1,-30}  {2}" -f (MB $s), $t.L, $t.P)
            Add-Finding 'T17' 'AI框架缓存' '🟡' $t.P $s 'n/a' "需要用户确认是否在用：$($t.L)"
        }
    }
}
Log ""

# ===== [T11] Bloatware 进程（完整 catalog）=====
Log "=== [T11] Bloatware 进程 ==="
$bloat = @(
    "360safe","360sd","ZhuDongFangYu","360TSMain","QHWatchdog","360SafeClean",
    "2345Safe","2345Guard","2345Live","2345Ime","2345Pinyin","2345Explorer","2345Pic","HaoZip",
    "KSAVSvc","kxescore","kxetray","QQPCMgr","QQPCRtp","TQMCenter",
    "LDSMain","LDSService","DriverGenius","DGService","DTLSoft","DrvLife",
    "SogouService","SogouIM","SGMain","QQPinyinService",
    "360Desktop","360DesktopLite","KingsoftDesktop","MojingWallpaper","HaoZhuoDao",
    "360se","360chrome","QQBrowser","SogouExplorer","UCBrowser",
    "FlashCenter","FlashHelperService","TodayHot","NewsPush","HotNews",
    "KuaiZip","BaiduNetdisk","Meitu"
)
$whitelist = @("DeskGo","DesktopMgr64","Steam","wallpaper32","WallpaperEngine","HuorongEs")
$bhits = Get-Process -EA SilentlyContinue | Where-Object { $bloat -contains $_.ProcessName -and $_.ProcessName -notin $whitelist }
if ($bhits) {
    $bhits | Group-Object ProcessName | ForEach-Object {
        $ws = [math]::Round((($_.Group | Measure-Object WorkingSet -Sum).Sum)/1MB,0)
        Log ("  ⚠️  [$($_.Count)x] {0,-25} {1} MB" -f $_.Name, $ws)
    }
} else { Log "  ✅ 未检测到已知 bloatware 进程" }
Log ""

# ===== [T10] 自启动项 =====
Log "=== [T10] 自启动项 ==="
foreach ($key in @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)) {
    if (Test-Path $key) {
        Log "  [Run] $key"
        Get-ItemProperty $key -EA SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                ForEach-Object { Log ("    {0,-35} = {1}" -f $_.Name, $_.Value) }
        }
    }
}
Log "  --- 计划任务（前 20 最近运行）---"
Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.State -ne 'Disabled' } | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -EA SilentlyContinue
    $last = if ($info.LastRunTime) { $info.LastRunTime.ToString('MM-dd HH:mm') } else { '从未' }
    [PSCustomObject]@{ Name=$_.TaskName; State=$_.State; Last=$last }
} | Sort-Object @{E={ if ($_.Last -eq '从未') { '9999' } else { $_.Last } }} | Select-Object -First 20 |
    ForEach-Object { Log ("    {0,-12} {1,-50} 上次 {2}" -f $_.State, $_.Name, $_.Last) }
Log ""

# ===== [T12/T18] 服务 =====
Log "=== [T12/T18] 服务快照 ==="
foreach ($n in @('YunDetectService','XLServicePlatform','ThunderNetwork','wpscloudsvr','AlibabaProtect')) {
    $s = Get-Service -Name $n -EA SilentlyContinue
    if ($s) { Log ("  [T18 顽固] {0,-18} 状态={1,-10} 启动={2}" -f $n, $s.Status, $s.StartType) }
}
$optSvcs = @("DiagTrack","dmwappushservice","diagnosticshub.standardcollector.service","DusmSvc",
             "XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","BcastDVRUserService",
             "RemoteRegistry","Fax","WerSvc","MapsBroker")
Get-Service -EA SilentlyContinue | Where-Object { $_.Name -in $optSvcs -or $_.Name -like 'GoogleUpdate*' } |
    ForEach-Object { Log ("  [T12 可优化] {0,-40} 状态={1,-10} 启动={2}" -f $_.Name, $_.Status, $_.StartType) }
Log ""

# ===== [T16] Shell 扩展审计 =====
Log "=== [T16] Shell 扩展审计 ==="
$expectedGood = @(
    'FileSyncEx','EncryptionMenu','EPP','Sharing','WorkFolders',
    'New','NvCplDesktopContext','EnhancedStorageShell',
    'Open With kwpsshellext','Open With qingshellext',
    'QingNseContextMenu','qkdesktopshellext',
    'CF444751-60FC-48B8-AC0F-363063EB2A9E',
    # === Win11 新增系统组件（v1.5.0 补充）===
    'Previous Versions','PreviousVersions','Portable Devices','PortableDevices',
    'CD Burning','CDBurning','Search','ModernSharing','PinTo','PinToStart',
    'Microsoft','OneDrive','Defender','Windows','Shell','Explorer'
)
$bloatPatterns = @('360','2345','HaoZip','KuaiZip','FlashCenter',
                   'SogouService','QQPCMgr','LDSMain','BaiduNetdisk',
                   'MojingWallpaper','HaoZhuoDao','TodayHot','NewsPush',
                   'Meitu','AlibabaProtect','KSafe','KXETray')
$roots = @(
    'HKLM:\Software\Classes\Directory\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Drive\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\shellex\ContextMenuHandlers'
)
$allClsids = @()
foreach ($root in $roots) {
    Get-ChildItem $root -EA SilentlyContinue | ForEach-Object {
        $allClsids += (Split-Path $_.PSPath -Leaf)
    }
}
$allClsids = $allClsids | Where-Object { $_ -match '^\{[\w-]+\}$' } | Select-Object -Unique
$fGood = 0; $fBloat = 0; $fUnknown = @()
foreach ($c in $allClsids) {
    $nm = (Get-ItemProperty "HKLM:\Software\Classes\$c" -EA SilentlyContinue)."(default)"
    $inproc = (Get-ItemProperty "HKLM:\Software\Classes\$c\InprocServer32" -EA SilentlyContinue)."(default)"
    $locsvr = (Get-ItemProperty "HKLM:\Software\Classes\$c\LocalServer32" -EA SilentlyContinue)."(default)"
    $impl  = if ($inproc) { $inproc } elseif ($locsvr) { $locsvr } else { '?' }
    $isGood = $false
    foreach ($g in $expectedGood) {
        if ($c -like "*$g*" -or "$nm" -like "*$g*") { $isGood = $true; break }
    }
    $isBloat = $false
    foreach ($b in $bloatPatterns) {
        if ($impl -match $b -or "$nm" -match $b) { $isBloat = $true; break }
    }
    if ($isBloat) { $fBloat++ }
    elseif ($isGood) { $fGood++ }
    else { $fUnknown += [PSCustomObject]@{ CLSID=$c; Name=$nm; Impl=$impl } }
}
Log ("  良性: {0}  疑似 bloatware: {1}  未知/待定: {2}" -f $fGood, $fBloat, $fUnknown.Count)
foreach ($u in $fUnknown) {
    Log ("    未知: {0,-40} {1,-30} -> {2}" -f $u.CLSID, $u.Name, $u.Impl)
}
Log ""

# ===== [T13] 内存基线 =====
Log "=== [T13] 内存基线 ==="
$mem = Get-CimInstance Win32_OperatingSystem
$totGB = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
$freeGB = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
$usedGB = $totGB - $freeGB
Log ("  物理: 总 {0} GB / 已用 {1} GB / 可用 {2} GB ({3}%)" -f $totGB, $usedGB, $freeGB, ([math]::Round($usedGB/$totGB*100,1)))
Log "  --- Top 15 进程 ---"
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 15 |
    ForEach-Object { Log ("    {0,-8}  {1}" -f (MB $_.WorkingSet), $_.Name) }
Log ""

# ===== [T14] 电源计划 =====
Log "=== [T14] 电源计划 ==="
$ps = & powercfg /getactivescheme 2>$null
Log "  当前: $ps"
Log ""

# ===== 自动画像反推 =====
Log "===== 画像自动反推 ====="
$profile = @()
# 家庭：WPS / 360 / 2345 / 腾讯管家
$wpsFamily = $findings | Where-Object { $_.Path -match 'WPS|Kingsoft|360|2345|QQPCMgr' }
if ($wpsFamily) { $profile += '🏠 家庭用户（装了 WPS/360/2345/腾讯管家等）' }
# 开发者：Docker / WSL / VS Code / JetBrains / AI IDE
$devPaths = $findings | Where-Object { $_.Path -match 'JetBrains|Programs\\Python|Programs\\OpenCode|Programs\\antigravity|\\.codex|\\.gemini|Programs\\HanaAgent' }
if ($devPaths) { $profile += '👨‍💻 开发者（装了 JetBrains/Python/AI IDE）' }
# AI 创作者 / 虚拟化用户：本地大模型、WSL2、Docker、AVD 镜像
$aiPaths = $findings | Where-Object { $_.Type -eq 'AI与虚拟化缓存' -or $_.Path -match 'ollama|huggingface|modelscope|\.android\\avd|\.vhdx' }
if ($aiPaths) { $profile += '🤖 AI创作者/虚拟化用户（存在本地大模型/WSL/Docker/AVD虚拟磁盘）' }
# 游戏玩家
$steamProc = Get-Process Steam -EA SilentlyContinue
if ($steamProc) { $profile += '🎮 游戏玩家（Steam 在跑）' }
# OEM 笔记本
if ($ps -match 'Acer|Lenovo|Dell|ASUS|HP|Huawei') {
    $profile += '💻 笔记本/OEM（厂商电源方案）'
}
if ($profile.Count -gt 0) {
    Log "  你的画像："
    $profile | ForEach-Object { Log "    $_" }
} else {
    Log "  未识别出明显画像"
}
Log ""
Log "  针对你画像的专项建议见后续报告"
Log ""

# ===== 写盘 =====
$script:lines | Out-File $report -Encoding UTF8
Write-Host ""
Write-Host "===== 报告已生成 ====="
Write-Host "路径: $report"
Write-Host "发现数: $($findings.Count) 项"