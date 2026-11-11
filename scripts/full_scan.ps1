<#
.SYNOPSIS
    windows-cleanup-optimize 一键全量扫描脚本
.DESCRIPTION
    SKILL.md 阶段 1（只读诊断）的入口：一次跑完全部只读扫描，不改设置、不删文件。
    开头做运行前检查（权限、系统版本、待重启、还原点、C 盘余量），缺什么直接给修法。
    结尾按档位汇总发现项，并自动反推用户画像（家庭/开发者/AI/游戏/笔记本）。

.PARAMETER Quick
    跳过最耗时的两项（T2 非系统盘、T4 安装目录递归统计），用于 CI 或快速体检。

.PARAMETER OutDir
    报告输出目录，默认 $env:TEMP\wco（不往用户目录里丢文件，见踩坑 64）

.EXAMPLE
    .\full_scan.ps1
    # 输出：%TEMP%\wco\full_scan_<timestamp>.txt

.NOTES
    作者：windows-cleanup-optimize 团队
    版本：v2.0.1
    依赖：Windows 10/11 + PowerShell 5.1+ + 标准命令行工具（powercfg）
#>

param(
    [string]$OutDir = (Join-Path $env:TEMP 'wco'),
    [switch]$Quick
)

$ErrorActionPreference = 'SilentlyContinue'
# 保存原控制台编码，脚本结尾还原，不给用户的会话留副作用。
# 注意：主体不包 try/finally —— 在 try 里任何一条语句级错误都会中止整次扫描，而现在是"某段失败就跳过、继续下一段"。
$script:origOutputEncoding = $null
try { $script:origOutputEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Verbose "无法设置控制台编码：$($_.Exception.Message)" }
function Restore-ConsoleEncoding {
    if ($null -ne $script:origOutputEncoding) {
        try { [Console]::OutputEncoding = $script:origOutputEncoding } catch { Write-Verbose "无法还原控制台编码：$($_.Exception.Message)" }
    }
}
try {
    Import-Module (Join-Path $PSScriptRoot 'lib\Wco.Common.psm1') -Force -ErrorAction Stop
} catch {
    Restore-ConsoleEncoding
    throw "加载 scripts\lib\Wco.Common.psm1 失败：$($_.Exception.Message)"
}
# 只读保证：除了 %TEMP%\wco 下的这份报告，不写任何文件
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$report = Join-Path $OutDir "full_scan_$ts.txt"
$script:lines  = New-Object 'System.Collections.Generic.List[string]'
$script:findings = New-Object 'System.Collections.Generic.List[object]'
$script:startTime = Get-Date
# 体积缓存（完整路径 → 字节）：AppData 只遍历一次，后面各段直接复用
$script:sizeCache = @{}

function Log($s) { $script:lines.Add([string]$s); Write-Host $s }
function Get-DirSize($p) {
    # Measure-WcoDirectory：不进 junction/符号链接（5.1 下 Get-ChildItem -Recurse 会跟随），路径按字面处理（[ ] 不当通配符）
    if (-not $p) { return 0 }
    $r = Measure-WcoDirectory -Path $p -Cache $script:sizeCache
    if (-not $r.Exists) { return 0 }
    return [int64]$r.Bytes
}
function MB($b) { if ($null -eq $b -or $b -eq 0) { '0 MB' } else { '{0:N1} MB' -f ($b/1MB) } }
function GB($b) { if ($null -eq $b -or $b -eq 0) { '0 MB' } else { '{0:N2} GB' -f ($b/1GB) } }

function Add-Finding($tpl, $type, $level, $path, $size, $lastWrite, $note) {
    $script:findings.Add([PSCustomObject]@{
        Template = $tpl; Type = $type; Level = $level
        Path = $path; SizeMB = [math]::Round($size/1MB, 1)
        LastWrite = $lastWrite; Note = $note
    })
}

Log "===== windows-cleanup-optimize 全量扫描 ====="
Log "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log "机器: $env:COMPUTERNAME / $env:USERNAME"
$os = Get-CimInstance Win32_OperatingSystem
Log "系统: $($os.Caption) $($os.Version)"
$isAdmin = Test-WcoAdmin
if ($isAdmin) {
    Log "权限: 管理员（完整扫描）"
} else {
    Log "权限: 普通用户 —— 以下几项数据可能不全：系统目录体积、服务配置、WMI 订阅、开机耗时日志。需要完整结果请右键「以管理员身份运行」。"
}
if ($os.Version -like '10.0.1*') { Log "提示: 这是 Windows 10（微软已于 2025-10-14 停止常规支持）。不要关闭 Windows 更新与 Defender。" }
Log ""

# ===== 运行前检查（只读；只提示，不阻断扫描）=====
Log "=== [PRE] 运行前检查 ==="
$pre = @()
if (-not $isAdmin) { $pre += "非管理员：部分数据不全。修法：开始菜单搜 PowerShell → 右键「以管理员身份运行」，再执行本脚本。" }
if ($PSVersionTable.PSVersion.Major -lt 5) { $pre += "PowerShell 版本过低（$($PSVersionTable.PSVersion)）。修法：安装 Windows Management Framework 5.1。" }
$pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                 (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
if ($pendingReboot) { $pre += "系统有待完成的更新重启。修法：先重启一次再清理，否则更新缓存删不动、DISM 也会报错。" }
$srDisabled = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -EA SilentlyContinue).DisableSR -eq 1
$srInterval = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -EA SilentlyContinue).RPSessionInterval
if ($srDisabled -or $srInterval -eq 0) { $pre += "系统还原可能未开启，改服务或驱动前建不了还原点。修法：Win+R 输入 sysdm.cpl → 系统保护 → 选 C 盘 → 配置 → 启用。" }
$cFree = (Get-PSDrive C -EA SilentlyContinue).Free
if ($cFree -and $cFree -lt 5GB) { $pre += ("C 盘只剩 {0:N1} GB，建还原点和 DISM 可能失败。先做第一档的缓存清理，腾出空间再做其他。" -f ($cFree / 1GB)) }
if ($pre.Count -eq 0) { Log "  ✅ 全部就绪" } else { $pre | ForEach-Object { Log "  ⚠️  $_" } }
Log "  扫描只读，可以照常用电脑；通常几分钟，盘越大越久（-Quick 更快）。"
Log ""

# ===== [T0] 开机耗时实测（Diagnostics-Performance 事件 100，需管理员） =====
Log "=== [T0] 开机耗时（系统自记，最近 5 次）==="
try {
    $boots = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 5 -ErrorAction Stop
    foreach ($b in $boots) {
        $xml = [xml]$b.ToXml()
        $ms = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text'
        Log ("  {0}  开机 {1:N1} 秒" -f $b.TimeCreated.ToString('yyyy-MM-dd HH:mm'), ([double]$ms / 1000))
    }
    $script:bootSeconds = [math]::Round((($boots | ForEach-Object { [double](([xml]$_.ToXml()).Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }).'#text' }) | Measure-Object -Average).Average / 1000, 1)
    Log "  平均: $($script:bootSeconds) 秒（优化后再跑一次，对比这个数）"
} catch {
    Log "  读不到（需要管理员，或该日志被禁用）。用户说开机慢时，改用任务管理器「启动应用」页的「启动影响」列。"
}
Log ""

# ===== [T9] 磁盘基准 =====
Log "=== [T9] 磁盘基准 ==="
Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | Where-Object { $_.Used -ne $null -and ($_.Used + $_.Free) -gt 0 } | ForEach-Object {
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
# 由深到浅预先量一遍各层子目录（Local\Programs → Local → Roaming → USERPROFILE），
# 结果进缓存：外层遇到已量过的子目录直接取值，AppData 不会被重复遍历。T3/T5A 也复用这些结果。
$layerRows = @{}
foreach ($layer in @($layers[3], $layers[1], $layers[2], $layers[0])) {
    $rows = @()
    if ($layer.P -and (Test-Path -LiteralPath $layer.P)) {
        $rows = @(Get-ChildItem -LiteralPath $layer.P -Directory -Force -EA SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{ N=$_.Name; S=(Get-DirSize $_.FullName); LW=$_.LastWriteTime }
        })
    }
    $layerRows[$layer.Tpl] = $rows
}
foreach ($layer in $layers) {
    Log "=== [$($layer.Tpl)] $($layer.L) Top 20 ==="
    if ($layer.P -and (Test-Path -LiteralPath $layer.P)) {
        $rows = @($layerRows[$layer.Tpl] | Where-Object { $_.S -ge ($layer.ThresholdMB * 1MB) })
        $rows | Sort-Object S -Descending | Select-Object -First 20 | ForEach-Object {
            Log ("  {0,-8}  {1,-50}  写 {2:yyyy-MM-dd}" -f (MB $_.S), $_.N, $_.LW)
        }
    }
    Log ""
}

if ($Quick) { Log "=== [T2] 已跳过（-Quick：不递归统计非系统盘和安装目录）==="; Log "" } else {
# ===== [T2] 非系统盘 =====
Log "=== [T2] 非系统盘根目录 ==="
foreach ($letter in @('D','E','F')) {
    $root = "${letter}:\"
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Log "  --- ${letter} 盘 ---"
    $rows = @()
    Get-ChildItem -LiteralPath $root -Directory -Force -EA SilentlyContinue | ForEach-Object {
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

}

# ===== [T5] 更新包残留（A/B/C/D 四项必跑）=====
Log "=== [T5] 更新包残留（4 项必跑）==="

# T5A: AppData 下 update/updater 类
foreach ($base in @($env:LOCALAPPDATA, $env:APPDATA)) {
    if (-not $base) { continue }
    Get-ChildItem -LiteralPath $base -Directory -Force -EA SilentlyContinue |
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
    if (-not (Test-Path -LiteralPath $pb)) { continue }
    Get-ChildItem -LiteralPath $pb -Directory -Force -EA SilentlyContinue | ForEach-Object {
        foreach ($sub in @('Update','updater','pending','updateTemp')) {
            $p = Join-Path $_.FullName $sub
            if (-not (Test-Path -LiteralPath $p)) { continue }
            $s = Get-DirSize $p
            if ($s -gt 20MB) {
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
    if (Test-Path -LiteralPath $d.P) {
        $s = Get-DirSize $d.P
        if ($s -gt 50MB) { Log "  [T5C] $($d.N): $(GB $s)" }
    }
}

# T5D: Downloads / Temp 中 >50MB 安装包
$dl = "$env:USERPROFILE\Downloads"
if (Test-Path -LiteralPath $dl) {
    Get-ChildItem -LiteralPath $dl -File -Force -EA SilentlyContinue | Where-Object { $_.Length -gt 50MB } |
        Sort-Object Length -Descending | Select-Object -First 20 | ForEach-Object {
            Log ("  [T5D-Downloads] {0,-8}  {1}" -f (MB $_.Length), $_.Name)
        }
}
$tempPath = "$env:LOCALAPPDATA\Temp"
if (Test-Path -LiteralPath $tempPath) {
    Get-ChildItem -LiteralPath $tempPath -File -Force -EA SilentlyContinue | Where-Object { $_.Length -gt 50MB } |
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
    if (Test-Path -LiteralPath $item.P) {
        $s = Get-DirSize $item.P
        if ($s -ge 50MB) {
            $lw = (Get-Item -LiteralPath $item.P -Force).LastWriteTime
            Log ("  [T5E-AI] {0,-8}  {1}  (写 {2:yyyy-MM-dd})" -f (MB $s), $item.N, $lw)
            Add-Finding 'T5E' 'AI与虚拟化缓存' '🟡' $item.P $s $lw.ToString('yyyy-MM-dd') $item.Note
        }
    }
}
# VHDX 虚拟磁盘扫描（WSL2 / Docker）
$pkgDir = "$env:LOCALAPPDATA\Packages"
if (Test-Path -LiteralPath $pkgDir) {
    Get-ChildItem -LiteralPath $pkgDir -Filter "*.vhdx" -Recurse -Force -EA SilentlyContinue | ForEach-Object {
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

Get-ChildItem -LiteralPath $env:APPDATA -Directory -Force -EA SilentlyContinue | ForEach-Object {
    $s = Get-DirSize $_.FullName   # 命中 T1c 缓存，不再遍历 Roaming
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

if ($Quick) { Log "=== [T4] 已跳过（-Quick：不递归统计非系统盘和安装目录）==="; Log "" } else {
# ===== [T4] 安装目录残留 =====
Log "=== [T4] 安装目录残留 (C:/D:/Program Files) ==="
$knownSys = @('common files','windows nt','internet explorer','windows defender','microsoft shared','windows media player','reference assemblies','msbuild','dotnet','windows kits','windowsapps','modifiablewindowsapps','windows powershell')
$progBases2 = @("C:\Program Files", "C:\Program Files (x86)", "D:\Program Files", "D:\Program Files (x86)", "$env:LOCALAPPDATA\Programs")
foreach ($pb in $progBases2) {
    if (-not (Test-Path -LiteralPath $pb)) { continue }
    Get-ChildItem -LiteralPath $pb -Directory -Force -EA SilentlyContinue | ForEach-Object {
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

}

# ===== [T17] 本地 AI 框架缓存 =====
Log "=== [T17] 本地 AI / 开发框架缓存 ==="
$aiTargets = @(
    @{L='Ollama';P="$env:USERPROFILE\.ollama\models"},
    @{L='HuggingFace';P="$env:USERPROFILE\.cache\huggingface"},
    @{L='PyTorch 权重缓存';P="$env:USERPROFILE\.cache\torch"},
    @{L='uv 包缓存';P="$env:LOCALAPPDATA\uv\cache"},
    @{L='Android AVD 镜像';P="$env:USERPROFILE\.android\avd"},
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
    if (Test-Path -LiteralPath $t.P) {
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
# Run / RunOnce / RunOnceEx / Policies\Explorer\Run / 启动文件夹，并对上 StartupApproved（任务管理器「启动应用」开关）
$approvedLabel = @{ Enabled = '启用'; Disabled = '已禁用'; Absent = '启用(默认)'; Unknown = '未知'; 'n/a' = '无开关' }
$startupItems = @(Get-WcoStartupItem)
if ($startupItems.Count -eq 0) {
    Log "  （未读到任何登录自启项）"
} else {
    $startupItems | Group-Object Source | ForEach-Object {
        Log "  [$($_.Name)] $($_.Group[0].Location)"
        foreach ($it in $_.Group) {
            $st = $approvedLabel[[string]$it.Approved]
            if (-not $st) { $st = [string]$it.Approved }
            if ($it.DisabledAt) { $st = "$st @ $($it.DisabledAt.ToString('yyyy-MM-dd'))" }
            Log ("    {0,-14} {1,-35} = {2}" -f "[$st]", $it.Name, $it.Command)
        }
    }
    $activeCnt = @($startupItems | Where-Object { $_.Approved -ne 'Disabled' }).Count
    Log ("  合计 {0} 项，其中生效 {1} 项（已在任务管理器禁用的 {2} 项不算生效）" -f $startupItems.Count, $activeCnt, ($startupItems.Count - $activeCnt))
}
Log "  --- 计划任务（前 20 最近运行）---"
@(Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.State -ne 'Disabled' } | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -EA SilentlyContinue
    $lrt = $null
    if ($info -and $info.LastRunTime -and ([datetime]$info.LastRunTime).Year -ge 2000) { $lrt = [datetime]$info.LastRunTime }
    $last = if ($lrt) { $lrt.ToString('yyyy-MM-dd HH:mm') } else { '从未' }
    # 从未运行的任务 LastRunTime 常为 1999-11-30，按"从未"处理并排在最后
    $sortKey = if ($lrt) { $lrt } else { [datetime]::MinValue }
    [PSCustomObject]@{ Name=$_.TaskName; State=$_.State; Last=$last; SortKey=$sortKey }
}) | Sort-Object SortKey -Descending | Select-Object -First 20 |
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

# ===== [T19] WMI 持久化与快捷方式劫持审计 =====
Log "=== [T19] WMI 持久化与快捷方式劫持审计 ==="
# 1. WMI 永久事件订阅（__EventFilter / CommandLine / ActiveScript 消费者 / 绑定）；查询失败绝不报"干净"
$wmi = Get-WcoWmiSubscription
if ($wmi.Status -ne 'OK') {
    Log ("  ⚠️  [WMI] 查询失败（需管理员）—— 未检查，不代表干净。{0}" -f $wmi.Message)
} else {
    $wmiSuspect = @($wmi.Items | Where-Object { -not $_.KnownDefault })
    if ($wmiSuspect.Count -gt 0) {
        foreach ($c in $wmiSuspect) {
            Log ("  ⚠️  [WMI常驻] {0} | 名称: {1} | {2}" -f $c.Class, $c.Name, $c.Detail)
            $lvl = if ($c.Class -match 'Consumer') { '🔴' } else { '🟡' }
            Add-Finding 'T19' 'WMI持久化常驻' $lvl "root\subscription:$($c.Class):$($c.Name)" 0 'n/a' "待核实：$($c.Detail)"
        }
    } else { Log ("  ✅ 未检测到第三方 WMI 永久事件订阅（系统自带 {0} 项已忽略）" -f @($wmi.Items).Count) }
}

# 2. 桌面与开始菜单 LNK 快捷方式参数审计（检测劫持推广参数）
$shell = New-Object -ComObject WScript.Shell
$lnkDirs = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu')
)
$hijackedLnks = 0
foreach ($dir in $lnkDirs) {
    if ($dir -and (Test-Path -LiteralPath $dir)) {
        Get-ChildItem -LiteralPath $dir -Filter *.lnk -Recurse -EA SilentlyContinue | ForEach-Object {
            try {
                $sc = $shell.CreateShortcut($_.FullName)
                if ($sc.Arguments -match 'http|www\.|\.com|\.cn|channel=|tn=|--flag') {
                    Log ("  ⚠️  [快捷方式劫持] {0} -> 参数: {1}" -f $_.Name, $sc.Arguments)
                    Add-Finding 'T19' 'LNK参数劫持' '🟡' $_.FullName 0 'n/a' "参数: $($sc.Arguments)"
                    $hijackedLnks++
                }
            } catch { Write-Verbose "读不了快捷方式：$($_.Exception.Message)" }
        }
    }
}
if ($hijackedLnks -eq 0) { Log "  ✅ 未发现带可疑推广网址或启动参数的快捷方式" }
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

# ===== [T21] CompactOS 压缩状态 =====
Log "=== [T21] CompactOS 压缩状态 ==="
$compactQuery = & compact.exe /compactos:query 2>$null
if ($compactQuery) {
    $cState = ($compactQuery | Out-String).Trim()
    Log "  $cState"
} else {
    Log "  CompactOS: 未能获取状态"
}
Log ""

# ===== [EXT] 扩展审计模板（t23/t24/t25，存在才跑）=====
Log "=== [EXT] 扩展审计模板 ==="
$extTemplates = @(
    @{ L='T23 浏览器劫持审计'; F='t23-audit-browser-hijack.ps1' },
    @{ L='T24 扩展自启动审计'; F='t24-audit-autostart-extended.ps1' },
    @{ L='T25 已安装程序清单'; F='t25-inventory-programs.ps1' }
)
$extFound = 0
foreach ($et in $extTemplates) {
    $tp = Join-Path $PSScriptRoot (Join-Path 'templates' $et.F)
    if (-not (Test-Path -LiteralPath $tp)) { continue }
    $extFound++
    Log "  --- $($et.L) ($($et.F)) ---"
    $t0 = Get-Date
    try {
        $out = @(& $tp)
        Log ("    完成（屏幕明细见上方）：返回 {0} 个结果对象，用时 {1:N1} 秒" -f $out.Count, ((Get-Date) - $t0).TotalSeconds)
        $preview = @($out | Select-Object -First 3 | ForEach-Object { if ($_ -is [string]) { $_ } else { ($_ | Out-String -Width 160).Trim() } })
        foreach ($pl in $preview) { foreach ($ln in ($pl -split "`r?`n" | Select-Object -First 4)) { Log "    $ln" } }
        if ($out.Count -gt 3) { Log "    …（其余 $($out.Count - 3) 条见该模板单独运行的输出）" }
    } catch {
        Log "    ⚠️  运行失败：$($_.Exception.Message)"
    }
}
if ($extFound -eq 0) { Log "  未找到模板，跳过" }
Log ""

# ===== 自动画像反推 =====
Log "===== 画像自动反推 ====="
$personas = @()
# 家庭：WPS / 360 / 2345 / 腾讯管家
$wpsFamily = $findings | Where-Object { $_.Path -match 'WPS|Kingsoft|360|2345|QQPCMgr' }
if ($wpsFamily) { $personas += '🏠 家庭用户（装了 WPS/360/2345/腾讯管家等）' }
# 开发者：直接看常见开发工具目录是否存在（不只看残留列表）
$devMarkers = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code", "$env:USERPROFILE\.vscode", "$env:LOCALAPPDATA\JetBrains",
                "$env:LOCALAPPDATA\Programs\Python", "$env:APPDATA\npm", "$env:USERPROFILE\.cargo", "$env:USERPROFILE\.gradle",
                "$env:ProgramFiles\Docker", "$env:USERPROFILE\.codex", "$env:USERPROFILE\.gemini")
$devPaths = $devMarkers | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if ($devPaths) { $personas += '👨‍💻 开发者（装了 VS Code/JetBrains/Python 等开发工具）' }
# AI 创作者 / 虚拟化用户：本地大模型、WSL2、Docker、AVD 镜像
$aiPaths = $findings | Where-Object { $_.Type -eq 'AI与虚拟化缓存' -or $_.Path -match 'ollama|huggingface|modelscope|\.android\\avd|\.vhdx' }
if ($aiPaths) { $personas += '🤖 AI创作者/虚拟化用户（存在本地大模型/WSL/Docker/AVD虚拟磁盘）' }
# 游戏玩家
$steamProc = Get-Process Steam -EA SilentlyContinue
if ($steamProc) { $personas += '🎮 游戏玩家（Steam 在跑）' }
# OEM 笔记本
if ($ps -match 'Acer|Lenovo|Dell|ASUS|HP|Huawei') {
    $personas += '💻 笔记本/OEM（厂商电源方案）'
}
if ($personas.Count -gt 0) {
    Log "  你的画像："
    $personas | ForEach-Object { Log "    $_" }
} else {
    Log "  未识别出明显画像，按通用用户处理"
}
Log ""

# ===== 发现汇总（按档位）=====
Log "===== [SUM] 发现汇总（按档位）====="
if ($findings.Count -eq 0) {
    Log "  未发现需要处理的项"
} else {
    $findings | Group-Object Level | Sort-Object Name | ForEach-Object {
        $sum = ($_.Group | Measure-Object SizeMB -Sum).Sum
        Log ("  {0} {1} 项，合计 {2:N1} MB" -f $_.Name, $_.Count, $sum)
        $_.Group | Sort-Object SizeMB -Descending | Select-Object -First 5 | ForEach-Object {
            Log ("      [{0}] {1}  {2} MB  {3}" -f $_.Template, $_.Type, $_.SizeMB, $_.Path)
        }
    }
}
Log ("  扫描耗时 {0:N0} 秒" -f ((Get-Date) - $script:startTime).TotalSeconds)
Log ""

# ===== 写盘 =====
$script:lines | Out-File -LiteralPath $report -Encoding UTF8
Write-Host ""
Write-Host "===== 报告已生成 ====="
Write-Host "路径: $report"
Write-Host "发现数: $($findings.Count) 项"

# 还原控制台编码
Restore-ConsoleEncoding
