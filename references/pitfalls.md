# 常见陷阱与实战教训

<!-- skill-doctor: allow-block SEC002（实战路径示例用 <用户名> / %USERPROFILE% 占位，无真实用户路径） -->

执行清理/迁移过程中容易踩的坑（2026 实战沉淀）。按需查阅，主文件 SKILL.md 只在流程关键点引用本节条目。

## 目录

- 执行方式陷阱（1-3, 21, 27）
- 判断误判陷阱（4, 10, 14, 17-20, 23-25）
- 空间/性能陷阱（5-6, 12-13, 28-29）
- 安全边界陷阱（7-8, 22, 26）
- 迁移专项陷阱（11, 15-16）

## 执行方式陷阱

1. **PowerShell 变量 `$` 符号被 bash 吃掉。** 不要通过 `-Command` 传含 `$` 的脚本。正确做法：先 `Write` 一个 `.ps1` 文件，再用 `powershell -ExecutionPolicy Bypass -File "path.ps1"` 执行。

2. **SendToRecycleBin 不释放空间。** 这是最容易引起困惑的点。文件进了回收站还在 C 盘上，必须清空回收站才释放。务必在阶段 5 明确告知用户。

3. **Temp 目录大量文件被锁。** 这是正常行为（运行中的程序占用），不是错误。跳过即可，不需要反复重试。

21. **PowerShell 函数内 `$report +=` 会静默丢失（白扫一轮）。** 函数内普通赋值创建的是局部变量，不会写回脚本级变量。全盘扫描几十行结果全空、但没报任何错误——八成是这个原因。修复：函数内一律 `$script:report +=`，或让函数返回数组由调用方捕获。这是 2026-08 实战中实际踩过的坑。

27. **清空回收站命令不要用 bash 内联传 `$` 变量。** `powershell -Command "...$c..."` 会被 bash 展开变量导致解析错误（报 `op_Division` 之类）。同陷阱 1：一律 .ps1 文件执行。实战中 `Clear-RecycleBin` 曾因此差点执行结果无法确认。

## 判断误判陷阱

4. **AppData\Roaming 里残留已卸载软件的数据。** Windows 卸载程序通常不删 Roaming 下的配置目录。通过检查对应 exe 是否仍存在于 `Program Files` 或 PATH 中来判断是否为残留。

10. **Roaming 交叉比对的模糊匹配有局限。** 注册表里的 `DisplayName` 和 Roaming 目录名不一定一一对应（例如 VMware 在 Roaming 里的目录名就是 `VMware`，但注册表可能显示 `VMware Workstation Pro`）。交叉比对结果是辅助判断，不是最终结论——呈现给用户时标注"疑似残留"而非"确认残留"，让用户做最终决定。

14. **TRAE 改名导致 Roaming 交叉比对误判。** TRAE Solo 在 2026-06-09 改名为 TRAE Work，但 `%APPDATA%\TRAE SOLO CN` 目录名未变、注册表 `DisplayName` 已变为 `TRAE Work CN (User)`。交叉比对的模糊匹配无法将 `TRAE Work CN` 与 `TRAE SOLO CN` 关联，会把正在使用的 TRAE 误标为"RESIDUAL（已卸载残留）"。遇到类似情况（软件改名但目录名未同步更新），应优先检查进程列表中是否存在对应进程，而非仅依赖注册表匹配。

17. **非系统盘根目录的哈希命名隐藏目录通常是视频流缓存。** 如 `D:\50c1669063de13bda9d5cbeab7da607b`（32 位十六进制字符串），内含 `.hls`/`.ts`/`.m3u8` 文件。这类目录来自某些视频播放器或浏览器的离线缓存，可以安全清理。识别方法：隐藏属性 + 哈希命名 + 内含流媒体分片文件。

18. **"- AppData" 后缀目录是软件搬家的旧备份。** 腾讯电脑管家等工具的"软件搬家"功能会把 AppData 目录迁移到 D 盘，有时在目标位置留下 `原目录名 - AppData` 的备份副本（如 `<自定义安装根>/TRAE SOLO CN - AppData`）。如果当前软件运行正常且 AppData 已指向新位置，这些备份可以安全清理。

19. **非系统盘上版本号命名的 IDE 目录大概率是旧版残留。** 如 `D:\IntelliJ IDEA Community Edition 2022.1.3`（2022 年版，LastWrite 2024-10）。用户通常已升级到新版，旧版安装目录（含 plugins/lib/jbr 等）就是纯占用。判断方法：目录名含版本号 + LastWriteTime 超过 6 个月 + 注册表中无对应安装记录。

20. **非系统盘 Users 目录不能只看顶层 LastWriteTime 就判定为孤儿。** 软件搬家（如腾讯电脑管家）会把 C 盘 `AppData\Local\Programs\*` 迁移到 `D:\Users\<用户名>\AppData\Local\Programs\*`，顶层目录 LastWrite 可能很旧（迁移时间），但内部子目录（如 VS Code）仍在活跃写入。**必须逐层展开检查内部每个软件的 LastWriteTime，并确认 C 盘是否有 junction 指向此路径。** 实战教训：`D:\Users\<用户名>` 顶层 LastWrite 2025-12，差点被判定为孤儿，实际内部的 VS Code LastWrite 2026-07-22，是正在使用的搬家目标。

23. **软件搬家备份不止 `- AppData` 后缀一种命名。** 腾讯电脑管家"软件搬家"还会生成 `软件名_腾讯电脑管家搬家目录_哈希`（如 `douyin_腾讯电脑管家搬家目录_852562`）。识别：目录名含"搬家"字样，且对应软件已卸载（注册表无记录）→ 旧备份，可清。若对应软件还在用，先核对 C 盘是否有 junction 指向它。

24. **哈希视频缓存目录删除前先看 LastWriteTime。** 如果 LastWriteTime 在最近几天内，说明有播放器/浏览器正在写它——此时删除会失败（文件被占用），且清理后播放中的内容会中断。做法：先告知用户"该缓存正在使用，删除后会自动重建"，被占用导致失败时重试即可，不要反复死磕。

25. **D 盘可能出现无法显示的乱码目录名**（如 `�����ļ�`，GBK 字节被当 Unicode 显示）。这是正常现象（老工具创建的目录），不是文件损坏。用 `[System.IO.Directory]::GetDirectories('D:\')` 可读真实名；**不要凭乱码名猜测内容，先看内部再定档**（实战：乱码目录内部是 `Tencent Files`，实为 QQ 聊天文件数据，第四档）。

## 空间/性能陷阱

5. **Python 全局环境膨胀。** `site-packages` 可能累积到几 GB。建议用户迁移到 `uv venv` 虚拟环境工作流，而非反复清理全局包。

6. **扫描大目录耗时。** `Get-ChildItem -Recurse` 扫描几 GB 的目录可能需要 1-3 分钟。给 Bash 命令设置足够的 `timeout`（建议 300000ms 以上），并使用 `-ErrorAction SilentlyContinue` 避免权限错误中断。

12. **推荐 WizTree / TreeSize Free 作为辅助诊断工具。** PowerShell 的 `Get-ChildItem -Recurse` 扫描几 GB 目录需要数分钟，而 WizTree 利用 NTFS MFT（Master File Table）可以秒级出全盘热力图。当用户对扫描结果有疑问或想更直观地看空间分布时，建议他们安装 WizTree（免费、免安装版可用）做可视化验证。

13. **WSL2 虚拟磁盘文件会无限增长。** `%LOCALAPPDATA%\Packages\*Ubuntu*\LocalState\ext4.vhdx` 只增不减，即使你在 WSL 里删了文件，vhdx 也不会自动缩小。需要用 `diskpart` 的 `compact vdisk` 命令手动压缩。如果用户有 WSL2 环境，这个路径值得单独检查。

28. **DriverStore 驱动存储库是最大盲区之一。** `C:\Windows\System32\DriverStore\FileRepository` 累积所有旧版驱动（实测 11 GB、20+ 个 NVIDIA 版本）。**绝不手动删文件**，清理用 `pnputil /enum-drivers` + `pnputil -d oemXXX.inf`（详见 system-cleanup.md）。扫描阶段只测大小，若 >2 GB 提示用户。

29. **清理前建议建系统还原点。** 涉及驱动/系统组件的操作（pnputil、DISM）前，执行 `Checkpoint-Computer -Description "BeforeDriversDelete"`（需管理员），用户数据类清理不需要。

---

## 优化主题踩坑（30+）

30. **"内存清理工具"几乎都是 placebo。** 360 内存清理、CCleaner、Mem Reduct、Razer Cortex 等都调用 `EmptyWorkingSet`，只是把内存页从 Working Set 移到 Standby 列表——物理 RAM 占用**不变**。详见 `memory-optimization.md`。**不要推荐用户安装任何这类工具**。

31. **不要禁用 SysMain（Superfetch）除非你确定机器配置。** 现代机器（SSD + 8 GB+ 内存）SysMain 加速应用冷启动，禁用反而变慢。判断方法：`Get-PhysicalDisk | Select MediaType`（SSD = 4，HDD = 3）。详见 `services-optimization.md` SysMain 节。

32. **不要禁用 Windows Defender 来"优化性能"。** Defender 在 Win10/11 已经非常轻量（CPU < 2%），禁用后安全风险巨大。**正确做法**：用排除列表（Add-MpPreference）跳过 IDE 缓存等。详见 `performance-tuning.md`。

33. **不要禁用 Windows Update 来"提速"。** 收益几乎为零，安全风险巨大。正确做法：设置"工作时间不更新"，或保持默认自动更新。

34. **页面文件不要设为 0。** 即使物理内存很大，Windows 需要页面文件生成崩溃转储（蓝屏诊断）。**最小值**：1 GB（仅给崩溃转储用）。完全禁用会导致崩溃转储失败。

35. **服务禁用需要管理员权限。** `Disable-ScheduledTask`（计划任务）和 `sc.exe config ... start= disabled`（服务）经常因权限不足失败——错误信息为 "Access is denied"。**解决方案**：用 `Start-Process powershell -Verb RunAs` 提权，会弹 UAC。

36. **提权后的 `Stop-Service` 对部分受保护服务无效。** 例如 `DiagTrack`、`RemoteRegistry` 等被系统保护的服务，停止时可能需要 5-10 秒等待，或在 `Stop-Service` 后加 `Start-Sleep -Seconds 5`。

37. **bloatware 卸载前先看进程列表。** 360 安全卫士等带自我保护的标准卸载会失败——必须先终止进程（`Stop-Process -Force`），再走标准卸载。详见 `software-uninstall.md`。

38. **360 内核驱动普通方法删不掉。** `360AvFlt`、`360Box`、`360FsFlt`、`360SelfProtection` 是内核级驱动，需要专用工具（如 GitHub `ROWENxAI/force-uninstall-360`）或进安全模式手动处理。**不要用普通 `Remove-Item` 操作这些驱动文件**——可能导致系统无法启动。

39. **钉钉的"钉钉保镖"是内核服务，标准卸载后仍残留。** 路径 `C:\Program Files (x86)\AlibabaProtect`，需提权删除。

40. **WPS 卸载后 Kingsoft 目录残留巨大。** 典型残留：`addons/pool/win-i386/`（旧版插件）和 `%APPDATA%\kingsoft`（配置）。WPS 还会在 `%LOCALAPPDATA%\Kingsoft` 留云服务缓存。详见 `software-uninstall.md` WPS 专项。

41. **腾讯桌面整理 (DeskGo) 自启**。**保留**——这是腾讯少有的"无广告无捆绑"工具，但默认会自启（占 350 MB 内存）。如果觉得太占内存，可在 HKCU Run 中禁用，但保留软件本体。

42. **Windows Search 索引范围影响性能。** 索引 `D:\code` 等大型代码库会大量消耗磁盘 I/O。建议：索引用户库 + 开始菜单，**不索引**大型项目目录。用 Everything（第三方）替代更快。

43. **修改注册表前必须导出备份。** 优化涉及 `HKLM` 或 `HKCU\Software\` 的修改前，必须 `reg export` 备份整个注册表项（不是单个值），便于回退。

44. **Defender 排除路径不要加太多。** 排除 = 不扫描 = 不保护。**只加**确认安全的路径：IDE 缓存、构建输出、虚拟磁盘镜像。**不要加**整个 `C:\` 或 `D:\`——失去 Defender 防护。

45. **电源计划"卓越性能"对笔记本电池有负面影响。** 该计划禁用 USB 选择性挂起等节能功能，**电池续航降低 10-20%**。笔记本用户推荐：插电时切"高性能"，电池时保留"平衡"。

46. **视觉效果"调整为最佳性能"会禁用 ClearType。** 视觉效果全关后字体发虚，**必须手动勾回"平滑屏幕字体边缘"**（这是 UI 可读性的最低要求）。

47. **NTFS Last Access Time 在 Win10 1803+ 已默认禁用。** 不需要手动设置。早期版本可 `fsutil behavior set disablelastaccess 1`。

48. **Nagle 算法禁用只对在线竞技游戏有意义。** 普通办公 / 网页用户禁用没收益，反而增加网络流量。**只对**游戏玩家推荐。

49. **DoH (DNS over HTTPS) 配置后可能访问变慢。** DoH 服务器响应延迟可能比 ISP DNS 高。**先测速**：访问一些国际网站是否变慢；如果变慢，切回 ISP DNS。

50. **Defender 排除进程时必须用完整进程名。** `Add-MpPreference -ExclusionProcess "Code.exe"` 才对，不是 `Code` 或 `code`。VS Code 是 `Code.exe`，不是 `VSCode.exe`。

51. **服务禁用后某些计划任务会自动启用服务。** 例如 `WaaSMedicSvc` 服务可能被某些 Windows Update 计划任务重新启用。**禁用计划任务**和**禁用服务**需要同时进行。

52. **HKCU 注册表修改不需要管理员权限，但 HKLM 需要。** 写脚本时先检测权限（`$isAdmin`），非管理员时只改 HKCU 项；HKLM 项放提权脚本里。

53. **修改电源计划需要管理员。** `powercfg /setactive` 在普通权限下报"Access is denied"。需要 `Start-Process -Verb RunAs`。

54. **服务禁用后系统某些功能可能延迟几小时才察觉。** 例如关 WSearch 后，Outlook 搜索结果可能要重启后才明显改变。**不要立刻回退**——等 24 小时确认是配置问题还是真问题。

55. **"内存 80% 就紧张"的判断是错的。** Windows 内存管理 Standby 缓存，80% 是**正常**。只有 Available < 500 MB 才是真压力。详见 `memory-optimization.md`。

56. **TRIM 对 SSD 的重要性被高估了。** 现代 SSD 都有 GC（垃圾回收），TRIM 是"提示"而不是"必须"。**但开启 TRIM 仍然是好习惯**（默认开）——不会造成伤害。

57. **Defender 排除路径用绝对路径，不要用通配符。** `Add-MpPreference -ExclusionPath "D:\code\projects\*\node_modules"` 这种通配符**不生效**。需要具体路径或父目录。

58. **腾讯会议 / 微信 PC 用 mklink 迁移会损坏数据。** 这两个软件使用硬编码路径，不支持 junction 迁移。详见 `mklink-migration.md` 不兼容列表。

---

## 2026-08 实战新增（踩坑 59-66）

59. **非标准安装路径会漏检。** 2026-08 实战：WPS Office 装在 `<自定义安装根>/WPS Office/<版本号>/office6/`（用户从第三方渠道装的），而非标准的 `C:\Program Files (x86)\Kingsoft\WPS Office`。诊断脚本里所有"已知路径"硬编码都不命中，导致搜索不到更新器、检查不到 ksolaunch 等关键文件。**对策**：永远不要硬编码安装路径。改用两步法：
    ```powershell
    # 1. 从 Uninstall 注册表查 DisplayName 反查 InstallLocation
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
        Where-Object { $_.DisplayName -match 'WPS|Kingsoft' } | ForEach-Object {
            Write-Host "$($_.InstallLocation) -> $($_.DisplayName)"
        }
    # 2. 然后在 InstallLocation 下找具体 exe（如 wps.exe、ksolaunch.exe）
    ```
    同时额外扫：`C:\Program Files\*`、`C:\Program Files (x86)\*`、`D:\Program Files\*`、`<自定义安装根>/*`（用户自定义安装区）、`%LOCALAPPDATA%\Programs\*`、`%LOCALAPPDATA%\Kingsoft\*` 等候选根。

60. **`HKCR\*` 通配符枚举极慢甚至卡死。** 2026-08 实战：`Get-ChildItem 'Registry::HKEY_CLASSES_ROOT\*\...'` 会枚举整个 HKCR 树（几十万个 ProgID 和文件扩展名），10 分钟都跑不完且无输出。**对策**：改用 `HKLM:\Software\Classes\<具体路径>`（HKCR 是 HKLM\Software\Classes + HKCU\Software\Classes 的合并视图，但 HKLM 这一半枚举速度快很多）。文件右键菜单常用的几个具体路径：`HKLM:\Software\Classes\*\shell`、`HKLM:\Software\Classes\Directory\shellex\ContextMenuHandlers`、`HKLM:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers`、`HKLM:\Software\Classes\Drive\shellex\ContextMenuHandlers`、`HKLM:\Software\Classes\SystemFileAssociations\<.exe|.txt|.lnk>\shell`。

61. **WPS 自动升级任务反复复活的根因与三层修复。** 2026-08 实战：WPS 始终在用户电脑安装，无论怎么手动禁用 `WpsUpdateTask_<用户名>` 和 `WpsUpdateLogonTask_<用户名>`，下次开 WPS 这两个任务又自动被 `ksolaunch.exe /wpsupdate` 重新写回。用户反复禁用 = WPS 反复复活。**根因**：WPS 启动器 `ksolaunch.exe` 在 WPS 主程序运行时检查并重注册任务。**三层防护**：
    1. **配置层（治本）**：把注册表 `HKCU:\Software\Kingsoft\Office\6.0\Common\updateinfo\UpdateMode` 从 `auto` 改为 `manual`（字符串类型）。这一项让 ksolaunch **不再去**注册任务，从源头解决。
    2. **任务层（兜底）**：禁用三个 WPS 任务：`WpsUpdateTask_<用户名>`、`WpsUpdateLogonTask_<用户名>`、`WpsWakeWnsLogonTask`（消息推送中心，也会被 WPS 自动重写）。
    3. **服务层（兜底）**：禁用 `wpscloudsvr` 服务（云服务也能重写任务）。
    
    **陷阱**：① 用户找不到 in-app "自动升级" 开关时（某些版本藏得深），直接改 UpdateMode 是治本的最快路径。② 修改前必须 `reg export` 备份整个 `updateinfo` 子键（不要只备份 UpdateMode 单值），便于回退。③ 还要把 `LastUpdateMode` 同步改为 `manual`，否则 WPS 可能在下次启动时根据 LastUpdateMode 把 UpdateMode 改回 `auto`。详细模板见 `software-uninstall.md` WPS 专项（已更新）。

62. **计划任务根目录修改需要管理员，子目录某些可非管理员改。** 2026-08 实战：`schtasks /change /tn "\WpsUpdateTask_20919" /disable` 报 `Access is denied`（即使任务 owner 是当前用户），但同一个用户 token 下 `\GoogleUserPEH\RunPlatformExperienceHelperOnUnlock` 禁用却成功。规律：注册在 `\` 根目录下的任务（特别是厂商专属更新的）会被任务调度器安全策略拦截；`\<子文件夹>\` 下的任务大多可改。**对策**：遇到根目录任务禁用失败，统一放到管理员提权脚本里执行（见 `mklink-migration.md` 提权方案）。

63. **`schtasks /change` 失败的隐藏错误。** 2026-08 实战：`schtasks /change /tn ... /disable` 返回的 stderr 在 powershell 里是空的（看起来像成功但 `$LASTEXITCODE != 0`），实际是 `Access is denied`。**对策**：用 `Start-Process -FilePath schtasks.exe -ArgumentList ... -Wait -PassThru -RedirectStandardError ... -RedirectStandardOutput ...` 才能抓住真错误。PowerShell 原生调用 `schtasks` 时 stderr 被吞噬。

64. **诊断/执行脚本不要放在用户根目录。** 2026-08 实战：清点下来用户在 `C:\Users\<用户名>\` 下看到一堆 `diag.ps1`、`exec_cleanup.ps1`、`wps_investigate.ps1` 等临时脚本大发雷霆——这是噪声不是功能。**对策**：所有诊断/执行/临时 .ps1 一律写到 `$env:TEMP` 或 `C:\Windows\Temp`，不用 `Write` 到用户目录。真的需要可点击的"用户运行入口"（如管理员提权 .bat）才放用户目录，但跑完立即让用户删掉并在脚本里自动 `Remove-Item` 自己。

65. **electron-updater 残留目录扫描模板。** 2026-08 实战：在 `%LOCALAPPDATA%` 下扫到 `@opencode-aidesktop-updater`(241MB)、`qwen-work-cn-updater`(226.8MB) 两个残留。这些是早期版本的 electron 应用留下的更新缓存，软件本体可能已升级或卸载，但更新器缓存没人清。**扫描模式**：在 `LocalAppData`、`AppData`、各软件安装目录下找名字匹配 `*updater*`、`*update*`、`pending`、`*Update*` 的目录，结合 Uninstall 注册表交叉比对（已卸载软件的就清，没卸载看大小决定）。完整模板见 `scan-scripts.md` 模板 5。

66. **服务禁用需要管理员，非管理员错误一律是 "OpenService FAILED 5: Access is denied"。** 2026-08 实战：`sc config <service> start= disabled` 在非管理员 token 下报这个错。`schtasks /change` 失败报 `Access is denied`。两者都通过 `%LOCALAPPDATA%\Temp\<script>.log` 抓日志后一目了然。**对策**：所有需要改 `HKLM`、服务、计划任务根目录的脚本，组装到独立的 `*_admin.ps1`，让用户双击 `*_admin.bat` 调 `powershell -Verb RunAs` 触发 UAC。把非管理员部分（HKCU 写、Temp 删除、用户目录扫描）放在普通脚本里并行跑。

67. **PowerShell `Invoke-RestMethod` 往 GitHub API POST/PATCH 中文 body 会变乱码（`???`）。** 2026-08 实战：用 `Invoke-RestMethod -Body ($obj|ConvertTo-Json)` 创建含中文的 GitHub Release 后，名字和说明全变成 `?`。**根因**：PowerShell 5.1 的 HttpWebRequest 默认 ContentType 编码不是 UTF-8，中文被压成 `?` 存进 GitHub——之后怎么读都是 `?`，只能手动重建。**对策（必用）**：
    - **幂等好法**：写临时 UTF-8 JSON 文件 + `curl.exe`：
      ```powershell
      $utf8 = New-Object System.Text.UTF8Encoding($false)
      [System.IO.File]::WriteAllText("C:\Temp\payload.json", $json, $utf8)
      & curl.exe -sS -X PATCH "$uri" -H "Authorization: Bearer $token" `
          -H "Content-Type: application/json; charset=utf-8" --data-binary "@C:\Temp\payload.json"
      ```
    - 若必须用 `Invoke-RestMethod`：先 `$payload = $obj|ConvertTo-Json`（会输出 `\uXXXX` 转义的纯 ASCII），再 `Invoke-RestMethod -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8"`。**绝不要**直接传字符串 body 且不带 charset。
    - 验证：GET 回来后 `if($obj.body -match '\?\?\?') { '有乱码' }`。
    - 延伸（pitfalls 备用）：GitHub token 应只从环境变量读取（`[Environment]::GetEnvironmentVariable('GITHUB_TOKEN','User')`），不要写进任何脚本文件——脚本文件里出现可用的凭据字面量属于高危。凭据用后按用户意图决定是否保留环境变量。

## 安全边界陷阱

7. **Edge / Chrome 缓存不要直接删文件夹。** 建议用户从浏览器设置里清除浏览数据，直接删文件夹可能导致浏览器异常。

8. **微信/QQ/腾讯视频的缓存建议在应用内清理。** 这些应用的缓存格式私有，直接删文件夹可能导致聊天记录损坏。

22. **`C:\Program Files` 下删除失败的报错有误导性。** 非管理员下 SendToRecycleBin 会报 `"This function is not supported on this system"`（看起来像功能不支持，实际是权限不足）。识别方法：确认 `isAdmin` 为 False + 目标在 Program Files 下。处理见主文件 4.4 提权方案。

26. **提权进程（RunAs）写日志用绝对路径。** `Start-Process -Verb RunAs` 启动的管理员进程环境变量可能与当前会话不同，`$env:TEMP` 可能解析到别的目录导致报告"丢失"。统一写 `C:\Users\<user>\AppData\Local\Temp\<固定名>.txt` 绝对路径。

## 迁移专项陷阱

9. **量太小不值得折腾时果断跳过。** 实战中遇到 OpenRGB 残留目录仅 4 MB，但 logs 子目录有 2485 个文件全被系统锁定。强行逐个处理耗时远超收益。正确做法：记录跳过原因，告诉用户"重启后可处理"，不要在微小目录上浪费大量时间。一般阈值：目录 < 10 MB 且遇到锁定错误时，直接跳过。

11. **安装到 D 盘不代表 AppData 搬走了。** 绝大多数软件（TRAE、VS Code、Kimi、Claude Desktop、各类 IDE、AI 客户端等）即使本体装到 D 盘，用户数据和缓存仍然默认写入 `C:\Users\<用户名>\AppData`。用户以为装到 D 盘就没事了，实际上 C 盘还在被持续占用。**这是 Windows 的普遍现象，不是单个软件的 bug**。需要配合符号链接迁移（见 `references/mklink-migration.md`）才能真正把数据搬到 D 盘。

15. **mklink 迁移时复制工具的两大隐形坑（迁移必读，通用）。** （一）**稀疏文件膨胀**：robocopy 默认把稀疏文件（sparse file，逻辑大小远小于分配大小）展开到完整大小——常见于虚拟磁盘镜像类文件（如 TRAE `VMCache`、WSL2 `ext4.vhdx`、Docker VHD 等），复制后目标体积膨胀 2-3 倍。识别方法：`fsutil sparse queryflag <文件>`。**对策**：对含稀疏文件的子目录单独用 xcopy 或 `Copy-Item -Recurse`。（二）**junction 跟踪**：robocopy 默认跟随源目录内的 junction point，把 junction 指向的目标内容也复制一份，导致文件数暴增数倍。**对策**：加 `/XJ` 排除 junction。xcopy 没有这两个问题，但有 260 字符路径长度限制，深层 `node_modules` 会报"路径找不到"并跳过。实战最稳方案：**xcopy 复制主体 + robocopy `/XJ /E` 补充长路径子目录**，最后用文件数+大小双重验证。另外，bash/cmd 下直接调 robocopy 时 `/E`、`/MIR` 等参数会被 shell 当路径解析，必须写成 `.ps1` 脚本通过 `powershell -File` 执行。详见 `references/mklink-migration.md` 通用指南与 `references/case-study.md` Case A 实战。

16. **非系统盘扫描策略与 C 盘完全不同。** C 盘有固定的 AppData 分层结构，可以逐层深入扫描。D 盘等非系统盘的目录结构完全由用户习惯决定，没有统一模式。正确做法是**根目录一级展开**，按大小排序后逐个识别，而不是套用 C 盘的 AppData 扫描逻辑。对 D 盘做 `Get-ChildItem -Recurse` 全盘扫描会非常慢（几十 GB 到上百 GB），应该只扫描根目录一级，然后对可疑大目录再深入一层。
