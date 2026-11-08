# 模板 11：detect-bloatware-process（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 11 节。

$bloatwareProcesses = @(
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

# 用户主动保留的白名单
$whitelist = @("DeskGo","DesktopMgr64","Steam","wallpaper32","WallpaperEngine","HuorongEs")

$hits = Get-Process -EA SilentlyContinue | Where-Object {
    $_.ProcessName -in $bloatwareProcesses -and $_.ProcessName -notin $whitelist
}

if ($hits) {
    $hits | Group-Object ProcessName | ForEach-Object {
        $first = $_.Group | Select-Object -First 1
        "[$($_.Count)x] $($_.Name) - 路径: $($first.Path) - 占用: $([math]::Round((($_.Group | Measure-Object WorkingSet -Sum).Sum)/1MB,0)) MB"
    }
} else {
    "未检测到已知 bloatware 进程"
}
