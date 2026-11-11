# 流氓软件 / 捆绑软件 / 广告载体识别清单

> 覆盖中国用户常见的"流氓软件"（弹窗广告、捆绑安装、首页劫持、自我保护难卸载），以及 Windows 自带和 OEM 预装的推广内容。完整卸载流程见 `software-uninstall.md`。
>
> **识别特征的权威来源是 `data/bloatware-catalog.json`**（发行主体、签名者、进程、服务、计划任务、驱动、置信度、来源链接、核对日期）。本文表格是给人看的摘要；两者不一致时以 JSON 为准，改动标识符请改 JSON。表中进程名、目录名多来自历史报告和社区资料，厂商会改名，**标「需实机确认」的条目不能单独作为处置依据**。

---

## 目录

- [使用方式](#使用方式)
- [多路径检测方法学](#多路径检测方法学)
- [1. 安全软件类](#1-安全软件类)
- [2. 下载工具与网盘类](#2-下载工具与网盘类)
- [3. 输入法类](#3-输入法类)
- [4. 桌面整理/壁纸类](#4-桌面整理壁纸类)
- [5. 浏览器捆绑类](#5-浏览器捆绑类)
- [6. 弹窗广告/资讯类](#6-弹窗广告资讯类)
- [7. 办公软件捆绑类](#7-办公软件捆绑类)
- [8. 媒体/其他类](#8-媒体其他类)
- [8b. 补充家族（需实机确认）](#8b-补充家族需实机确认)
- [8c. 国际/OEM/商店预装](#8c-国际oem商店预装)
- [9. 不卸载只静音：弹窗处理（含 IFEO 风险）](#9-不卸载只静音弹窗处理含-ifeo-风险)
- [10. 快捷方式（.lnk / .url）参数劫持](#10-快捷方式lnk--url参数劫持)
- [11. 其他广告与劫持载体](#11-其他广告与劫持载体)
- [替代软件推荐](#替代软件推荐)

---

## 使用方式

**审计时**：
1. 跑只读模板 **T25**（`scripts/templates/t25-inventory-programs.ps1`）：列出已安装程序和商店应用，按发行主体、签名者、服务、任务对照 JSON 目录。签名/发行主体命中 = 高置信度；只有名字命中 = 低置信度，显示为"疑似，需人工确认"；目录里没有的第三方软件显示为"未知第三方"，不做任何动作。
2. 跑 **T11**（正在运行的进程，同样由 JSON 驱动）、**T23**（浏览器/网络劫持）、**T24**（自启扩展位置）、**T19**（快捷方式）。
3. 命中项按"推荐"列分级：❌ 建议卸载 / ⚠️ 可选（可只静音） / ✅ 建议保留。
4. ❌ 项也**必须用户确认**才进入卸载流程。

**判断要点**：
- **看签名和路径，不看文件名**：有的广告模块会把自己随机改名成安全软件的文件名（[火绒报告 803](https://www.huorong.cn/document/tech/vir_report/803)），只按进程名判断会漏报，也会误报。用 `Get-AuthenticodeSignature <exe>` 看签名者，再看安装目录归属。
- **同一发行主体名下可能既有正常软件又有广告组件**（例如金山的 WPS 与毒霸、腾讯的 QQ 与电脑管家），不能按发行主体一刀切。
- **安装目录 + AppData 同时存在**：说明软件在用——可能是用户主动选择的（如火绒、DeskGo）。
- **注册表 DisplayName 模糊**：很多推广软件用拼音或缩写显示名（如"今日热点"）；`SystemComponent=1` 或没有 `UninstallString` 的条目在控制面板里看不到，T25 会单独列出。

## 多路径检测方法学

本文"安装目录"列是**常见位置**，现实中很多软件从第三方渠道安装时会装到别处（例如 `<自定义安装根>\WPS Office\`）。**永远不要用硬编码路径作为"软件不存在"的判据。**

1. **从卸载注册表反推真实路径**（首选）：`Get-WcoInstalledProgram -Name '*WPS*'`（读 HKLM、HKLM\WOW6432Node、HKCU 三处卸载键，给出 InstallLocation、UninstallString、签名者）。没有模块时：
   ```powershell
   Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
       Where-Object { $_.DisplayName -match 'WPS|Kingsoft' } |
       Select-Object DisplayName, Publisher, InstallLocation, DisplayVersion
   ```
2. **多候选根扫描（兜底）**：`C:\Program Files`、`C:\Program Files (x86)`、其他盘的同名目录、`%LOCALAPPDATA%\Programs`、用户自定义安装区，只展开一级目录按名字和大小识别。
3. **进程路径作为最后兜底**：软件在运行但找不到安装目录时，读 `Get-Process | Select-Object Name, Path`。
4. **非系统盘根目录**：结构由用户习惯决定，根目录一级展开后按大小排序识别（详见 SKILL.md）。

---

## 1. 安全软件类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **360 安全卫士** | `360safe.exe`, `360sd.exe`, `ZhuDongFangYu.exe`（托盘进程常见为 `360Tray.exe`，需实机确认） | `C:\Program Files (x86)\360\360safe` | `%APPDATA%\360safe`, `C:\ProgramData\360safe` | 弹窗、首页劫持、内核驱动自我保护 | ❌ |
| **360 杀毒** | `360sd.exe`, `360SafeClean.exe` | `C:\Program Files (x86)\360杀毒` | `%APPDATA%\360sd` | 同上 | ❌ |
| **360 Total Security** | `360TSMain.exe`, `QHWatchdog.exe` | `C:\Program Files\360\Total Security` | `C:\ProgramData\360TotalSecurity` | 国际版同样弹窗捆绑 | ❌ |
| **2345 安全卫士** | `2345Safe.exe`, `2345Guard.exe`, `2345Live.exe` | `C:\Program Files (x86)\2345安全卫士` | `%APPDATA%\2345Security` | 首页劫持（2345 导航）、弹窗 | ❌ |
| **腾讯电脑管家** | `QQPCMgr.exe`, `QQPCRtp.exe`, `TQMCenter.exe` | `C:\Program Files (x86)\Tencent\PCMgr` | `%APPDATA%\Tencent\PCMgr` | 捆绑安装、弹窗（比 360 温和） | ⚠️ |
| **金山毒霸** | `KSAVSvc.exe`, `kxescore.exe`, `kxetray.exe` | `C:\Program Files (x86)\Kingsoft\KSafe` | `%APPDATA%\kingsoft` | 弹窗、首页劫持 | ❌ |
| **火绒安全** | `HuorongEs.exe`, `HipsDaemon.exe` | `C:\Program Files (x86)\Huorong` | `%APPDATA%\Huorong` | 无弹窗广告、无捆绑 | ✅ |
| **鲁大师** | `LDSMain.exe`, `LDSService.exe`（也有报告为 `ComputerZ_*.exe`，需实机确认） | `C:\Program Files (x86)\LuDaShi` | `%APPDATA%\LuDaShi` | 弹窗广告、捆绑 | ❌ |
| **驱动精灵** | `DriverGenius.exe`, `DGService.exe` | `C:\Program Files (x86)\MyDrivers\DriverGenius` | `%APPDATA%\MyDrivers` | 捆绑、弹窗（Windows 自带驱动更新可替代） | ❌ |
| **驱动人生** | `DTLSoft.exe`, `DrvLife.exe` | `C:\Program Files (x86)\DTLSoft\驱动人生` | `%APPDATA%\DTLSoft` | 捆绑、弹窗 | ❌ |

**360 家族内核驱动**：`360AvFlt` / `360Box` / `360FsFlt` / `360SelfProtection`。它们多为过滤驱动，`pnputil /enum-drivers` 不一定列得出来；用 `Get-CimInstance Win32_SystemDriver` 或管理员 `fltmc filters` 查看。处理顺序见 `software-uninstall.md` 360 节。

---

## 2. 下载工具与网盘类

| 软件 | 进程名 / 服务名 | 安装目录 | AppData | 行为与后台机制 | 推荐 |
|------|--------|----------|---------|------|------|
| **迅雷** | `Thunder.exe`, `ThunderKernel.exe`, 服务 `XLServicePlatform`, `ThunderNetwork` | `C:\Program Files (x86)\Thunder Network\Thunder` | `%APPDATA%\Thunder Network` | 捆绑、常驻 P2P 上传服务（退出软件后服务仍在）、弹窗 | ⚠️（需关服务） |
| **百度网盘** | `baidunetdisk.exe`, `baidunetdiskhost.exe`, 服务 `YunDetectService` | `%APPDATA%\Baidu\BaiduNetdisk` 或 `%ProgramFiles%\Baidu` | `%APPDATA%\Baidu\BaiduNetdisk` | 退出后 `YunDetectService` 仍常驻、右键扩展 | ⚠️（需关服务） |
| **夸克网盘** | `Quark.exe`, `QuarkServices.exe` | `%LOCALAPPDATA%\Programs\Quark` | `%APPDATA%\Quark` | 开机常驻、临时分片文件占用 C 盘 | ⚠️ |
| **QQ 旋风**（已停服） | `QQDownload.exe`（残留） | `C:\Program Files (x86)\Tencent\QQ旋风` | `%APPDATA%\Tencent\QQDownload` | 已停服，残留可清 | ❌（残留） |

---

## 3. 输入法类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **搜狗输入法** | `SogouService.exe`, `SogouCloud.exe`, `SGDownload.exe`, `PinyinUp.exe`, `SogouNews.exe` | `C:\Program Files (x86)\SogouInput` | `%APPDATA%\SogouPY` | 打字时随输入法拉起 `SogouCloud`（云候选）与 `SGDownload`（弹窗/下载器） | ⚠️（关弹窗即可） |
| **2345 输入法** | `2345Ime.exe`, `2345Pinyin.exe` | `C:\Program Files (x86)\2345输入法` | `%APPDATA%\2345Ime` | 捆绑、弹窗 | ❌ |
| **QQ 输入法** | `QQPinyin.exe`, `QQPinyinService.exe` | `C:\Program Files (x86)\Tencent\QQPinyin` | `%APPDATA%\Tencent\QQPinyin` | 相对温和 | ⚠️ |

---

## 4. 桌面整理/壁纸类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **腾讯桌面整理 (DeskGo)** | `DeskGo.exe`, `DesktopMgr64.exe` | `C:\Program Files (x86)\Tencent\DeskGo` | `%APPDATA%\Tencent\DeskGo` | 无广告，功能实用 | ✅（用户主动选择） |
| **360 桌面助手** | `360Desktop.exe`, `360DesktopLite.exe` | `C:\Program Files (x86)\360\360DesktopLite` | `%APPDATA%\360DesktopLite` | 弹窗、捆绑 | ❌ |
| **金山桌面** | `KingsoftDesktop.exe` | `C:\Program Files (x86)\Kingsoft\KingsoftDesktop` | `%APPDATA%\kingsoft\Desktop` | 捆绑 | ❌ |
| **魔镜壁纸** | `MojingWallpaper.exe` | `C:\Program Files (x86)\MojingWallpaper` | `%APPDATA%\MojingWallpaper` | 弹窗、修改桌面 | ❌ |
| **好桌道壁纸** | `HaoZhuoDao.exe` | `C:\Program Files (x86)\好桌道` | `%APPDATA%\HaoZhuoDao` | 弹窗、篡改 | ❌ |
| **小鸟壁纸**（需实机确认） | 安装目录名线索 `BirdWallpaper` | — | — | 捆绑安装、弹窗 | ❌ |
| **其他壁纸类**（需实机确认） | 目录名线索 `360bizhi`、`66bizhi`、`aibizhi`、`yuanqizhuomianbizhi`（元气桌面壁纸） | — | — | 捆绑、弹窗 | ⚠️ 先问用户 |

> 目录名线索来源：[AzureIvory/block-ads note.txt](https://raw.githubusercontent.com/AzureIvory/block-ads/block-ads1.1/note.txt)（许可未声明，只作线索，未整表搬运）。

---

## 5. 浏览器捆绑类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **2345 浏览器** | `2345Explorer.exe` | `C:\Program Files (x86)\2345浏览器` | `%APPDATA%\2345Explorer` | 首页劫持（2345 导航） | ❌ |
| **360 安全浏览器** | `360se.exe`, `360chrome.exe` | `C:\Program Files (x86)\360\360SE` | `%APPDATA%\360se` | 捆绑、首页篡改 | ❌ |
| **QQ 浏览器** | `QQBrowser.exe` | `C:\Program Files (x86)\Tencent\QQBrowser` | `%APPDATA%\Tencent\QQBrowser` | 捆绑、抢默认浏览器 | ❌ |
| **搜狗浏览器** | `SogouExplorer.exe` | `C:\Program Files (x86)\SogouExplorer` | `%APPDATA%\SogouExplorer` | 首页劫持、抢默认浏览器 | ❌ |
| **UC 浏览器 PC**（已停产） | `UCBrowser.exe`（残留） | `C:\Program Files (x86)\UCBrowser` | `%APPDATA%\UCBrowser` | 卸载残留 | ❌（残留） |
| **购物/降价助手类**（需实机确认） | 多以浏览器扩展 + 桌面助手形式出现（"比价""返利""降价提醒"） | — | — | 改搜索/首页、注入购物推广 | ❌ |

---

## 6. 弹窗广告/资讯类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **Flash 中心**（重庆重橙） | `FlashCenter.exe`, `FlashHelperService.exe`, `FFNewTask.exe` | `C:\Program Files (x86)\FlashCenter` | `%APPDATA%\FlashCenter` | 以 Flash 国内版名义分发，弹窗推广（Flash 已停止支持，无需保留） | ❌ |
| **今日热点** | `TodayHot.exe`, `NewsPush.exe` | `C:\Program Files (x86)\今日热点` | `%APPDATA%\TodayHot` | 右下角弹新闻 | ❌ |
| **热点资讯** | `HotNews.exe` | 随其他软件安装 | - | 弹窗推送 | ❌ |
| **2345 看图王** | `2345Pic.exe` | `C:\Program Files (x86)\2345看图王` | `%APPDATA%\2345Pic` | 弹窗、捆绑、抢图片默认打开方式 | ❌ |
| **2345 好压** | `HaoZip.exe`, `HaoZipPopup.exe` | `C:\Program Files (x86)\2345好压` | `%APPDATA%\2345HaoZip` | 弹窗、捆绑、右键扩展 | ❌ |
| **"XX 看图 / XX PDF / XX 压缩"类**（需实机确认） | 名称各异，常见特征：免费工具 + 抢文件关联 + 右键扩展 + 推广弹窗 | — | — | 抢 `.jpg/.png/.pdf/.zip` 默认程序 | ❌ |
| **"蓝屏修复 / 一键修复 / C 盘清理大师"类**（需实机确认） | 名称各异；目录名线索 `Clean Master`、`ToWinCleaner` | — | — | 夸大问题吓唬用户（"发现 999 个问题"）、诱导付费或装软件 | ❌ |

---

## 7. 办公软件捆绑类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **WPS Office** | `wps.exe`, `wpscloudsvr.exe`, `wpscenter.exe`, `ksolaunch.exe`, `ksobulletin.exe` | `C:\Program Files (x86)\Kingsoft\WPS Office` | `%APPDATA%\kingsoft\office6` | 广告弹窗、推荐装其他软件、更新任务反复重建 | ⚠️（关闭广告可用） |
| **福昕阅读器（免费版）** | `FoxitReader.exe` | `C:\Program Files (x86)\Foxit Software\Foxit Reader` | `%APPDATA%\Foxit Software` | 捆绑、弹窗 | ⚠️ |

**WPS 处理要点**：
- 本体可用，主要是广告多。先在 WPS 设置里关推送与广告（各版本入口名称不同，以界面为准）、关云服务。
- 自动升级任务反复复活的三层修复、卸载后残留，见 `software-uninstall.md` 的 WPS 专项。

---

## 8. 媒体/其他类

| 软件 | 进程名 | 安装目录 | AppData 路径 | 行为 | 推荐 |
|------|--------|----------|--------------|------|------|
| **暴风影音**（残留） | `StormPlayer.exe` | `C:\Program Files (x86)\StormPlayer` | `%APPDATA%\Baofeng` | 已衰落 | ❌（残留） |
| **PPS / PPTV**（残留） | `PPStream.exe`, `PPTV.exe` | 各自目录 | `%APPDATA%\PPStream` | 服务已弱化 | ❌（残留） |
| **快压** | `KuaiZip.exe` | `C:\Program Files (x86)\快压` | `%APPDATA%\KuaiZip` | 弹窗、捆绑（详见 8b） | ❌ |
| **美图秀秀 PC 版** | `Meitu.exe`, `MeituViewer.exe` | `C:\Program Files (x86)\Meitu` | `%APPDATA%\Meitu` | 捆绑 | ❌ |

（百度网盘见第 2 类。）

---

## 8b. 补充家族（需实机确认）

> 以下全部来自安全厂商分析报告（时间跨度 2019–2026），厂商可能已改名或换签名。JSON 目录里置信度为 low，T25 只会提示"疑似"，不会建议自动处置。

| 家族 | 识别线索 | 持久化 / 行为 | 来源 |
|------|---------|--------------|------|
| **金山系 kbasesrv**（驱动精灵卸载时投放，与毒霸组件重叠） | 服务/进程 `kbasesrv.exe`；广告模块 `kwhcommonpop.exe`（云控**随机改名成安全软件文件名**）、`knbhm.exe`、`infocenter.exe`、`phoenix.exe` | 静默装服务；锁首页、推广；**主程序卸载后仍在** | [火绒 802](https://www.huorong.cn/document/tech/vir_report/802)、[803](https://www.huorong.cn/document/tech/vir_report/803) |
| **驱动人生系伪装组件** | `realtek.exe`（自称"Realtek 音频管理器"，带驱动人生签名）、`AERTSrv.exe`、插件目录 `DTLPlugs` | 静默推广安装、托盘广告 | [火绒 803](https://www.huorong.cn/document/tech/vir_report/803) |
| **鲁大师推广链（2025 报告）** | `computercenter.exe`、`guardhp.exe`、`master_ai_main.exe`，插件 `*.tpi` | 云控浏览器劫持、弹窗装软件、锁首页；会检测安全软件和虚拟机规避分析 | [火绒 1858](https://www.huorong.cn/document/tech/vir_report/1858) |
| **巧压** | `QiaoZipSvcHost.exe` | 卸载后服务项与右键扩展仍驻留，云控下载执行程序 | [火绒 811](https://huorong.cn/document/tech/vir_report/811) |
| **快压 + 上海展盟系** | 右键扩展 `KuaiZipShell.dll` 随资源管理器拉起 `UpdateChecker.exe`；推广弹窗 `KZTui.exe`；签名 SHANGHAI ZHANMENG NETWORK TECHNOLOGY CO.,LTD. | 用右键扩展作自启通道；捆绑"小黑记事本""ABC看图"等 | [火绒 1669](https://huorong.cn/document/tech/vir_report/1669) |
| **2345 下载器 → commander** | 安装到 `%APPDATA%\commander`，无快捷方式；`Services.exe` 注册为服务定时拉起 `commandtools.exe`；锁首程序 `DTPageSet.exe` | 服务 + 定时器、云控弹窗、改浏览器配置和快捷方式参数 | [火绒 1666](https://huorong.cn/document/tech/vir_report/1666) |
| **"拉法日历"** | 网络过滤驱动 `dll.sys`、推广模块 `ExpFc.dll` | 访问常见网站时弹广告、上传浏览网址 | [火绒 852](https://www.huorong.cn/document/tech/vir_report/852) |
| **Vaultify（以"主页保护"为名，2026-07 报告）** | 常驻 `vaultify_service.exe`；`regsvr32` 注册的 Shell 扩展 DLL | 直接改 Chrome/Edge 的 `Secure Preferences` / `Preferences` 篡改启动页 | [火绒 2013](https://www.huorong.cn/document/tech/vir_report/2013) |
| **激活工具类（"小马"等变种）** | 文件系统过滤驱动保护自身；WMI `ActiveScriptEventConsumer` 定时改快捷方式 | 驱动保护 + 无文件持久化；**强删驱动可能导致断网/无法启动** | [火绒 783](https://www.huorong.cn/document/tech/vir_report/783) |
| **仿冒官网安装包** | 搜索引擎竞价排在前面的仿冒下载站（钉钉、WPS、Chrome、火绒等均被仿冒）；安装包先装正版掩护 | 后门（银狐/Gh0st 类） | [火绒 1827](https://huorong.cn/document/tech/vir_report/1827) |
| **驱动级锁首页（总体规律）** | 来自修改版系统镜像、PE 工具、激活工具 | 首页"改回去又被改回来" | [火绒安全课堂 1715](https://www.huorong.cn/document/tech/safety-classroom/1715.html) |

> 遇到"首页改回又被改回、注册表策略删了又出现"，可能是驱动级或服务级劫持：不要反复改注册表，交给安全软件（火绒、Windows 安全中心离线扫描等）处理。

---

## 8c. 国际/OEM/商店预装

| 类别 | 例子 | 处理 | 推荐 |
|------|------|------|------|
| **杀毒软件试用版**（新机预装） | McAfee、Norton 试用 | 先在 设置 › 应用 里卸载；卸不干净时用厂商自己的清除工具（McAfee Consumer Product Removal、Norton Remove and Reinstall，下载地址以厂商官网为准，存疑：今日未核对链接）。卸载后确认 Windows 安全中心的防护已恢复 | ❌（不需要时） |
| **OEM 助手**（需实机确认） | Lenovo Vantage、HP Support Assistant、Dell SupportAssist、ASUS Armoury Crate / MyASUS、Acer Care Center、华为电脑管家 | 很多同时负责驱动、固件、BIOS 更新和电池/风扇设置，**默认保留**；只关其推送通知或推广内容；用户坚持卸载时说明后果 | ⚠️ |
| **商店预装/推广应用** | Candy Crush 等游戏、各类推广磁贴（随系统版本和地区变化） | 开始菜单右键 → 卸载，或 `Remove-WcoAppxPackage`（见 `software-uninstall.md`） | ❌（不需要时） |
| **系统推送** | 锁屏/开始菜单/设置里的推荐内容、Edge 首次运行推荐 | 见第 11 节"系统广告开关" | — |

> 不要卸载：Microsoft Store、应用安装程序（App Installer）、WebView2 运行时、VCLibs / UI.Xaml / .NET 等框架包、Windows 安全中心。`Remove-WcoAppxPackage` 会拒绝这些包。

---

## 9. 不卸载只静音：弹窗处理（含 IFEO 风险）

用户因工作需要**不能卸载** WPS、搜狗输入法、百度网盘等，但被弹窗骚扰。按下列顺序尝试，越靠前越安全：

1. **应用内关推送/广告**（WPS 设置、搜狗设置里的"资讯/热点"等）。
2. **关系统通知**：设置 › 系统 › 通知 → 找到该应用关闭（Win10：设置 › 系统 › 通知和操作）。
3. **禁用它的更新/推送计划任务、服务**（`Disable-WcoScheduledTask`、`Set-WcoServiceStartType`，可回退）。
4. **定位弹窗进程**：T20（`t20-locate-popup-window.ps1`）或 `software-uninstall.md` 的弹窗定位脚本——注意通知气泡和不抢焦点的弹窗不会成为前台窗口，抓不到时让用户在弹窗出现时手动点一下它。
5. **最后手段：IFEO 屏蔽单个弹窗程序（🟠 HIGH，用户明确同意后才做）。**

### IFEO 屏蔽的风险（先读再做）

原理：在 `Image File Execution Options\<程序名.exe>` 下写 `Debugger` 值，Windows 启动该程序时会改为启动 Debugger 指定的程序（把原程序路径作为参数）。指向一个会立刻退出的系统程序，弹窗程序就不会运行。

- **这本身就是一种劫持技术**（[MITRE ATT&CK T1546.012](https://attack.mitre.org/techniques/T1546/012/)）。Microsoft Defender 会把这类值检测为 **`Behavior:Win32/ifeoDebugger.DB`** 并自动清除（[PSAppDeployToolkit issue #1416](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/issues/1416)，2025-04）；公司电脑上的 EDR 会告警。写了之后可能被安全软件删掉或隔离。
- **按文件名全局生效**：系统里所有叫这个名字的 exe 都会被屏蔽，不论在哪个目录。只对专用的弹窗程序名使用，不要对 `updater.exe`、`setup.exe` 这类通用名使用。
- **Debugger 只填展开后的完整路径，如 `C:\Windows\System32\systray.exe`**（REG_SZ 值里的 `%SystemRoot%` 是否会被展开 存疑，所以写实际路径；先 `Test-Path "$env:SystemRoot\System32\systray.exe"` 确认存在；在当前 Win11 版本上是否仍存在 存疑）。不要用 `rundll32.exe`（会把 exe 路径当成 DLL 参数，很可能弹错误框）；不要填不存在的路径或空字符串（会报"找不到文件"）。
- 软件升级可能改掉弹窗程序名，屏蔽随之失效。
- 64 位系统上 32 位程序是否还要写 WOW6432Node 下的 IFEO：存疑，以实测为准。

| 目标软件 | 弹窗可执行文件（需实机确认） |
|---|---|
| **WPS Office** | `wpscenter.exe`、`ksobulletin.exe` |
| **搜狗输入法** | `SGDownload.exe`、`SogouNews.exe` |
| **Flash 中心** | `FFNewTask.exe`（Flash 中心建议直接卸载） |
| **2345 好压** | `HaoZipPopup.exe`（建议换 7-Zip） |

**操作（管理员 PowerShell；先演练，确认后加 `-Apply`）**：

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1
$ifeo = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
foreach ($exe in 'wpscenter.exe','ksobulletin.exe') {
    Set-WcoRegistryValue -Key "$ifeo\$exe" -Name Debugger -Value "$env:SystemRoot\System32\systray.exe" -Type String -Kind ifeo -Risk HIGH
}
# 确认后同样的命令加 -Apply，然后 Export-WcoUndo
```

**回退：只删 `Debugger` 这一个值，不要删整个 IFEO 子键**（子键里可能原本就有 `MitigationOptions` 等系统值）：

```cmd
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wpscenter.exe" /v Debugger /f
```

用模块执行时，`undo.ps1` 会按原状态恢复（原来没有该值就只删该值，原来子键不存在就删掉本次新建的子键）。

---

## 10. 快捷方式（.lnk / .url）参数劫持

推广软件常在桌面/开始菜单/任务栏的浏览器快捷方式后面加推广网址（如 `chrome.exe http://www.2345.com/?...`），或在桌面放 `.url` 广告图标（"淘宝""游戏大全"之类）。

**只读排查**：T19（`t19-audit-wmi-lnk-hijack.ps1`）。手动快查：

```powershell
$shell = New-Object -ComObject WScript.Shell
$dirs = @("$env:USERPROFILE\Desktop", "$env:PUBLIC\Desktop",
          "$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
          "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar")
foreach ($dir in $dirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Filter '*.lnk' -Recurse -EA SilentlyContinue | ForEach-Object {
        $lnk = $shell.CreateShortcut($_.FullName)
        if ($lnk.TargetPath -match 'chrome\.exe|msedge\.exe|firefox\.exe|360se\.exe|cmd\.exe' -and $lnk.Arguments -match 'http|www\.|\.com|\.cn|\.html') {
            "[待核实] $($_.FullName) -> $($lnk.TargetPath) $($lnk.Arguments)"
        }
    }
    Get-ChildItem -LiteralPath $dir -Filter '*.url' -EA SilentlyContinue | ForEach-Object { "[网址图标] $($_.FullName)" }
}
```

> 带 `--app=` 或网址参数的快捷方式也可能是用户自己建的网页应用（PWA），先问用户。

**修复**（用户确认后）：先把原 `.lnk` 复制到会话目录备份，再清空参数：`$lnk.Arguments = ''; $lnk.Save()`。更省事的做法：删掉这个快捷方式（走回收站，`t07-safe-recycle.ps1`），从开始菜单重新固定浏览器。修好后又被改回 → 有程序在后台改，回到 T24/T25 找来源。

---

## 11. 其他广告与劫持载体

| 载体 | 怎么查（只读） | 怎么处理 |
|------|--------------|---------|
| **浏览器策略劫持**（主页、启动页、新标签页、默认搜索、强制安装扩展） | T23：读 `HKLM` 和 `HKCU` 下的 `SOFTWARE\Policies\Google\Chrome`、`...\Microsoft\Edge`、`...\Mozilla\Firefox`，重点值 `HomepageLocation`、`RestoreOnStartup*`、`NewTabPageLocation`、`DefaultSearchProvider*`、`ExtensionInstallForcelist`、`ExtensionSettings`；浏览器地址栏打开 `edge://policy` / `chrome://policy` 也能看到 | 先确认不是单位/学校下发的（公司电脑不要动）。只删被写入的那几个值（见 `software-uninstall.md`"浏览器劫持修复"），**不要删整个策略键**；删了又回来 → 找写入它的程序 |
| **Native Messaging 宿主** | T23：`HKCU/HKLM\Software\Google\Chrome\NativeMessagingHosts\*`（Edge、Firefox 同类） | 扩展可借此拉起本地程序；卸载对应扩展和软件 |
| **浏览器配置文件被直接改**（`Secure Preferences` / `Preferences`） | T23 只提示，不解析 | 浏览器 设置 › 重置设置；必要时新建配置文件 |
| **通知轰炸** | 设置 › 系统 › 通知，看列表里哪些应用开着通知；浏览器网站通知：`edge://settings/content/notifications`、`chrome://settings/content/notifications` | 逐个关闭该应用/网站的通知（Win10：设置 › 系统 › 通知和操作）。注册表路径未核实，不用脚本改 |
| **锁屏 / 开始菜单 / 设置里的推荐内容** | — | **用设置开关**（名称随版本略有不同，以界面为准）：设置 › 个性化 › 锁屏界面 →"个性化锁屏界面"改选"图片"或"幻灯片"，并关闭"在锁屏界面上获取花絮、提示、技巧等"；设置 › 个性化 › 开始 → 关闭提示/推荐/新应用相关开关；设置 › 隐私和安全性 › 常规 → 关闭"在设置应用中向我显示建议的内容"；设置 › 系统 › 通知 → 其他设置 → 取消"使用 Windows 时获取提示和建议"等 |
| **Windows 聚焦（Spotlight）策略** | — | 策略 `DisableWindowsSpotlightFeatures`（"关闭所有 Windows 聚焦功能"）**只对企业版/教育版生效，家庭版和专业版无效**（[Policy CSP – Experience](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-experience)，2026-11-11 核对）；家庭/专业版用上一行的锁屏设置 |
| **hosts / 代理 / PAC / DNS** | T23：hosts 非注释行；`HKCU`/`HKLM` 的 `Internet Settings` 下 `ProxyServer`、`AutoConfigURL`；`netsh winhttp show proxy`；各网卡 DNS 服务器 | 列给用户核对来源（加速器、抓包工具、公司 VPN 都会改这些）。代理：设置 › 网络和 Internet › 代理；DNS：网卡设置改回自动。**本技能不推荐用 hosts 批量屏蔽域名**——hosts 是要审计的对象 |
| **根证书** | T23：`Cert:\LocalMachine\Root`、`Cert:\CurrentUser\Root` 中最近 180 天新增的证书（颁发者 + 生效日期） | 抓包工具、公司代理、部分安全软件会装根证书。来源不明的：先导出备份（`certmgr.msc` → 导出），用户同意后再删除；拿不准交给安全软件 |
| **文件关联被抢**（http/https、.pdf、.jpg/.png、.zip/.rar/.7z） | T23/T25 只读列出当前默认程序 | 只用 设置 › 应用 › 默认应用 改回。**不要写 `UserChoice`**（受系统哈希保护，强写会被重置） |
| **右键菜单 / 图标覆盖**（网盘、压缩软件） | T16 | 软件自带"右键菜单集成"开关，或卸载 |
| **Winsock LSP** | T24：`netsh winsock show catalog` 中的非微软项 | 🟠 HIGH：用户同意后 `netsh winsock reset` + 重启 |
| **卸载器套路** | — | 见 `software-uninstall.md`"识别卸载器套路"：默认勾"修复/保留"、挽留弹窗、卸载完弹广告页或顺手装别的、`UninstallString` 指向网页或"修复"程序 |
| **"卸了又回来"** | T25 前后对比 | 来源可能是同捆软件、厂商助手、Windows 更新推送的设备配套应用、WPBT（存疑）；找到并处理来源，而不是反复卸载 |

---

## 替代软件推荐

| 原 bloatware | 推荐替代 | 优势 |
|--------------|----------|------|
| 360 安全卫士 / 金山毒霸 | **Windows 安全中心（Defender）** / 火绒安全 | 无广告无捆绑 |
| 2345 好压 / 快压 / 巧压 | **7-Zip** | 开源、无广告 |
| 360 浏览器 / 2345 浏览器 | **Edge / Chrome / Firefox**（从官网下载） | 干净、无劫持 |
| 福昕阅读器 / XX PDF | **SumatraPDF** / 浏览器自带 PDF 查看 | 轻量、无广告 |
| 鲁大师 | **CPU-Z / HWMonitor** | 干净、无弹窗 |
| 驱动精灵 / 驱动人生 | Windows 更新 + 电脑厂商官网驱动 | 系统集成 |
| 桌面整理（360/金山版） | **腾讯 DeskGo** | 无广告（用户主动选择） |
| WPS（可选保留） | WPS 关闭广告 / LibreOffice | 取决于需求 |
| 暴风影音 | **PotPlayer / VLC** | 干净、无广告 |
| 搜狗输入法 | **微软拼音**（Windows 自带） | 系统集成、无弹窗 |
| XX 看图 | Windows 自带"照片" | 系统集成 |

> 下载软件只从官网或 winget 获取，避开搜索结果里的竞价下载站（仿冒官网见 8b）。

---

## 下一步

发现 bloatware 后：
1. 用户同意卸载 → `software-uninstall.md` 的"完整卸载流程"
2. 用户不想卸载、只想关自启 → `startup-audit.md`
3. 用户只想去掉弹窗 → 本文第 9 节，按顺序从最安全的做起
4. 用户保留（如 DeskGo、Steam）→ 不动，仅记录
