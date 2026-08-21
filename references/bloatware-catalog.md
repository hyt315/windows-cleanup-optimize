# 中国特色流氓软件/捆绑软件 识别清单

> 覆盖 30+ 中国用户常见的"流氓软件"（弹窗广告、捆绑安装、自我保护难卸载）。每个条目含**进程名、安装目录、AppData 路径、行为特征、推荐处理**——扫描时直接对比即可识别。完整卸载流程见 `software-uninstall.md`。

---

## 目录

- [使用方式](#使用方式)
- [多路径检测方法学（2026-08 实战沉淀）](#多路径检测方法学2026-08-实战沉淀)
- [1. 安全软件类](#1-安全软件类)
- [2. 下载工具类](#2-下载工具类)
- [3. 输入法类](#3-输入法类)
- [4. 桌面整理/壁纸类](#4-桌面整理壁纸类)
- [5. 浏览器捆绑类](#5-浏览器捆绑类)
- [6. 弹窗广告/资讯类](#6-弹窗广告资讯类)
- [7. 办公软件捆绑类](#7-办公软件捆绑类)
- [8. 媒体/其他类](#8-媒体其他类)
- [PowerShell 批量识别脚本](#powershell-批量识别脚本)
- [替代软件推荐](#替代软件推荐)

---

## 使用方式

**审计时**：
1. 运行 `startup-audit.md` 的完整脚本，输出进程列表
2. 进程名与本节表格的"进程名 (ProcessName)"列对比
3. 命中的项按"推荐处理"列分级：❌ 不推荐 / ⚠️ 可选 / ✅ 推荐保留
4. ❌ 项进入第三档，**必须用户确认**才能卸载

**判断要点**：
- **进程名是关键词**：进程名含 `360`、`2345`、`Kingsoft`、`Baidu` 等前缀通常都是 bloatware
- **安装目录 + AppData 同时存在**：说明这个软件正在用——可能是用户主动选择（如火绒、DeskGo）
- **注册表 DisplayName 模糊**：很多 bloatware 用拼音或缩写显示名（如"今日热点"）

## 多路径检测方法学（2026-08 实战沉淀）

**重要**：本目录中"安装目录"列出的路径是**约定俗成的标准位置**（如 `C:\Program Files (x86)\Kingsoft\WPS Office`），但现实中很多软件从第三方渠道安装时**会装到非标准位置**（如 `<自定义安装根>/WPS Office/`），导致硬编码搜索全部 miss。**永远不要用硬编码路径作为"软件不存在"的判据**。

**正确流程**：

1. **从注册表 Uninstall 反推真实路径**（首选、最可靠）：
   ```powershell
   Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
       Where-Object { $_.DisplayName -match 'WPS|Kingsoft|有道|腾讯|阿里|360|2345|百度' } |
       Select-Object DisplayName, InstallLocation, DisplayVersion
   ```
   这条命令**对所有路径都有效**——不管装在 C 还是 D、Standard 还是非 Standard。

2. **多候选根扫描（兜底）**：
   ```powershell
   $roots = @(
       'C:\Program Files',
       'C:\Program Files (x86)',
       'D:\Program Files',
       'D:\Program Files (x86)',
       "$env:LOCALAPPDATA\Programs",
       '<自定义安装根>'    # 用户 用户常见自定义区
   )
   foreach ($root in $roots) {
       if (-not (Test-Path $root)) { continue }
       Get-ChildItem $root -Directory -Force -EA SilentlyContinue | ForEach-Object {
           $dirLower = $_.Name.ToLower()
           if ($dirLower -match 'wps|kingsoft') {
               $size = (Get-ChildItem $_.FullName -Recurse -Force -EA SilentlyContinue |
                       Measure-Object Length -Sum -EA SilentlyContinue).Sum / 1GB
               Write-Host ("{0}  {1}GB  {2}" -f $_.Name, [math]::Round($size,1), $_.FullName)
           }
       }
   }
   ```

3. **进程路径作为终极兜底**：如果某软件安装目录找不到，但有对应进程在运行，直接读进程路径（`Get-Process | Select Name, Path`）。

4. **D 盘根目录扫描策略不同**：D 盘等非系统盘结构完全由用户习惯决定，没有统一模式。**根目录一级展开**后按大小排序识别（详见 SKILL.md 阶段 1.5）。

**实战教训**：2026-08 案例中，WPS 装在 `<自定义安装根>/WPS Office/<版本号>/office6/`，标准路径全部失效。改用注册表反查后立即定位到真实安装目录，进而找到 `wps.exe`、`ksolaunch.exe`、`wpscloudsvr.exe`、`wpsupdate.exe` 等关键二进制，最终完整修复了"自动升级反复复活"问题。

---

## 1. 安全软件类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **360 安全卫士** | `360safe.exe`, `360sd.exe`, `ZhuDongFangYu.exe` | `C:\Program Files (x86)\360\360safe` | `%APPDATA%\360safe`, `C:\ProgramData\360safe` | 弹窗、首页劫持、内核驱动自我保护 | ❌ |
| **360 杀毒** | `360sd.exe`, `360SafeClean.exe` | `C:\Program Files (x86)\360杀毒` | `%APPDATA%\360sd` | 同上 | ❌ |
| **360 Total Security** | `360TSMain.exe`, `QHWatchdog.exe` | `C:\Program Files\360\Total Security` | `C:\ProgramData\360TotalSecurity` | 国际版同样弹窗捆绑 | ❌ |
| **2345 安全卫士** | `2345Safe.exe`, `2345Guard.exe`, `2345Live.exe` | `C:\Program Files (x86)\2345安全卫士` | `%APPDATA%\2345Security` | 首页劫持 (2345 导航)、弹窗 | ❌ |
| **腾讯电脑管家** | `QQPCMgr.exe`, `QQPCRtp.exe`, `TQMCenter.exe` | `C:\Program Files (x86)\Tencent\PCMgr` | `%APPDATA%\Tencent\PCMgr` | 捆绑安装、弹窗（比 360 温和） | ⚠️ |
| **金山毒霸** | `KSAVSvc.exe`, `kxescore.exe`, `kxetray.exe` | `C:\Program Files (x86)\Kingsoft\KSafe` | `%APPDATA%\kingsoft` | 弹窗、首页劫持 | ❌ |
| **火绒安全** | `HuorongEs.exe`, `HipsDaemon.exe` | `C:\Program Files (x86)\Huorong` | `%APPDATA%\Huorong` | **无弹窗、无捆绑** | ✅ |
| **鲁大师** | `LDSMain.exe`, `LDSService.exe` | `C:\Program Files (x86)\LuDaShi` | `%APPDATA%\LuDaShi` | 弹窗广告、捆绑 | ❌ |
| **驱动精灵** | `DriverGenius.exe`, `DGService.exe` | `C:\Program Files (x86)\MyDrivers\DriverGenius` | `%APPDATA%\MyDrivers` | 捆绑、弹窗（Win10/11 自带驱动更新） | ❌ |
| **驱动人生** | `DTLSoft.exe`, `DrvLife.exe` | `C:\Program Files (x86)\DTLSoft\驱动人生` | `%APPDATA%\DTLSoft` | 捆绑、弹窗 | ❌ |

**360 家族内核驱动**（需专用工具处理）：
- `360AvFlt` / `360Box` / `360FsFlt` / `360SelfProtection`

---

## 2. 下载工具类

| 软件 | 进程名 | 安装目录 | AppData | 行为 | 推荐 |
|------|--------|----------|---------|------|------|
| **迅雷** | `Thunder.exe`, `ThunderKernel.exe` | `C:\Program Files (x86)\Thunder Network\Thunder` | `%APPDATA%\Thunder Network` | 捆绑、P2P 后台上传、弹窗 | ⚠️ |
| **QQ 旋风**（已停服） | `QQDownload.exe`（残留） | 残留于 `C:\Program Files (x86)\Tencent\QQ旋风` | `%APPDATA%\Tencent\QQDownload` | 已停服，残留可清 | ❌（残留） |

---

## 3. 输入法类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **搜狗输入法** | `SogouService.exe`, `SogouIM.exe`, `SGMain.exe` | `C:\Program Files (x86)\SogouInput` | `%APPDATA%\SogouPY` | 词库弹窗、推荐装浏览器 | ⚠️ |
| **2345 输入法** | `2345Ime.exe`, `2345Pinyin.exe` | `C:\Program Files (x86)\2345输入法` | `%APPDATA%\2345Ime` | 捆绑、弹窗 | ❌ |
| **QQ 输入法** | `QQPinyin.exe`, `QQPinyinService.exe` | `C:\Program Files (x86)\Tencent\QQPinyin` | `%APPDATA%\Tencent\QQPinyin` | 相对温和 | ⚠️ |

---

## 4. 桌面整理/壁纸类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **腾讯桌面整理 (DeskGo)** | `DeskGo.exe`, `DesktopMgr64.exe` | `C:\Program Files (x86)\Tencent\DeskGo` | `%APPDATA%\Tencent\DeskGo` | **无广告**，功能实用 | ✅（用户主动选择） |
| **360 桌面助手** | `360Desktop.exe`, `360DesktopLite.exe` | `C:\Program Files (x86)\360\360DesktopLite` | `%APPDATA%\360DesktopLite` | 弹窗、捆绑 | ❌ |
| **金山桌面** | `KingsoftDesktop.exe` | `C:\Program Files (x86)\Kingsoft\KingsoftDesktop` | `%APPDATA%\kingsoft\Desktop` | 捆绑 | ❌ |
| **魔镜壁纸** | `MojingWallpaper.exe` | `C:\Program Files (x86)\MojingWallpaper` | `%APPDATA%\MojingWallpaper` | 弹窗、修改桌面 | ❌ |
| **好桌道壁纸** | `HaoZhuoDao.exe` | `C:\Program Files (x86)\好桌道` | `%APPDATA%\HaoZhuoDao` | 弹窗、篡改 | ❌ |

---

## 5. 浏览器捆绑类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **2345 浏览器** | `2345Explorer.exe` | `C:\Program Files (x86)\2345浏览器` | `%APPDATA%\2345Explorer` | **首页劫持 (2345 导航)** | ❌ |
| **360 安全浏览器** | `360se.exe`, `360chrome.exe` | `C:\Program Files (x86)\360\360SE` | `%APPDATA%\360se` | 捆绑、首页篡改 | ❌ |
| **QQ 浏览器** | `QQBrowser.exe` | `C:\Program Files (x86)\Tencent\QQBrowser` | `%APPDATA%\Tencent\QQBrowser` | 捆绑、与 QQ 联动 | ❌ |
| **搜狗浏览器** | `SogouExplorer.exe` | `C:\Program Files (x86)\SogouExplorer` | `%APPDATA%\SogouExplorer` | 首页劫持 | ❌ |
| **UC 浏览器 PC**（已停产） | `UCBrowser.exe`（残留） | `C:\Program Files (x86)\UCBrowser` | `%APPDATA%\UCBrowser` | 卸载残留 | ❌（残留） |

---

## 6. 弹窗广告/资讯类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **Flash 中心** | `FlashCenter.exe`, `FlashHelperService.exe` | `C:\Program Files (x86)\FlashCenter` | `%APPDATA%\FlashCenter` | **伪装成 Adobe Flash**，实为广告 | ❌ |
| **今日热点** | `TodayHot.exe`, `NewsPush.exe` | `C:\Program Files (x86)\今日热点` | `%APPDATA%\TodayHot` | 系统右下角弹新闻 | ❌ |
| **热点资讯** | `HotNews.exe` | 随其他软件安装 | - | 弹窗推送 | ❌ |
| **2345 看图王** | `2345Pic.exe` | `C:\Program Files (x86)\2345看图王` | `%APPDATA%\2345Pic` | 弹窗、捆绑 | ❌ |
| **2345 好压** | `HaoZip.exe` | `C:\Program Files (x86)\2345好压` | `%APPDATA%\2345HaoZip` | 弹窗、捆绑、右键劫持 | ❌ |

---

## 7. 办公软件捆绑类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **WPS Office** | `wps.exe`, `wpscloud.exe`, `wpscenter.exe` | `C:\Program Files (x86)\Kingsoft\WPS Office` | `%APPDATA%\kingsoft\office6` | **广告弹窗**（WPS 收入来源）、推荐装其他软件 | ⚠️（关闭广告可用） |
| **福昕阅读器（免费版）** | `FoxitReader.exe` | `C:\Program Files (x86)\Foxit Software\Foxit Reader` | `%APPDATA%\Foxit Software` | 捆绑、弹窗 | ⚠️ |

**WPS 处理细节**（常见需求）：
- WPS Office 本体功能可用，**只是广告多**
- 关闭广告路径：WPS 设置 → 推送与广告 → 全部关闭
- 后台进程 `wpscloudsvr.exe` 占用资源——可在 WPS 设置关闭"云服务"
- 详细清理见 `software-uninstall.md` 的 WPS 专项章节

---

## 8. 媒体/其他类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **暴风影音**（残留） | `StormPlayer.exe` | `C:\Program Files (x86)\StormPlayer` | `%APPDATA%\Baofeng` | 已衰落 | ❌（残留） |
| **PPS / PPTV**（残留） | `PPStream.exe`, `PPTV.exe` | 残留于各自目录 | `%APPDATA%\PPStream` | 服务已弱化 | ❌（残留） |
| **快压** | `KuaiZip.exe` | `C:\Program Files (x86)\快压` | `%APPDATA%\KuaiZip` | 弹窗、捆绑 | ❌ |
| **百度网盘** | `BaiduNetdisk.exe`, `baidunetdiskhost.exe` | `C:\Program Files (x86)\Baidu\BaiduNetdisk` | `%APPDATA%\Baidu\BaiduNetdisk` | 开机启动、弹窗、后台上传 | ⚠️ |
| **美图秀秀 PC 版** | `Meitu.exe`, `MeituViewer.exe` | `C:\Program Files (x86)\Meitu` | `%APPDATA%\Meitu` | 捆绑 | ❌ |

---

## PowerShell 批量识别脚本

把审计脚本输出与本节表格交叉比对：

```powershell
# 1. 加载已知 bloatware 进程名
$bloatwareProcesses = @(
    # 360 家族
    "360safe","360sd","ZhuDongFangYu","360TSMain","QHWatchdog","360SafeClean",
    # 2345 家族
    "2345Safe","2345Guard","2345Live","2345Ime","2345Pinyin","2345Explorer","2345Pic","HaoZip",
    # 金山/腾讯安全
    "KSAVSvc","kxescore","kxetray","QQPCMgr","QQPCRtp","TQMCenter",
    # 鲁大师/驱动工具
    "LDSMain","LDSService","DriverGenius","DGService","DTLSoft","DrvLife",
    # 输入法（搜狗/QQ 拼音）
    "SogouService","SogouIM","SGMain","QQPinyinService",
    # 桌面整理（注意 DeskGo 是保留项，需要白名单）
    "360Desktop","360DesktopLite","KingsoftDesktop","MojingWallpaper","HaoZhuoDao",
    # 浏览器
    "360se","360chrome","QQBrowser","SogouExplorer","UCBrowser",
    # 弹窗广告
    "FlashCenter","FlashHelperService","TodayHot","NewsPush","HotNews",
    # 其他
    "KuaiZip","BaiduNetdisk","Meitu"
)

# 2. 保留进程白名单（用户主动选择）
$whitelist = @("DeskGo","DesktopMgr64","Steam","wallpaper32","WallpaperEngine","HuorongEs")

# 3. 扫描当前运行的进程
$hits = Get-Process -EA SilentlyContinue | Where-Object {
    $_.ProcessName -in $bloatwareProcesses -and $_.ProcessName -notin $whitelist
}

if ($hits) {
    Write-Host "===== 检测到 bloatware 进程 ====="
    $hits | Group-Object ProcessName | ForEach-Object {
        "($($_.Count)x) $($_.Name) - 占用: $([math]::Round((($_.Group | Measure-Object WorkingSet -Sum).Sum)/1MB,0)) MB"
    }
} else {
    Write-Host "未检测到已知 bloatware 进程。"
}
```

---

## 替代软件推荐

| 原 bloatware | 推荐替代 | 优势 |
|--------------|----------|------|
| 360 安全卫士 | **火绒安全** / Windows Defender | 无广告无捆绑 |
| 2345 好压 / 快压 | **7-Zip** | 开源、无广告、支持格式更多 |
| 360 浏览器 / 2345 浏览器 | **Chrome / Edge / Firefox** | 干净、无劫持 |
| 福昕阅读器 | **SumatraPDF** | 轻量、无广告、便携 |
| 鲁大师 | **CPU-Z / HWMonitor** | 干净、无弹窗 |
| 驱动精灵 / 驱动人生 | Windows 自带驱动更新 | 系统集成 |
| 桌面整理（360/金山版） | **腾讯 DeskGo** | 无广告（用户主动选择） |
| WPS（可选保留） | WPS 关闭广告 / LibreOffice | 取决于需求 |
| 暴风影音 | **PotPlayer / VLC** | 干净、无广告 |
| 搜狗输入法 | Windows 自带输入法 / **微软拼音** | 系统集成、无弹窗 |

---

## 下一步

发现 bloatware 后：
1. 看用户是否同意卸载 → 调用 `software-uninstall.md` 标准卸载流程
2. 用户不想卸载但想关自启 → 调用 `startup-audit.md` 禁用自启项
3. 用户保留（如 DeskGo、Steam） → 不动，仅记录
