# 常见陷阱与实战教训

清理、卸载、迁移、优化时容易踩的坑，按主题归类。每条一个规则，细节链接到负责的手册。SKILL.md 在流程关键点按主题引用本文。

## 目录

1. [安全底线（绝不默认做）](#一安全底线绝不默认做)（1–14）
2. [删除、回收站与权限](#二删除回收站与权限)（15–25）
3. [扫描与误判](#三扫描与误判)（26–41）
4. [自启动](#四自启动)（42–50）
5. [卸载与流氓软件](#五卸载与流氓软件)（51–56）
6. [迁移](#六迁移)（57–65）
7. [性能与内存误区](#七性能与内存误区)（66–76）

---

## 一、安全底线（绝不默认做）

1. **不手删 `C:\Windows\WinSxS`。** System32 里大量文件是指向 WinSxS 的硬链接，普通目录求和会重复计算，看起来比实际大。只用官方命令：先 `Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore` 分析，再 `/StartComponentCleanup`。手删可能导致无法开机或无法更新。依据：[Clean up the WinSxS folder](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder)。

2. **不默认加 `/ResetBase`。** `Dism /StartComponentCleanup /ResetBase` 之后，**现有**的更新包都无法卸载（以后安装的更新仍可卸载）。只有用户明确知道这个后果并要求时才做。

3. **Win11 24H2 磁盘清理里"约 8.63 GB 更新残留清不掉"是历史显示问题。** 微软 2024-10 记录为已知问题，2024-10-24（KB5044384）起的更新已缓解，现已不在 24H2 发布健康页上。遇到时不要因此去动 WinSxS。

4. **不碰 `C:\Windows\Installer`。** 这里是已安装 MSI/MSP 的缓存，删了之后 Office、Visual Studio、SQL Server 等会无法更新、修复或卸载（报"installation source is not available"）。只读；需要时用官方卸载程序卸掉不用的软件。`C:\ProgramData\Package Cache` 同理：不删，用产品自己的卸载/修复。

5. **不手删 DriverStore。** `C:\Windows\System32\DriverStore\FileRepository` 会累积旧版驱动（显卡驱动尤其多）。**绝不手动删文件**，只用 `pnputil /enum-drivers` + `pnputil /delete-driver oemXX.inf /uninstall`（详见 `system-cleanup.md`）。扫描阶段只测大小，超过 2 GB 时提示用户。

6. **不默认清卷影副本。** `vssadmin delete shadows /all` 会删掉全部系统还原点和文件"以前的版本"。只读查询 `vssadmin list shadowstorage`；只有空间极度紧张、用户知道"所有还原点会失效"后，由用户明确触发。

7. **不关 Windows Defender 来"优化性能"。** 开发目录提速首选 Dev Drive 的性能模式；排除项是 🟠 HIGH 的最后手段，只排除可再生成的构建产物，不排除整盘，**不排除进程**（`-ExclusionProcess "Code.exe"` 会让它读写的所有文件都不被扫描，包括打开的恶意项目和插件）。详见 `performance-tuning.md`。

8. **Defender 排除路径支持通配符，但有边界。** 微软文档：文件、文件夹、进程排除可用 `*`、`?` 和环境变量；文件夹路径里的 `*` 只匹配一层，如 `D:\code\*\node_modules` 排除 `D:\code\<任一项目>\node_modules` 及其子目录。**文件夹排除不覆盖其下的重解析点子文件夹**——用 junction 迁移过的目录要对目标路径单独排除。依据：[Configure exclusions based on file name, extension, and folder location](https://learn.microsoft.com/en-us/defender-endpoint/configure-extension-file-exclusions-microsoft-defender-antivirus)（2026-11-11 核对）。

9. **不关 Windows Update 来"提速"。** 收益几乎为零，安全风险大。用"使用时段"避开工作时间即可。Windows 10 已停止常规支持，更不能关更新（详见 SKILL.md 运行环境）。

10. **页面文件不要设为 0，大小不要套固定倍数。** 微软的说法是页面文件大小"不能一概而论"，推荐"系统管理的大小"。崩溃转储依赖页面文件（或专用转储文件）：没有足够的页面文件，蓝屏时就写不出转储；所需大小取决于转储类型（小型转储很小，完整转储约为内存 + 257 MB）。`0x3B`、`0x1A` 是蓝屏代码，不是应用崩溃代码。依据：[How to determine the appropriate page file size](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows)。规范做法见 `system-cleanup.md`。

11. **休眠文件：`powercfg /h /type reduced` 缩小约 30%，但会去掉"休眠"选项。** reduced 只保留快速启动（hiberboot）所需；如果之前自定义过大小，先 `powercfg /h /size 0` 恢复系统管理，再改类型。`powercfg -h off` 会同时关掉快速启动，只在用户确认不用休眠也不在乎快速启动时做。依据：[powercfg 命令行选项](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)、[Compact OS](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os)（"Reduces the file by 30%"）。

12. **CompactOS 不是默认动作。** `compact.exe /compactos:query` 查状态；`/compactos:always` 压缩系统文件，微软在 Win10 1607 测试镜像上测得约 2.75–3.7 GB。对性能的影响通常很小，但低速 CPU 或机械硬盘上可能略慢；`/compactos:never` 可撤销。用户同意后才做。

13. **IFEO `Debugger` 屏蔽弹窗是 🟠 HIGH，默认不做。** 它本身就是一种劫持技术（MITRE T1546.012），Microsoft Defender 会检测为 `Behavior:Win32/ifeoDebugger.DB` 并清除，公司 EDR 会告警；按文件名对所有同名 exe 全局生效。只在应用内关推送、关通知、禁用任务都无效且用户明确同意后才用：只指向完整路径的 `systray.exe`，不用 `rundll32.exe`，不填空值或不存在的路径；回退只删 `Debugger` 这一个值，不删整个子键。详见 `bloatware-catalog.md` §9。

14. **改注册表、驱动、系统组件前先留后路。** 注册表一律经 `Set-WcoRegistryValue` / `Remove-WcoRegistryKey`（自动 `reg export` 整个键，生成 undo）；动驱动、跑 DISM 前建还原点（`Checkpoint-Computer`，需管理员，默认 24 小时内只能建一个）。开了 BitLocker 的电脑先用 `manage-bde -status C:` 确认状态，并提醒用户确认恢复密钥已备份（例如在微软账户里）；"创建还原点会触发 BitLocker 恢复"这一说法无可靠来源，存疑。用户数据类清理（进回收站）不需要还原点。

---

## 二、删除、回收站与权限

15. **移入回收站不释放空间。** 文件还在原盘上，清空回收站才释放。阶段 5 必须明确告诉用户。

16. **这些命令是永久删除，不经过回收站：** `rd /s /q`、`del`、`Remove-Item`、`Shift+Delete`、`robocopy /MIR`（目标里多出来的文件会被删除）。默认用 `t07-safe-recycle.ps1`（`Invoke-WcoRecycle`）；它在回收站不可用（U 盘/网络盘、设为直接删除、超过容量上限、策略未知）时拒绝执行，而不是退化为永久删除。

17. **Temp 里大量文件被锁是正常的。** 运行中的程序占用着，跳过即可，不要反复重试；重启后再清。目录很小（< 10 MB）又大量锁定时，记录原因直接跳过，不在小目录上浪费时间。

18. **`C:\Program Files` 下回收失败的报错有误导性。** 非管理员时 SendToRecycleBin 可能报 "This function is not supported on this system"，实际是权限不足。确认非管理员 + 目标在 Program Files 下，就提权重试。超长路径（> 260 字符）是另一种失败，报告为"路径过长"，不能当成"文件被占用"。

19. **哪些操作需要管理员。** HKCU 写入不需要；HKLM、服务启动类型、根目录 `\` 下的计划任务、驱动、DISM、`powercfg /h` 需要。非管理员时典型报错：`sc config` 报 "OpenService FAILED 5: Access is denied"，`schtasks /change` 报 "Access is denied"（即使任务属于当前用户）；`\<子文件夹>\` 下的部分任务普通权限可改。做法：普通部分（HKCU、用户目录、Temp）直接跑，需要管理员的部分集中到一个脚本，用 `Start-Process powershell -Verb RunAs` 触发 UAC。`powercfg /setactive` 切换电源计划一般不需要管理员（存疑，遇到拒绝再提权）。

20. **原生命令失败要看退出码。** `schtasks`、`sc`、`reg` 失败时 PowerShell 不会抛异常；不加重定向时它们的错误输出会显示，但脚本里容易被 `| Out-Null` 吞掉。每次调用后检查 `$LASTEXITCODE`，需要日志时 `Start-Process ... -Wait -PassThru -RedirectStandardError <文件>`。

21. **提权进程写日志用绝对路径。** `Start-Process -Verb RunAs` 启动的管理员进程环境可能不同（尤其是用另一个管理员账户提权时），`$env:TEMP` 和 `HKCU` 可能指向别的账户。日志写固定的绝对路径（或由调用方传 `-OutDir`）；要改当前用户 HKCU 的步骤在用户自己的普通会话里跑。

22. **诊断/临时脚本不要放用户目录。** 写到 `$env:TEMP\wco\`，用完即删；用户目录里散落一堆 `.ps1` 会被当成垃圾。

23. **`HKCR\*` 通配符枚举极慢甚至卡死。** HKCR 是 HKLM\Software\Classes 与 HKCU\Software\Classes 的合并视图，含几十万项。改查具体路径，如 `HKLM:\Software\Classes\*\shellex\ContextMenuHandlers`、`...\Directory\shellex\ContextMenuHandlers`、`...\Directory\Background\shellex\ContextMenuHandlers`、`...\Drive\shellex\ContextMenuHandlers`，以及 HKCU 下的同名路径。

24. **系统更新缓存只走官方入口。**
    - 传递优化缓存：用磁盘清理里的"传递优化文件"，或 `Delete-DeliveryOptimizationCache -Force`（[官方 FAQ](https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-faq)）；不手删目录。缓存实际位置随版本不同（常见于 `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache`，属观察值），以 `system-cleanup.md` 为准。
    - `C:\Windows\SoftwareDistribution`：只清 `Download` 子目录。重置更新缓存时依次停止 `wuauserv`、`bits`、`cryptsvc`，把 `SoftwareDistribution` 改名为 `SoftwareDistribution.old`、`System32\catroot2` 改名为 `catroot2.old`，再启动这三个服务（改名而不是删除，出问题能改回）。

25. **浏览器和聊天软件的缓存在应用内清。** Edge/Chrome 用"清除浏览数据"；微信/QQ/腾讯视频用应用内的存储管理——缓存格式私有，直接删文件夹可能损坏聊天记录或让浏览器异常。

---

## 三、扫描与误判

26. **"疑似残留"不是"确认残留"。** 卸载注册表的 `DisplayName` 和 AppData 目录名不一定对应（如目录 `VMware` 对应 `VMware Workstation Pro`）；商店应用、用别的名字建目录的套件、厂商公共目录（`Tencent`、`Kingsoft`、`JetBrains`）都会被误判。对没匹配上的目录一律标"疑似"，用 `Find-WcoLeftover` 打分，让用户做最终决定。

27. **软件改名会让交叉比对失效。** 例：TRAE Solo 改名 TRAE Work 后，`%APPDATA%\TRAE SOLO CN` 目录名没变，注册表 DisplayName 变成 `TRAE Work CN (User)`，正在用的软件被标成残留。先看进程列表里有没有对应进程，再下结论。

28. **不要用硬编码安装路径判断"没装"。** 第三方渠道装的软件常在非标准位置（如 `<自定义安装根>\WPS Office\<版本号>\office6\`）。先 `Get-WcoInstalledProgram` 从卸载注册表反查 InstallLocation，再扫候选根，最后用进程路径兜底（见 `bloatware-catalog.md`"多路径检测方法学"）。

29. **非系统盘根目录的 32 位十六进制名隐藏目录，多半是视频流缓存。** 识别：隐藏属性 + 哈希名 + 内含 `.ts`/`.m3u8`/`.hls` 分片。先看 LastWriteTime：最近几天有写入说明播放器正在用，删除会失败或打断播放，先告诉用户"会自动重建"。

30. **软件搬家会留下旧备份，命名不止一种。** 腾讯电脑管家"软件搬家"会生成 `原目录名 - AppData`、`软件名_腾讯电脑管家搬家目录_<数字>`。对应软件已卸载 → 可进回收站；还在用 → 先确认 C 盘是否有 junction 指向它。

31. **不能只看顶层 LastWriteTime 判定孤儿目录。** 搬家目标（如 `D:\Users\<用户名>\AppData\Local\Programs\*`）顶层时间可能很旧（迁移时间），里面的软件仍在活跃写入。逐层看内部每个软件的 LastWriteTime，并检查 C 盘是否有 junction 指向这里。

32. **非系统盘上带版本号的 IDE 目录大概率是旧版残留。** 如 `D:\IntelliJ IDEA Community Edition 2022.1.3`：目录名含版本号 + 半年以上没写入 + 注册表无对应安装记录 → 疑似旧版，列给用户确认。

33. **乱码目录名不代表损坏。** 老工具用 GBK 建的目录可能显示成乱码。用 `[System.IO.Directory]::GetDirectories('D:\')` 读真实名；不要凭乱码猜内容，先看里面（实例：乱码目录里是 `Tencent Files`，是 QQ 聊天数据，属第四档）。

34. **非系统盘用"根目录一级展开"，不要整盘递归。** C 盘有固定的 AppData 分层可逐层深入；D 盘结构由用户习惯决定，整盘 `-Recurse` 很慢。先展开根目录一级按大小排序，再对可疑大目录深入一层。

35. **大目录递归扫描很慢，辅以 WizTree / TreeSize Free。** `Get-ChildItem -Recurse` 扫几 GB 要几分钟；WizTree 读 NTFS MFT，几秒出全盘分布。用户对结果有疑问时建议用它们核对。

36. **硬链接会被重复计算。** WinSxS 与 System32 之间、微信 4.x 新旧目录之间（微信官方 FAQ：4.0 迁移优先使用硬链接，大部分文件不占双份空间，[kf.qq.com](https://kf.qq.com/faq/250710MraIZj250710QniyAr.html)）都有硬链接。按路径求和会高估；删除其中一份释放的空间可能远小于它的显示大小。估算"能省多少"时说明这一点（WizTree 等工具按文件 ID 去重）。

37. **扫描时不要读取云文件占位符的内容。** OneDrive / iCloud 的"按需文件"本地只有占位符；脚本读取文件内容、算哈希时会触发自动下载（水合），越扫 C 盘越满、流量暴增。遍历时跳过带 `ReparsePoint` / `SparseFile` / `RecallOnDataAccess` 属性的文件，只读属性和长度（不会触发下载）。注意已下载到本地的 OneDrive 文件也带云重解析标记，因此按这个规则统计会少算，报告时写"OneDrive 本地占用见 OneDrive 设置"，不要写 0。

38. **Windows PowerShell 5.1 的 `Get-ChildItem -Recurse` 会钻进 junction。** "不跟随链接"是 PowerShell 6.0 起的行为。在 5.1 上先过滤再统计没用——过滤发生在遍历之后。测大小要在进入目录前跳过 `ReparsePoint`，否则迁移到 D 盘的数据会被算成 C 盘占用。路径里有 `[`、`]` 时用 `-LiteralPath`，否则会被当成通配符，结果静默为 0。

39. **electron 应用的更新器缓存常年无人清理。** 在 `%LOCALAPPDATA%`、`%APPDATA%` 下找 `*updater*`、`*-updater`、`pending` 一类目录（例：`qwen-work-cn-updater` 200+ MB），与卸载注册表交叉比对：软件已卸载就清，还在用看大小决定。模板见 `scan-scripts.md` T5。

40. **Python 全局环境会膨胀。** 全局 `site-packages` 可能累积到几 GB。建议改用虚拟环境（如 `uv venv`），而不是反复清理全局包。

41. **WSL2 虚拟磁盘不会自动缩小。** `ext4.vhdx` 在 WSL 里删了文件也不会变小。做法：WSL 内先 `sudo fstrim -av`；较新的 WSL 提供 `wsl --manage <发行版> --compact`（较新版本才有，存疑：以 `wsl --help` 为准）；否则 `wsl --shutdown` 后用 diskpart `compact vdisk`。稀疏 VHD（`sparseVhd` / `--set-sparse true`）有数据损坏报告，较新版本已加门槛，不作默认推荐（存疑，见 `drive-migration-official.md`）。

---

## 四、自启动

42. **浏览器自启"关了还会冒出来"：只处理了 Run 值，没关浏览器自己的开关。** Edge 的 `MicrosoftEdgeAutoLaunch_<hash>`、Chrome 的 `GoogleChromeAutoLaunch_<hash>` 是执行层；开关层是 Edge 的启动提升 + 后台运行、Chrome 的后台运行应用。顺序不可反：①关浏览器内开关 → ②（推荐）写 `HKLM\SOFTWARE\Policies\...` 策略防写回 → ③关 Run 项的启动开关。完整命令见 `startup-audit.md` 浏览器专项。

43. **Chrome 没有「启动提升 / Startup Boost」，那是 Edge 的功能。** Chrome 的对应物是"关闭后继续运行后台应用"（策略 `BackgroundModeEnabled`）+ Run 值。

44. **"开机直接弹出 Edge 窗口"查两处。** Edge ≥153 的策略 `LaunchEdgeOnWindowsStartupEnabled`（`HKLM\SOFTWARE\Policies\Microsoft\Edge`，置 0）；以及 Win11 的"自动保存我的可重启应用，并在我重新登录时重启它们"（设置 › 账户 › 登录选项）。两者都与启动提升的后台预启动不同。

45. **任务管理器"禁用"不删 Run 值，只写 StartupApproved。** 状态在 `...\Explorer\StartupApproved\Run`（`Run32`、`StartupFolder`）：首字节 `02` = 启用、`03` = 禁用（`06`/`07` 为变体），没有值 = 启用。审计时必须读这个状态，否则会把用户已关掉的项再报一遍。可逆关闭用 `Set-WcoStartupApproved`；删除 Run 值只作可选的第二步（先 `reg export`）。

46. **常规审计看不到的启动点，用 Autoruns 查。** Winlogon、Active Setup、AppInit、策略 Run、IFEO、WMI、隐藏计划任务等 20 多个位置。Autoruns（Sysinternals）勾选"隐藏微软项"看第三方自启；取消勾选 = 禁用，可勾回。详见 `startup-mechanisms.md`。

47. **`msedgewebview2.exe` 不是 Edge 自启。** 很多桌面应用用 WebView2 渲染界面。验证 Edge 是否还自启时只看 `msedge.exe`。不要卸载 WebView2 运行时。

48. **"复活型"软件要先切源头。**
    - **WPS**：`ksolaunch.exe` 每次运行都重建更新任务——先把 `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo` 的 `UpdateMode` 和 `LastUpdateMode` 改为 `manual`（只改 UpdateMode 可能被改回），再禁用三个任务、`wpscloudsvr` 服务（三层修复见 `software-uninstall.md`）。
    - **百度网盘 / 迅雷**：退出界面不等于退出服务，`YunDetectService`、`XLServicePlatform`、`ThunderNetwork` 以独立服务运行，需改启动类型。
    - **搜狗输入法**：以 IME 加载进各程序，打字时拉起 `SogouCloud`、`SGDownload`；先在设置里关云候选和资讯，再禁用更新任务；防火墙规则要写确切路径。

49. **服务禁用后可能被计划任务或修复服务重新启用。** 例：Windows 更新相关的修复机制会把更新服务改回来。需要同时看对应的计划任务；系统更新服务本来就不应禁用（第 9 条）。

50. **改服务/任务后，部分影响要过一阵才显现。** 如关 Windows Search 后 Outlook 搜索的变化要重启后才明显。不要立刻回退，观察一天再判断。

---

## 五、卸载与流氓软件

51. **卸完要复扫才能说"已卸载"。** 卸载程序跑完只能说"已启动卸载程序"；重启后用 `Get-WcoInstalledProgram` + `Find-WcoLeftover` 确认条目和残留都没了，再汇报。流程见 `software-uninstall.md`。

52. **自保护软件（360 等）：先关自我保护，走官方卸载，重启后再看残留。** 不要先 `Stop-Process -Force` 硬杀进程。`360AvFlt`、`360Box`、`360FsFlt`、`360SelfProtection` 等内核/过滤驱动重启后才真正移除；仍有残留 → 建还原点进安全模式（设置 › 恢复 › 高级启动，F8 默认无效）。**不要用 `Remove-Item` 删驱动文件**，可能导致无法开机；第三方强卸脚本是 🔴 最后手段，读完内容才运行，绝不 `irm | iex`。

53. **钉钉保镖（AlibabaProtect）标准卸载后可能残留。** 走官方卸载 → 重启 → 仍在时按 停止 → 禁用 → `Remove-WcoService` 的顺序处理（管理员）；停不下来就进安全模式。不要用 `sc delete` + `rd /s /q` 直接删。

54. **WPS 卸载后 Kingsoft 目录残留大。** 典型残留：`addons\pool\win-i386\`（旧版插件）、`%APPDATA%\kingsoft`、`%LOCALAPPDATA%\Kingsoft`。只删 WPS 产品子键，不删 `HKCU\Software\Kingsoft` 根键（可能有金山其他产品）。

55. **按服务名通配符批量删除会误伤。** `360*`、`*2345*` 会匹配到显示名碰巧相似的其他服务，而且 `Get-Service` 看不到驱动。按 `PathName`（可执行文件路径）判断归属，逐个处理。

56. **首页"改回去又被改回来"，可能是驱动级或服务级劫持。** 反复改注册表无效时，交给安全软件处理；先用 T23/T24/T25 找写入来源。

---

## 六、迁移

57. **装到 D 盘不代表 AppData 搬走了。** 大多数软件（TRAE、VS Code、各类 IDE 和 AI 客户端）本体装到 D 盘，用户数据和缓存仍写 `C:\Users\<用户名>\AppData`。先找软件官方的"更改数据位置/缓存位置"，再考虑 `mklink-migration.md`。

58. **微软从未官方支持"用 junction 搬 AppData"。** 官方受支持的是文件夹重定向，且清单不含 AppData\Local（[Folder Redirection](https://learn.microsoft.com/en-us/windows-server/storage/folder-redirection/folder-redirection-using-group-policy)）。AppData 只能走软件官方迁移/配置项，或有依据的 junction（见 `mklink-migration.md` 兼容性预检）。

59. **复制工具：统一用 robocopy，必须加 `/XJ`。**
    - robocopy 默认会**跟随** junction（`/XJ` 排除"默认会包含的"junction），不加会把链接指向的内容再复制一份，文件数和体积暴增。
    - robocopy 默认**保留**文件的稀疏状态（`/sparse` 默认为 yes），"robocopy 会展开稀疏文件"的说法不对；复制后可用 `fsutil sparse queryflag <文件>` 核对。
    - xcopy 默认会**复制符号链接指向的文件**（加 `/b` 才复制链接本身），并非"不跟随链接"，不再推荐 xcopy 混用方案。
    - 推荐：`robocopy <源> <目标> /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1`，完成后用文件数 + 大小双重核对。在 bash/cmd 里传 `/E` 等参数可能被当路径解析，写进 `.ps1` 用 `powershell -File` 执行。
    - 依据：[robocopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy)、[xcopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/xcopy)（2026-11-11 核对）。

60. **微信 / QQ / 腾讯会议不要用 mklink 迁移。** 用应用内"存储位置/文件管理"迁移，mklink 可能损坏数据。详见 `chat-apps-migration.md`。

61. **微信 4.x 改了保存位置还占 C 盘：`%APPDATA%\Tencent\xwechat` 没搬走。** 数据目录 `xwechat_files` 可在应用内迁移，但配置/登录缓存 `%APPDATA%\Tencent\xwechat` 不随迁移走。退出微信后只清 `log`、`crashinfo` 一类，不动 `config`、`login`。详见 `chat-apps-migration.md`。

62. **OneDrive 不支持同步 junction / 符号链接。** 把 mklink 目录放进 OneDrive 会出现不同步、一直处理中。用 OneDrive 自己的"更改位置 / 备份文件夹"（[OneDrive 限制](https://support.microsoft.com/en-us/office/restrictions-and-limitations-in-onedrive-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa)）。

63. **Chrome 程序目录不要用 junction 迁移。** Chrome 的应用绑定加密（App-Bound Encryption，Chrome 127 起）与安装路径相关，junction 后会出现解密失败、闪退、默认浏览器注册失效等报告。要装到 D 盘就重新安装到 D 盘（安装器是否支持 `--install-dir` 参数存疑，以 Google 文档为准），或只迁数据不动程序文件。MSIX/商店应用的数据目录含 junction 也容易出问题，慎用。

64. **迁移后要验证"真的搬走了且没坏"。** ① `(Get-Item <路径> -Force).LinkType` 为 Junction、Target 指向 D 盘；② 在 C 盘路径新建文件，到 D 盘确认可见；③ 记录 C 盘该目录大小，一周后对比是否回升（或用 ProcMon 过滤该路径的写入），看有没有组件绕过 junction 就地重建。

65. **AI 模型缓存用官方环境变量换盘，不用 mklink。** Ollama：`OLLAMA_MODELS=D:\OllamaModels`；Hugging Face：`HF_HOME=D:\HF_Cache`；设好后重启服务/终端。详见 `drive-migration-official.md`。

---

## 七、性能与内存误区

66. **不推荐任何"内存清理"工具。** 360 内存清理、Mem Reduct 等调用 `EmptyWorkingSet` 或清空待机列表：被裁掉的页进入待机/修改列表，任务管理器里"可用"内存看起来变多，但随后程序要把它们重新读回来（修改过的页还要先写入页面文件），反而更慢。详见 `memory-optimization.md`。

67. **内存占用 80% 不等于紧张。** Windows 用空闲内存做缓存（待机列表），"可用"= 空闲 + 待机。只有可用内存长期很低、频繁硬错误时才是真压力。

68. **不要随手禁用 SysMain。** SSD + 8 GB 以上内存的机器上，SysMain 有助于应用冷启动。用 `Get-PhysicalDisk | Select-Object MediaType` 看硬盘类型后再判断，详见 `services-optimization.md`。

69. **TRIM 保持默认开启即可。** 现代 SSD 有自身垃圾回收，TRIM 不是"开了就快很多"，但开着没有坏处（Windows 默认开）。

70. **Windows Search 索引范围影响磁盘 I/O。** 不要索引大型代码库（如 `D:\code`）；索引用户库和开始菜单即可。找文件可用 Everything。

71. **电源计划：默认"平衡"。** "卓越性能"会关掉 USB 选择性挂起等节能项，笔记本续航会下降（具体幅度因机器而异）；只在台式机、用户要求时用。

72. **"调整为最佳性能"会关掉字体平滑。** 视觉效果全关后字体发虚，必须手动勾回"平滑屏幕字体边缘"。

73. **NTFS 最后访问时间：先查再改。** `fsutil behavior query disablelastaccess` 看当前状态（新版 Windows 为"系统管理"，会按卷大小自动决定，存疑），不需要无条件设置。

74. **Nagle / TCP 调参只对部分在线游戏可能有用。** `TcpAckFrequency`、`TCPNoDelay` 属于旧式调参，普通办公和网页用户没有收益。确需尝试时写在活动网卡的接口键 `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{网卡GUID}` 下（写在全局 Parameters 下通常不生效），先备份、实测、无效就回退；效果无微软官方确认（存疑）。详见 `performance-tuning.md`。

75. **DoH（DNS over HTTPS）可能让解析变慢。** 改之前后各测一次常用网站的打开速度，变慢就改回。

76. **很多"优化"收益为零而风险不小。** 禁用保留存储、搜索索引、IPv6、合并 svchost、把服务全部改手动——副作用难排查（更新失败、搜索失效、网络问题），本技能不做。
