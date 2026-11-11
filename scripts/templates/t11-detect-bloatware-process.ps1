# 模板 11：detect-bloatware-process（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 11 节。只读：只报告命中项和证据，不结束进程、不停服务、不禁用任务。
# v2.1：标识来自 data/bloatware-catalog.json（Get-WcoBloatwareCatalog）；文件不存在时退回下方内置进程名单。
#       同时匹配正在运行的进程、已注册的服务和计划任务。置信度 low 的家族只算"疑似，需实机确认"。
param([string]$CatalogPath)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# 内置后备名单（catalog 缺失时使用，均按低置信度处理）
$builtinProcesses = @(
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

# 用户主动保留的白名单（进程名 / 服务名 / 任务名都适用）
$whitelist = @("DeskGo","DesktopMgr64","Steam","wallpaper32","WallpaperEngine","HuorongEs")

function Get-ListProp {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return @() }
    $p = $Obj.PSObject.Properties[$Name]
    if (-not $p -or $null -eq $p.Value) { return @() }
    return @($p.Value | Where-Object { $_ } | ForEach-Object { [string]$_ })
}

function Test-IdMatch {
    # 标识可含通配符 * ?；不含时按完全相等（不区分大小写）
    param([string]$Value, [string[]]$Patterns)
    foreach ($pat in $Patterns) {
        if (-not $pat) { continue }
        if ($pat.Contains('*') -or $pat.Contains('?')) { if ($Value -like $pat) { return $pat } }
        elseif ($Value -eq $pat) { return $pat }
    }
    return $null
}

# === 载入特征库 ===
$families = @()
$source = ''
try {
    $cat = if ($CatalogPath) { Get-WcoBloatwareCatalog -Path $CatalogPath } else { Get-WcoBloatwareCatalog }
    foreach ($f in @($cat.families)) {
        if ($null -eq $f) { continue }
        $families += [pscustomobject]@{
            Id         = [string]$f.id
            Name       = [string]$f.name
            Confidence = [string]$f.confidence
            Processes  = @(Get-ListProp $f 'processes' | ForEach-Object { $_ -replace '(?i)\.exe$', '' })
            Services   = @(Get-ListProp $f 'services')
            Tasks      = @(Get-ListProp $f 'tasks')
        }
    }
    $source = "data/bloatware-catalog.json（$($families.Count) 个家族，核对日期 $($cat.verified_at)）"
} catch {
    $families = @([pscustomobject]@{ Id = 'builtin'; Name = '内置名单'; Confidence = 'low'; Processes = $builtinProcesses; Services = @(); Tasks = @() })
    $source = "内置进程名单（未找到 catalog：$($_.Exception.Message)）"
}
Write-Host "特征来源：$source"

# === 采集（只读）===
$procs = @(Get-Process -ErrorAction SilentlyContinue)
$services = @()
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    $services = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, State, StartMode, PathName)
}
if ($services.Count -eq 0 -and (Get-Command Get-Service -ErrorAction SilentlyContinue)) {
    $services = @(Get-Service -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, @{ N = 'State'; E = { $_.Status } }, @{ N = 'StartMode'; E = { $_.StartType } }, @{ N = 'PathName'; E = { '' } })
}
$tasks = @()
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) { $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue) }

# === 匹配 ===
$hits = @()
foreach ($fam in $families) {
    $level = if ($fam.Confidence -eq 'low') { '疑似，需实机确认' } else { "置信度 $($fam.Confidence)" }
    if ($fam.Processes.Count -gt 0) {
        $procs | Where-Object { $_.ProcessName -notin $whitelist } | Group-Object ProcessName | ForEach-Object {
            $pat = Test-IdMatch $_.Name $fam.Processes
            if ($pat) {
                $first = $_.Group | Select-Object -First 1
                $mb = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 0)
                $hits += [pscustomobject]@{ Family = $fam.Name; Level = $level; Kind = '进程'; Text = "[$($_.Count)x] $($_.Name) - 路径: $($first.Path) - 占用: $mb MB" }
            }
        }
    }
    if ($fam.Services.Count -gt 0) {
        foreach ($s in $services) {
            if ($s.Name -in $whitelist) { continue }
            $pat = Test-IdMatch ([string]$s.Name) $fam.Services
            if ($pat) {
                $hits += [pscustomobject]@{ Family = $fam.Name; Level = $level; Kind = '服务'; Text = "$($s.Name)（$($s.DisplayName)）- 状态: $($s.State) - 启动类型: $($s.StartMode) - 程序: $($s.PathName)" }
            }
        }
    }
    if ($fam.Tasks.Count -gt 0) {
        foreach ($t in $tasks) {
            if ($t.TaskName -in $whitelist) { continue }
            $full = "$($t.TaskPath)$($t.TaskName)"
            $pat = Test-IdMatch ([string]$t.TaskName) $fam.Tasks
            if (-not $pat) { $pat = Test-IdMatch $full $fam.Tasks }
            if ($pat) {
                $exec = @($t.Actions | ForEach-Object { if ($_.PSObject.Properties['Execute'] -and $_.Execute) { "$($_.Execute) $($_.Arguments)".Trim() } }) -join '; '
                $hits += [pscustomobject]@{ Family = $fam.Name; Level = $level; Kind = '计划任务'; Text = "$full - 状态: $($t.State) - 动作: $exec" }
            }
        }
    }
}

# === 输出 ===
if ($hits.Count -gt 0) {
    $hits | Group-Object Family | ForEach-Object {
        $g = $_.Group
        "== $($_.Name)（$($g[0].Level)）=="
        $g | ForEach-Object { "  [$($_.Kind)] $($_.Text)" }
    }
    Write-Host '以上仅为识别结果。处置前请核对路径与签名（模板 25 可看发行商/签名置信度）；停用服务、禁用任务请用 Set-WcoServiceStartType / Disable-WcoScheduledTask（默认演练，-Apply 才执行）。'
} else {
    "未检测到已知 bloatware 进程、服务或计划任务"
}
