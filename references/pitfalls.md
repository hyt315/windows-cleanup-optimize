# 常见陷阱与实战教训

<!-- skill-doctor: allow-block SEC002（实战路径示例用 <用户名> / %USERPROFILE% 占位，无真实用户路径） -->

执行清理/迁移过程中容易踩的坑（2026 实战沉淀）。按需查阅，主文件 SKILL.md 只在流程关键点引用本节条目。

## 目录

- 执行方式陷阱（1-3, 21, 27）
- 判断误判陷阱（4, 10, 14, 17-20, 23-25）
- 空间/性能陷阱（5-6, 12-13, 28-29）
- 安全边界陷阱（7-8, 22, 26）
- 迁移专项陷阱（11, 15-16）
- 2026-09 自启动+迁移彻底化（68-78）

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

28. **DriverStore 驱动存储库是最大盲区之一。** `C:\Windows\System32\DriverStore\FileRepository` 累积所有旧版驱动（实测 11 GB、20+ 个 NVIDIA 版本）。**绝不手动删文件**，清理用 `pnputil /enum-drivers` + `pnputil /delete-driver oemXXX.inf /uninstall`（详见 system-cleanup.md）。扫描阶段只测大小，若 >2 GB 提示用户。

29. **清理前建议建系统还原点。** 涉及驱动/系统组件的操作（pnputil、DISM）前，执行 `Checkpoint-Computer -Description "BeforeDriversDelete"`（需管理员），用户数据类清理不需要。

---

## 优化主题踩坑（30+）

30. **"内存清理工具"几乎都是 placebo。** 360 内存清理、CCleaner、Mem Reduct、Razer Cortex 等都调用 `EmptyWorkingSet`，只是把内存页从 Working Set 移到 Standby 列表——物理 RAM 占用**不变**。详见 `memory-optimization.md`。**不要推荐用户安装任何这类工具**。

31. **不要禁用 SysMain（Superfetch）除非你确定机器配置。** 现代机器（SSD + 8 GB+ 内存）SysMain 加速应用冷启动，禁用反而变慢。判断方法：`Get-PhysicalDisk | Select MediaType`（SSD = 4，HDD = 3）。详见 `services-optimization.md` SysMain 节。

32. **不要禁用 Windows Defender 来"优化性能"。** Defender 在 Win10/11 已经非常轻量（CPU < 2%），禁用后安全风险巨大。**正确做法**：开发目录放 Dev Drive 用性能模式；排除列表是 🟠 HIGH 的最后手段，只排除可再生成的构建产物。详见 `performance-tuning.md` 第七节。

33. **不要禁用 Windows Update 来"提速"。** 收益几乎为零，安全风险巨大。正确做法：设置"工作时间不更新"，或保持默认自动更新。

34. **页面文件不要设为 0。** 即使物理内存很大，Windows 需要页面文件生成崩溃转储（蓝屏诊断）。**最小值**：1 GB（仅给崩溃转储用）。完全禁用会导致崩溃转储失败。

35. **服务禁用需要管理员权限。** `Disable-ScheduledTask`（计划任务）和 `sc.exe config ... start= disabled`（服务）经常因权限不足失败——错误信息为 "Access is denied"。**解决方案**：用 `Start-Process powershell -Verb RunAs` 提权，会弹 UAC。

36. **提权后的 `Stop-Service` 对部分受保护服务无效。** 例如 `DiagTrack`、`RemoteRegistry` 等被系统保护的服务，停止时可能需要 5-10 秒等待，或在 `Stop-Service` 后加 `Start-Sleep -Seconds 5`。

37. **bloatware 卸载前先看进程列表。** 360 安全卫士等带自我保护的标准卸载会失败——必须先终止进程（`Stop-Process -Force`），再走标准卸载。详见 `software-uninstall.md`。

38. **360 内核驱动普通方法删不掉。** `360AvFlt`、`360Box`、`360FsFlt`、`360SelfProtection` 是内核级驱动，先关自我保护、走官方卸载、重启后再看残留；仍有残留再建还原点进安全模式处理（v2.0：第三方强卸脚本降为 🔴 CRITICAL 最后手段，见 `software-uninstall.md` 360 节）。**不要用普通 `Remove-Item` 操作这些驱动文件**——可能导致系统无法启动。

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

50. **不要排除 IDE 进程（v2.0 改）。** `Add-MpPreference -ExclusionProcess "Code.exe"` 会让该进程读写的所有文件都不被扫描，包括它打开的恶意项目和插件。v1.x 推荐过，v2.0 撤回；需要提速用 Dev Drive。

51. **服务禁用后某些计划任务会自动启用服务。** 例如 `WaaSMedicSvc` 服务可能被某些 Windows Update 计划任务重新启用。**禁用计划任务**和**禁用服务**需要同时进行。

52. **HKCU 注册表修改不需要管理员权限，但 HKLM 需要。** 写脚本时先检测权限（`$isAdmin`），非管理员时只改 HKCU 项；HKLM 项放提权脚本里。

53. **修改电源计划需要管理员。** `powercfg /setactive` 在普通权限下报"Access is denied"。需要 `Start-Process -Verb RunAs`。

54. **服务禁用后系统某些功能可能延迟几小时才察觉。** 例如关 WSearch 后，Outlook 搜索结果可能要重启后才明显改变。**不要立刻回退**——等 24 小时确认是配置问题还是真问题。

55. **"内存 80% 就紧张"的判断是错的。** Windows 内存管理 Standby 缓存，80% 是**正常**。只有 Available < 500 MB 才是真压力。详见 `memory-optimization.md`。

56. **TRIM 对 SSD 的重要性被高估了。** 现代 SSD 都有 GC（垃圾回收），TRIM 是"提示"而不是"必须"。**但开启 TRIM 仍然是好习惯**（默认开）——不会造成伤害。

57. **Defender 排除路径用绝对路径，不要用通配符。** `Add-MpPreference -ExclusionPath "D:\code\projects\*\node_modules"` 这种通配符**不生效**。需要逐个写具体路径——**不要因此改成排除整个父目录**（v2.0）。

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

15. **mklink 迁移时复制工具的两大隐形坑（迁移必读，通用）。** （一）**稀疏文件膨胀**：robocopy 默认把稀疏文件（sparse file，逻辑大小远小于分配大小）展开到完整大小——常见于虚拟磁盘镜像类文件（如 TRAE `VMCache`、WSL2 `ext4.vhdx`、Docker VHD 等），复制后目标体积膨胀 2-3 倍。识别方法：`fsutil sparse queryflag <文件>`。**对策**：对含稀疏文件的子目录单独用 xcopy 或 `Copy-Item -Recurse`。（二）**junction 跟踪**：robocopy 默认跟随源目录内的 junction point，把 junction 指向的目标内容也复制一份，导致文件数暴增数倍。**对策**：加 `/XJ` 排除 junction。xcopy 没有这两个问题，但有 260 字符路径长度限制，深层 `node_modules` 会报"路径找不到"并跳过。实战最稳方案：**xcopy 复制主体 + robocopy `/XJ /E` 补充长路径子目录**，最后用文件数+大小双重验证。另外，bash/cmd 下直接调 robocopy 时 `/E`、`/MIR` 等参数会被 shell 当路径解析，必须写成 `.ps1` 脚本通过 `powershell -File` 执行。详见 `references/mklink-migration.md` 通用指南与 `references/migration-cases.md` Case A 实战。

16. **非系统盘扫描策略与 C 盘完全不同。** C 盘有固定的 AppData 分层结构，可以逐层深入扫描。D 盘等非系统盘的目录结构完全由用户习惯决定，没有统一模式。正确做法是**根目录一级展开**，按大小排序后逐个识别，而不是套用 C 盘的 AppData 扫描逻辑。对 D 盘做 `Get-ChildItem -Recurse` 全盘扫描会非常慢（几十 GB 到上百 GB），应该只扫描根目录一级，然后对可疑大目录再深入一层。

---

## 2026-09 自启动 + 迁移彻底化（踩坑 68-78）

> 依据：Edge/Chrome 官方策略与支持页、微软官方文档、Stack Overflow / GitHub issue / CSDN 复盘等多源交叉核验（详见 `startup-mechanisms.md`、`startup-audit.md`、`mklink-migration.md`、`drive-migration-official.md`、`chat-apps-migration.md`）。

### 自启动"关不彻底"（68-70）

68. **Edge/Chrome 自启"关了还会冒出来"的根因：只删了 Run 键，没关浏览器自己的后台开关。** Edge 的 `MicrosoftEdgeAutoLaunch_<hash>`、Chrome 的 `GoogleChromeAutoLaunch_<hash>` 只是"执行层"，真正的"开关层"是 Edge 的**启动提升(Startup Boost)+ 后台运行扩展** 与 Chrome 的**后台运行应用**。只删 Run 键不关开关，浏览器一运行/更新就把 Run 键写回。**对策（顺序不可反）**：①先关内置开关（用户级注册表），②强烈建议再写 `HKLM\SOFTWARE\Policies\...` 策略强制（防写回，管理员），③最后删 Run 键。完整命令见 `startup-audit.md` 浏览器专项。

69. **Chrome 没有「启动提升 / Startup Boost」——那是 Edge 的功能。** 中文网大量文章将此混为一谈（Chrome 官方策略列表从未包含 `StartupBoostEnabled`）。给 Chrome 做彻底关闭时不要去找不存在的"启动提升"开关，Chrome 的对应物就是"关闭后继续运行后台应用"（`BackgroundModeEnabled`）+ Run 键。

70. **Edge ≥153 新增"开机后可见启动"策略 `LaunchEdgeOnWindowsStartupEnabled`。** 用户反馈"开机直接弹出 Edge 窗口"而非后台进程时，查这个策略并置 0（`HKLM\SOFTWARE\Policies\Microsoft\Edge`，管理员）。它与"启动提升"的后台静默预启动是两回事。

### 自启动隐藏机制（71-73）

71. **任务管理器「启动」页"已禁用"只是打标记，Run 键值仍在。** 禁用状态记在 `HKCU\...\Explorer\StartupApproved\Run`（首字节 02=禁用/03=启用），Run 键本身没删。这解释了"看起来关了还会自启"，也解释了某些软件的勾反逻辑。彻底处理＝删除对应 Run 值。

72. **Winlogon / Active Setup / AppInit / 策略 Run 等 20+ 个隐藏启动点，常规审计脚本看不到。** 用户说"实在找不到它怎么起来的"时，用微软官方工具 **AutoRuns**（Sysinternals，`download.sysinternals.com/files/Autoruns.zip`），勾选"隐藏微软签名项"后一键看全部第三方自启，比手查快 10 倍。详见 `startup-mechanisms.md`。

73. **Chrome/Edge 的 `msedgewebview2.exe` / WebView2 组件进程不是浏览器自启。** 很多桌面应用（Office、各种 Electron 外壳）用 WebView2 渲染界面，进程名带 msedge。验证"Edge 是否还自启"时，只看 `msedge.exe`，别把 `msedgewebview2.exe` 误判为失败。

### 迁移"搬不彻底"（74-78）

74. **微软从未官方支持"用 junction 搬 AppData"。** 官方受支持通道是文件夹重定向（Folder Redirection），且官方清单**明确不含 AppData\Local**（官方文档：https://learn.microsoft.com/en-us/windows-server/storage/folder-redirection/folder-redirection-using-group-policy ）。想"官方地"搬用户数据→用系统重定向；AppData 只能走"软件官方迁移/配置项"或"有依据地 junction"（见 `mklink-migration.md` 兼容性预检）。

75. **微信 4.x"改了保存位置还占 C 盘"的典型原因：`%APPDATA%\Tencent\xwechat` 那份没搬走。** 微信 4.x 数据目录在 `Documents\xwechat_files`（应用内可迁），但配置/登录缓存 `%APPDATA%\Tencent\xwechat`（实测可近 1 GB）**不会随迁移自动搬走**。迁移后需单独清理（退出微信后清 `log/crashinfo` 等，勿动 `config/login`）。详见 `chat-apps-migration.md`。

76. **OneDrive 不认识 junction 目录。** 把目录 mklink 塞进 OneDrive，会导致"单向同步/一直 processing/不上传"。官方确认：OneDrive 原生不支持同步 symlink/junction，同步的是被指向的真实目录。避开：用 OneDrive 官方"更改位置 / 已知文件夹移动"。

77. **新版 Chrome 程序目录（`Program Files\Google`）不能用 junction 迁移——会闪退。** Chrome 138+ 的 App-Bound Encryption 密钥与安装路径绑定：junction 后物理路径（`D:\`）与注册表路径（`C:\`）不一致，报 `Unable to decrypt key ... 0x80070002`，默认浏览器注册也失效。**正解**：官方离线包 `ChromeStandaloneSetup64.exe --install-dir="D:\..."` 真装到 D 盘，或只迁数据不动程序文件。同样，MSIX/UWP 应用（如 Claude/Codex）的数据目录含 junction 会写虚拟化异常，慎用。

78. **迁移后要验证"真的搬走了且没坏"再算完成。** 三个动作：① `(Get-Item <路径> -Force).LinkType` 应为 Junction、Target 指向 D 盘；② 重启后任一时刻在 C 盘路径建文件，去 D 盘确认可见；③ **残留写入检测**：记录 C 盘该目录大小，一周后对比是否回升（或用 Sysinternals ProcMon 过滤 `Path contains C:\Users\<用户>\AppData` 的 WriteFile/CreateFile 看有没有组件绕过 junction 就地重建）。详见 `mklink-migration.md`"官方限制与真实失败案例"。

### 深度根治与现代系统避坑（79-86）

79. **WPS 自动更新反复复活的根因：只删计划任务没用，源头是注册表 `UpdateMode=auto`。** 只要打开任意文档，WPS 主程序就会触发静默检查，重新向任务计划程序写入 `WpsUpdateTask` 和 `WpsUpdateLogonTask`，并重新注册 `wpscloudsvr` 服务。**对策**：先将 `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo` 下的 `UpdateMode` 和 `LastUpdateMode` 改为 `manual`，再禁用计划任务并降级服务。

80. **百度网盘与迅雷后台守护服务：退出界面不等于退出服务。** 百度网盘的 `YunDetectService` 与迅雷的 `XLServicePlatform`、`ThunderNetwork` 是独立系统服务，即使退出客户端，服务仍以 SYSTEM 运行进行后台探测或 P2P 上传。**对策**：必须在服务管理器或通过 `sc config <svc> start= disabled` 彻底禁用底层服务。

81. **搜狗输入法打字伴随唤醒 `SogouCloud` 与 `SGDownload`。** 输入法不是独立进程而是 IME DLL。打字时任何窗口加载输入法都会触发后台唤醒。**对策**：输入法设置中关闭「云计算候选」与「今日热点」，禁用其更新任务，并对 `SGDownload.exe` 配置出站防火墙规则。

82. **Windows 11 24H2 磁盘清理显示 8.63 GB 更新残留无法清除是误报。** 微软官方确认此为 UI 计算标记 Bug，实际旧更新已完成释放。**绝不要强删 `C:\Windows\WinSxS`**，否则可能损坏系统组件导致无法接收后续安全更新。

83. **Ollama 本地大模型与 Hugging Face 权重默认吞噬 C 盘。** 运行 DeepSeek / Qwen 等大模型，权重默认保存在 `%USERPROFILE%\.ollama\models`，动辄占用数十 GB。**对策**：配置系统环境变量 `OLLAMA_MODELS=D:\OllamaModels` 与 `HF_HOME=D:\HF_Cache`，重启服务后官方原生换盘，严禁无脑 mklink。

84. **Win11 24H2 默认开启 BitLocker 加密时的系统还原风险。** 在创建系统还原点或进行驱动清理前，应使用 `manage-bde -status C:` 检查加密状态，提醒用户在微软账户备份好 48 位恢复密钥，避免还原异常触发恢复锁定。

85. **TCP Nagle 算法优化（TcpAckFrequency/TCPNoDelay）写在 `Tcpip\Parameters` 根下是完全无效的静默空跑。** 微软官方网络协议栈规范确认，`TcpAckFrequency` 与 `TCPNoDelay` 必须写入到当前活动网卡的特定 GUID 键值下：`HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{AdapterGUID}`。写在全局 Parameters 下系统不会读取，导致所谓“网络优化”变成安慰剂。**对策**：必须动态枚举网卡或路由匹配出有 IPv4 地址分配的活动网卡 GUID，再写入配置并重启网卡使之生效。

86. **IFEO 映像劫持（Image File Execution Options）阻断弹窗时，Debugger 绝对不能随手乱填不存在的路径或空字符串。** 若 Debugger 键值无效，Windows 在尝试启动该 exe 时会弹系统级“找不到文件”报错框，或者引起调用方死循环反复抛异常拉起子进程。**对策**：必须将其劫持映射到 Windows 内置的静默退出宿主程序，如 `systray.exe` 或 `rundll32.exe`，确保被劫持的弹窗进程瞬时无感退出，既不弹窗也不报错。

---

## 深水区：官方规范基线与安全探针（原 pitfalls.md，v2.0 并入）

> 涉及 DISM / WinSxS、Installer 缓存、卷影副本、云端随选文件时先读本节。

<!-- skill-doctor: allow-block SEC002 -->

> 本指南聚合 GitHub 顶级开源磁盘清理工程实践、微软官方架构内部白皮书（DISM/VSS/CompactOS）与【冷门长尾探索池】中的真实生产级故障，为 Windows 深度清理与磁盘优化提供防破坏与避坑准则。

---

### 一、 微软官方规范与系统级清理基线

### 1. WinSxS 组件存储库与 Hard Link 错觉
- **官方原理**：`C:\Windows\System32` 中的大量文件并非独立实体，而是通过 NTFS 硬链接（Hard Link）指向 `C:\Windows\WinSxS` 中的物理文件。普通扫描工具（如简单的目录求和）会重复计算硬链接大小，产生 WinSxS 虚胖假象（看起来占用 20GB+，实际独占空间仅 6~8GB）。
- **官方清理规范**：
  - 第一步（分析可回收空间）：`Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore`；
  - 第二步（标准安全回收）：`Dism.exe /Online /Cleanup-Image /StartComponentCleanup`。
- **🚨 致命风险禁区（`/ResetBase`）**：
  - 严禁默认执行 `Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase`！
  - **根因**：`/ResetBase` 会物理删除组件存储中所有被取代的旧版本补丁，执行后**当前所有已安装的累积更新（LCU）将永久无法卸载和回滚**。若未来微软补丁出现兼容性 Bug，用户将无法通过卸载补丁自救。必须仅在用户明确了解该不可逆后果时手动授权执行。

### 2. Windows 交付优化缓存 (Delivery Optimization)
- **官方规范**：Windows 10/11 从网络或对等节点下载更新时，会在 `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache` 缓存分块文件。
- **推荐做法**：调用系统原生支持的 PowerShell 命令 `Delete-DeliveryOptimizationCache` 或使用系统磁盘清理 API，严禁手动直接 `rmdir` 导致 BITS 传递队列异常。

### 3. CompactOS 原生系统文件压缩
- **官方原理**：微软自 Windows 10 引入的基于 WOF（Windows Overlay Filter）与 XPRESS4K/LZX 算法的系统核心文件无损压缩技术。
- **查询状态**：`compact.exe /compactos:query`；
- **安全启用**：`compact.exe /compactos:always`，可在不影响系统性能与冷启动速度的前提下，稳定释放 2.0GB ~ 4.5GB C 盘空间。

### 4. 休眠文件 `hiberfil.sys` 与快速启动的取舍平衡
- **常识误区**：许多脚本直接执行 `powercfg -h off`，虽然释放了与物理内存大小相当的 `hiberfil.sys`，但会**静默关闭 Windows 快速启动（Fast Startup）**，导致机械硬盘或旧电脑开机变慢 3~5 倍，且在现代待机（Modern Standby / S0ix）笔记本上可能引起异常耗电。
- **最佳实践**：
  - 若需保留快速启动但节省空间，执行：`powercfg /h /type reduced`（体积缩减 50% 并保留快速启动）；
  - 仅在用户确认不使用休眠且要求极致空间释放时，才执行 `powercfg -h off`。

### 5. 虚拟内存页面文件 (`pagefile.sys`) 底线
- **崩溃转储基线**：即便物理内存（RAM）高达 32GB/64GB，也**严禁将页面文件完全设为 0**。
- **根因**：完全禁用页面文件会导致 Windows 在遭遇内核故障时无法生成内存转储（Minidump / Memory.dmp），且部分老旧软件与 Direct3D 大作在 Commit Charge 达到 100% 时会直接崩溃闪退（报 0x0000003B / 0x0000001A MEMORY_MANAGEMENT）。页面文件安全下限为 1024MB。

---

### 二、 【冷门长尾探索池】极端特异性杀手坑

### 1. OneDrive / iCloud "文件随选 (Files On-Demand)" 水合雪崩陷阱
- **病症**：许多递归扫描、哈希校验或清理脚本在扫描 `%USERPROFILE%` 时，越扫 C 盘反而越满，网络流量暴增数百兆。
- **底层机理**：
  - 云存储的“文件随选”采用 NTFS 重解析点（Reparse Points）与稀疏文件机制，本地仅保存几个字节的占位符元数据；
  - 传统脚本遍历读取文件头、获取哈希或读取内容时，Windows 文件系统微筛选驱动（Filter Driver）会将其判定为“用户正在读取该文件”，从而触发云端自动将整份文件实时下载（Hydration 水合）到本地 SSD，导致空间直接被占满！
- **防御对策**：
  - 在 PowerShell 遍历中，必须检查并跳过包含以下属性的文件：
    ```powershell
    $isCloudPlaceholder = ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or
                          ($file.Attributes -band [System.IO.FileAttributes]::SparseFile)
    if ($isCloudPlaceholder) { continue } # 跳过，严禁读取内容
    ```

### 2. `C:\Windows\Installer` (.msi / .msp) 误删灾难
- **病症**：扫描发现 `C:\Windows\Installer` 占用数 GB 乃至数十 GB，用户或激进清理工具手动全选删除。
- **后果**：直接导致已安装的 Microsoft Office、Visual Studio、SQL Server、AutoCAD 等大型软件**永久无法更新、打补丁、修复或卸载**，再次点击卸载将报错 `The installation source for this product is not available`（微软官方明确声明手动删除该目录文件不受支持）。
- **防御对策**：
  - 将 `C:\Windows\Installer` 列入全局只读白名单，严禁直接 `Remove-Item`；
  - 仅支持通过官方卸载程序卸载废弃软件，或借助经过验证的孤儿补丁分析工具（如 PatchCleaner）进行只读探测。

### 3. VSS 卷影副本 (Volume Shadow Copy) 静默清除隐患
- **病症**：使用 `vssadmin delete shadows /all` 一键清空卷影存储以释放几十 GB 空间。
- **后果**：所有系统还原点（System Restore Points）以及文件“以前的版本”（Previous Versions）瞬间物理蒸发。若后续系统更新异常或遭受恶意软件篡改，机器将彻底失去本地秒级回滚防线。
- **防御对策**：
  - 不得将清空卷影副本设为默认执行项；
  - 提供只读查询：`vssadmin list shadowstorage`，仅在空间极度告急且告知用户“所有历史还原点将失效”后由用户显式触发。

### 4. SoftwareDistribution 目录与 Windows Update 服务锁死
- **病症**：直接对 `C:\Windows\SoftwareDistribution` 执行强制递归删除，报“文件被占用拒绝访问”或导致 Windows Update 服务出现 0x80248007 错误码。
- **防御对策**：
  - 仅可清理下载缓存子目录 `C:\Windows\SoftwareDistribution\Download`；
  - 若需重置更新缓存，必须按规范停用服务并按序重启：
    `net stop wuauserv` ➔ `net stop cryptsvc` ➔ 重命名或清理 ➔ `net start cryptsvc` ➔ `net start wuauserv`。

---

### 三、 GitHub 顶级开源项目与同类 Agent 技能对标经验

| 维度 | 行业标杆工具 / 项目 | 沉淀的工程设计范式 |
|---|---|---|
| **MFT 秒级遍历** | **WizTree / Everything** | 对于超大容量磁盘，放弃极慢的逐层 `Get-ChildItem -Recurse`，建议在需要全盘热力图时提示用户使用 MFT 级轻量工具辅助验证。 |
| **五档安全隔离架构** | **BleachBit / Czkawka** | 将清理目标划分严格的安全等级：<br>1. **第一档（无感无损缓存）**：系统与浏览器临时文件、缩略图缓存；<br>2. **第二档（已卸载残留）**：注册表空键、废弃 Roaming 文件夹；<br>3. **第三档（开发环境与构建产物）**：`node_modules`、`.gradle`、`target/`；<br>4. **第四档（应用大文件搬家）**：微信/QQ 存储目录 mklink 重定向；<br>5. **第五档（系统核心禁区）**：`WinSxS`、`Installer`、驱动库，只读排查，绝不强删。 |
| **就近内联动作范式** | **Agent Skills 行业标准** | 消除主工作流中的“可参考/详见”，所有参考手册在步骤下方以 `👉 动作：读取 [文件]` 直达，彻底杜绝 AI 跳步。 |

---

### 四、 自动化安全核验探针 (Safety Probes)

所有诊断脚本与清理建议在落地前，必须通过以下静态与运行时探针断言：

1. **重解析点探针（防云端脱水文件被拉下）**：
   ```powershell
   # 验证代码是否具备重解析点拦截
   if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
       Write-Verbose "Skipping ReparsePoint: $($item.FullName)"
   }
   ```
2. **只读预检探针（Zero-Mutation 断言）**：
   - 探测命令中绝不包含 `-Force` 删除语句；
   - 估算大小必须输出为结构化 JSON 或 Markdown 事实卡供用户审核。
