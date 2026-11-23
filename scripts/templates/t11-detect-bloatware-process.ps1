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

# === 载入特征库 ===
$source = ''
try {
    $cat = if ($CatalogPath) { Get-WcoBloatwareCatalog -Path $CatalogPath } else { Get-WcoBloatwareCatalog }
    $source = "data/bloatware-catalog.json（$(@($cat.families).Count) 个家族，核对日期 $($cat.verified_at)）"
} catch {
    # 特征库缺失时退回内置名单，统一按低置信度处理
    $cat = [pscustomobject]@{ families = @([pscustomobject]@{ id = 'builtin'; name = '内置名单'; confidence = 'low'; processes = $builtinProcesses }) }
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

# === 匹配（公共模块 Get-WcoCatalogHit，与 full_scan 同一套规则）===
$hits = @(Get-WcoCatalogHit -Catalog $cat -Process $procs -Service $services -Task $tasks -Whitelist $whitelist)

# === 输出 ===
if ($hits.Count -gt 0) {
    $hits | Group-Object Family | ForEach-Object {
        $g = $_.Group
        "== $($_.Name)（$($g[0].Level)，置信度 $($g[0].Confidence)）=="
        foreach ($h in $g) {
            $mem = if ($null -ne $h.MemoryMB) { " - 占用: $($h.MemoryMB) MB" } else { '' }
            $cnt = if ($h.Count -gt 1) { "[$($h.Count)x] " } else { '' }
            "  [$($h.Kind)] $cnt$($h.Name) - $($h.Path)$mem $($h.Detail)".TrimEnd()
        }
    }
    Write-Host '以上仅为识别结果。处置前请核对路径与签名（模板 25 可看发行商/签名置信度）；停用服务、禁用任务请用 Set-WcoServiceStartType / Disable-WcoScheduledTask（默认演练，-Apply 才执行）。'
} else {
    "未检测到特征库里的进程、服务或计划任务"
}
