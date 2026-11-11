# Windows 自启动机制全清单（Startup Mechanisms）

> 用户说"开机慢""有些软件明明关了还会自启""关不干净"——先读本文。Windows 的"自启动"远不止注册表 Run + 启动文件夹 + 计划任务 + 服务 4 类，常见软件和流氓软件会用到的启动点有 **20 多个**。本文依据微软官方文档（Microsoft Learn / Sysinternals）与 MITRE ATT&CK 整理，标清每个机制怎么查、怎么可逆地关、能不能碰。
>
> **给普通用户的一句话**：先用微软官方工具 **Autoruns** 看全（见文末），比手动逐项查快得多；本仓库的只读模板 T10 / T24 / T23 覆盖其中最常见的部分。

---

## 目录

- [自启动机制全清单（表格）](#自启动机制全清单表格)
- [按 Autoruns 类别的检查与关闭矩阵](#按-autoruns-类别的检查与关闭矩阵)
- [现代 Windows 10/11 的启动来源](#现代-windows-1011-的启动来源)
- [高频机制详解](#高频机制详解)
- [普通用户核心审计清单（8 项）](#普通用户核心审计清单8-项)
- [只检不改的高危机制](#只检不改的高危机制)
- [官方工具 Autoruns 使用指南](#官方工具-autoruns-使用指南)

---

## 自启动机制全清单（表格）

> 路径均为通用占位。依据分三档：**🟢 微软官方文档**、**🟡 高可信第三方**（MITRE，路径逐条核验）、**🔴 依据较弱**（工具文档/社区，已标注）。

| # | 机制 | 位置路径 | 依据 | 检出命令（简版） | 风险 |
|---|------|---------|------|------------------|------|
| 1 | **Run / RunOnce / RunOnceEx** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run(Once)`、`HKCU\Software\...\Run(Once)`、64 位系统上 32 位程序另见 `HKLM\SOFTWARE\WOW6432Node\...\Run(Once)`；`HKLM\...\CurrentVersion\RunOnceEx` | 🟢 [Run and RunOnce Registry Keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)、🟡 [Startup apps (wow64 nodes)](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/startup-apps) | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"` 等；T10 / T24 一次列全 | ✅ 常规可查 |
| 2 | **RunServices / RunServicesOnce**（Win9x 遗留） | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices(Once)`、`HKCU\...\RunServices(Once)` | 🟡 MITRE T1547.001（WinNT 系是否执行无现行官方文档） | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices"` | ✅ 检出即可，通常为空 |
| 3 | **用户/系统启动文件夹** | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`（FOLDERID_Startup）、`%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp`（FOLDERID_CommonStartup） | 🟢 [KNOWNFOLDERID](https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid)、🟢 [Developing Applications that Run at Logon](https://learn.microsoft.com/en-us/previous-versions/bb325654(v=msdn.10)) | `[Environment]::GetFolderPath('Startup')`、`GetFolderPath('CommonStartup')` 后列文件（不要硬编码 `C:\ProgramData`） | ✅ 常规可查 |
| 4 | **任务计划程序（触发器）** | 任务存 `%SystemRoot%\System32\Tasks`，注册表索引 `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree`；"登录/启动/空闲/解锁/事件触发"的任务等价于自启 | 🟢 [Task Triggers](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-triggers)、🟢 [Trigger types](https://learn.microsoft.com/en-us/windows/win32/taskschd/trigger-types) | 见下方"高频机制详解 §4" | ⚠️ 谨慎 |
| 5 | **Winlogon：Shell / Userinit / Notify / Taskman / AutoAdminLogon** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` | 🟢 [Registry Entries（认证，Notify 全表）](https://learn.microsoft.com/en-us/windows/win32/secauthn/registry-entries)、🟢 [自动登录](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon) | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Userinit` | 🔴 只检不改 |
| 6 | **策略 Run 键** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`、`HKCU\...\Policies\Explorer\Run` | 🟡 MITRE T1547.001 | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"` | ⚠️ 先查是谁写的策略 |
| 7 | **启动文件夹被重定向** | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` 的 `Startup` 值 | 🟢 [个人文件夹位置排障](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/change-personal-folder-location-fails)、🟡 MITRE T1547.001 | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Startup` | ⚠️ |
| 8 | **Active Setup** | `HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\<组件>\StubPath` | 🟡 MITRE T1547.014 | `reg query "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components" /s /v StubPath` | ⚠️ 先分辨微软组件 |
| 9 | **AppInit_DLLs / AppCertDlls** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows` 值 `AppInit_DLLs`、`LoadAppInit_DLLs`（WOW6432Node 下另有一份）；`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls` | 🟢 [AppInit DLLs and Secure Boot](https://learn.microsoft.com/en-us/windows/win32/dlls/secure-boot-and-appinit-dlls)（官方明示不推荐；**开启安全启动时 AppInit 被禁用**，非空值常常不生效）、🟡 MITRE T1546.009（AppCertDlls） | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v AppInit_DLLs` | 🔴 只检不改 |
| 10 | **BootExecute / Session Manager** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager` 值 `BootExecute`（另有 `SetupExecute`、`PlatformExecute`） | 🟢 [Inside Native Applications](https://learn.microsoft.com/en-us/sysinternals/resources/inside-native-applications) | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v BootExecute`（默认 `autocheck autochk *`） | 🔴 不要碰 |
| 11 | **IFEO 映像劫持（Debugger）** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<程序名.exe>` 值 `Debugger`（WOW6432Node 下另有一份） | 🟢 [IFEO 原理（微软博客存档）](https://learn.microsoft.com/en-us/archive/blogs/mithuns/image-file-execution-options-ifeo)、🟡 [MITRE T1546.012](https://attack.mitre.org/techniques/T1546/012/) | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s /v Debugger` | 🔴 只检不改 |
| 11b | **SilentProcessExit 监视器** | 同上键下的 `GlobalFlag` + `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\<程序名.exe>` 值 `MonitorProcess` / `ReportingMode` | 🟢 [Registry entries for Silent Process Exit](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/registry-entries-for-silent-process-exit)、🟡 MITRE T1546.012 | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit" /s` | 🔴 只检不改 |
| 12 | **服务（自动 / 自动延迟）** | `HKLM\SYSTEM\CurrentControlSet\Services\<服务>` Start=2 | 🟢 [Services 概述](https://learn.microsoft.com/en-us/windows/win32/services/services)、🟢 [sc config（delayed-auto）](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config) | `Get-CimInstance Win32_Service \| Where-Object StartMode -eq 'Auto'` | ⚠️ 逐项确认 |
| 13 | **内核驱动 / 文件系统过滤驱动** | `HKLM\SYSTEM\CurrentControlSet\Services\<驱动>` Start=0/1/2 | 🟢 Autoruns 官方页（`-a s` 含服务和驱动） | `Get-CimInstance Win32_SystemDriver \| Where-Object StartMode -ne 'Disabled'`；管理员 `fltmc filters` | 🔴 不要动驱动 |
| 14 | **登录脚本（组策略）+ UserInitMprLogonScript** | GPO 用户登录脚本；注册表 `HKCU\Environment\UserInitMprLogonScript` | 🟡 MITRE T1037.001 | `reg query HKCU\Environment /v UserInitMprLogonScript` | ⚠️ 域环境问管理员 |
| 15 | **KnownDLLs** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs` | 🟢 [DLL 搜索顺序](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order) | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs"` | 🔴 不要碰 |
| 16 | **启动应用开关（StartupApproved）+ UWP/MSIX StartupTask** | 任务管理器"启动"页 / 设置 › 应用 › 启动 的开关；Run 与启动文件夹项的启用状态记在 `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run`、`Run32`、`StartupFolder`（HKLM 下也有同名键）；商店应用通过 `windows.startupTask` 扩展声明 | 🟢 [Startup apps](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/startup-apps)、🟢 [StartupTask API](https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask)（用户通过设置启动页/任务管理器控制） | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved" /s`；T10 解码启用状态 | ✅ 常规可查 |
| 17 | **Shell 扩展 / 启动对象** | `ShellServiceObjectDelayLoad`、`ShellIconOverlayIdentifiers`、各类 `shellex\ContextMenuHandlers`（`*`、`AllFilesystemObjects`、`Folder`、`Directory`、`Drive`） | 🔴 Autoruns"Explorer"分类（无微软单页文档） | T16 | ⚠️ |
| 18 | **WMI 事件订阅** | `root\subscription` 的 `__EventFilter` / `CommandLineEventConsumer` / `ActiveScriptEventConsumer` / `__FilterToConsumerBinding` | 🟢 [CommandLineEventConsumer](https://learn.microsoft.com/en-us/windows/win32/wmisdk/commandlineeventconsumer)、🟡 MITRE T1546.003 | 见 §18（需管理员） | 🔴 罕见，改动需专业 |
| 19 | **LSA 提供程序** | `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` 值 `Security Packages`、`Authentication Packages`、`Notification Packages` | 🟡 MITRE T1547.005 / T1547.002 / T1556.002 | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa"` | 🔴 不要碰 |
| 20 | **IE 加载项 / BHO** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{CLSID}` | 🔴 Autoruns"IE add-ons"分类；Win11 上 IE 已退役，价值低 | `reg query "HKLM\...\Browser Helper Objects" /s` | ✅ 通常为空/微软项 |
| 21 | **屏幕保护程序** | `HKCU\Control Panel\Desktop` 值 `SCRNSAVE.EXE` | 🟡 MITRE T1546.002 | `reg query "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE` | ✅ |
| 22 | **文件类型打开命令劫持** | `HKLM\SOFTWARE\Classes\exefile\shell\open\command`（默认应为 `"%1" %*`），`batfile`、`cmdfile`、`htmlfile` 同理 | 🟡 Autoruns"Hijacks"分类 | T24 对比默认值 | 🔴 只检不改 |
| 23 | **Winsock / 网络提供程序** | Winsock LSP/NSP 目录；`HKLM\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order` | 🟡 MITRE T1547.010 相关；Autoruns `n` 类别 | `netsh winsock show catalog` | 🔴 只检不改 |
| 24 | **打印监视器** | `HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors` | 🟡 MITRE T1547.010 | T24 列非默认项 | 🔴 只检不改 |
| 25 | **Win11"自动保存可重启的应用"** | `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon` 值 `RestartApps`；设置 › 账户 › 登录选项 | 🟢 [Stop Microsoft Edge from starting automatically](https://support.microsoft.com/en-us/edge/stop-microsoft-edge-from-starting-automatically) | T24 | ✅ 用设置开关 |
| 26 | **Office 加载项** | `HKCU/HKLM\Software\Microsoft\Office\<应用>\Addins\<名称>` 值 `LoadBehavior` | 🔴 Autoruns GUI 的 Office 页 | `reg query "HKCU\Software\Microsoft\Office\Word\Addins" /s` | ⚠️ 用 Office 自带"加载项"管理 |

> **纠偏**：网上流传的 `Explorer\Run` 独立自启键是**讹传**——真正被系统执行的是 `Policies\Explorer\Run`（#6）。不要让脚本去查 HKCU/HKLM 的 `Explorer\Run`。

---

## 按 Autoruns 类别的检查与关闭矩阵

> 类别字母对应 Sysinternals Autoruns v14.3 的 `autorunsc -a` 参数（[官方页](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns)，2026-06-17 版，2026-11-11 核对）。"可逆关闭"列一律先演练（不加 `-Apply`），确认后再加 `-Apply`；每次改动写入 `changes.json`，`Export-WcoUndo` 生成 `undo.ps1`。模块用法：`Import-Module .\scripts\lib\Wco.Common.psm1`。

| 类别 | 位置（本文 #） | 只读检查 | 可逆关闭（首选） | 不建议 / 只检不改 |
|------|---------------|---------|-----------------|------------------|
| **l** Logon | Run / RunOnce / RunOnceEx / WOW6432Node（#1）、Policies\Explorer\Run（#6）、启动文件夹（#3、#7）、UserInitMprLogonScript（#14） | T10（含 StartupApproved 启用状态）、T24 | Run 和启动文件夹项：`Set-WcoStartupApproved -Name <值名或文件名> -Scope HKCU-Run\|HKLM-Run\|HKLM-Run32\|HKCU-StartupFolder\|HKLM-StartupFolder -Enabled $false`（与任务管理器开关同一机制）；或设置 › 应用 › 启动 | 删除 Run 值只作可选的第二步（先 `reg export`）；Policies\Explorer\Run 先查写入来源（软件/组策略），再决定 |
| **t** 计划任务 | #4 | T10（含 `TaskPath`、动作、触发器类型）、T24（隐藏任务差集） | `Disable-WcoScheduledTask -TaskPath '\路径\' -TaskName '<名称>'` | 删除用 `Remove-WcoScheduledTask`（先导出 XML，拒绝 `\Microsoft\` 下任务），仅在卸载后清残留时 |
| **s** 服务与驱动 | #12、#13 | T12 快照、T18、T24（非微软驱动 + 签名） | 服务：`Set-WcoServiceStartType -Name <服务> -StartType disabled`（记录原启动类型） | 驱动：🔴 不改启动类型；卸载后的残留驱动包见 `software-uninstall.md` 的 pnputil 手动步骤 |
| **e** Explorer 扩展 | #17 | T16 | 用软件自带"右键菜单集成"开关；或卸载软件 | 不手删 CLSID 键 |
| **i** IE 加载项 | #20 | Autoruns | IE 已退役，通常无需处理 | — |
| **w** Winlogon | #5 | T24（对比默认 `explorer.exe` / `userinit.exe,`） | — | 🔴 只检不改，异常交给安全软件 |
| **h** 映像劫持 | #11、#11b、#22 | T24 | — | 🔴 只检不改；发现陌生 Debugger/MonitorProcess 交给安全软件（自己写 Debugger 屏蔽弹窗的风险见 `bloatware-catalog.md` §9） |
| **d** AppInit | #9 | T24 | — | 🔴 只检不改 |
| **k** KnownDLLs | #15 | `reg query` | — | 🔴 不要碰 |
| **b** Boot Execute | #10 | T24（对比 `autocheck autochk *`） | — | 🔴 不要碰 |
| **r** LSA 提供程序 | #19 | T24 | — | 🔴 不要碰 |
| **n** Winsock / 网络提供程序 | #23 | T24（`netsh winsock show catalog` 非微软项） | 🟠 HIGH：`netsh winsock reset`（经用户同意，需重启；会重置所有 LSP） | 不逐条手删 Winsock 目录 |
| **p** 打印监视器 | #24 | T24 | 卸载对应打印/虚拟打印软件 | 不手删 |
| **m** WMI | #18 | T24（四个类都查；查询失败明确报"需管理员，未检查"，不报"干净"） | — | 🔴 删除不可一键还原，见 §18 |
| **o** 编解码器 | — | Autoruns | 卸载对应软件 | — |
| **g** 边栏小工具 | — | — | Win10/11 不适用 | — |
| Office 加载项 | #26 | `reg query` | Office › 文件 › 选项 › 加载项 → 管理 COM 加载项 | — |
| Active Setup | #8 | T24（HKLM 与 HKCU 版本对比） | — | ⚠️ 只检，非微软 StubPath 逐个确认来源 |
| 浏览器策略 / 快捷方式参数 | 见 `bloatware-catalog.md` | T23、T19 | 浏览器设置 / 只删被写入的具体策略值（见 `software-uninstall.md`） | 不整键删除策略 |

---

## 现代 Windows 10/11 的启动来源

| 来源 | 机制 | 怎么关（可逆） | 依据 / 状态 |
|------|------|---------------|-------------|
| **设置 › 应用 › 启动** / 任务管理器"启动"页 | Run、启动文件夹（StartupApproved）+ 商店应用 StartupTask，同一组开关 | 直接在设置里关；脚本用 `Set-WcoStartupApproved`（只覆盖 Run / 启动文件夹，不覆盖 StartupTask 应用） | 🟢 StartupTask 文档 |
| **"自动保存我的可重启应用，并在我重新登录时重启它们"** | Win11 登录时恢复上次打开的应用（`Winlogon\RestartApps`） | 设置 › 账户 › 登录选项 → 关闭该开关 | 🟢 微软 Edge 支持页把它列为"Edge 自己打开"的解决办法 |
| **更新后重启的应用** | 应用调用 `RegisterApplicationRestart`，Windows 更新重启后重新打开 | 同上开关；或在应用内关闭 | 🟢 Win32 API（机制）；与上一行的关系 存疑 |
| **Edge 启动提升 / 后台模式 / 开机打开窗口** | Edge 自身开关 + `MicrosoftEdgeAutoLaunch_*` Run 值 | 见 `startup-audit.md` 浏览器专项 | 🟢 Edge 策略文档 |
| **OneDrive** | HKCU Run 值 `OneDrive` | OneDrive 设置 → 常规 → 取消"登录 Windows 时自动启动"；或设置 › 应用 › 启动 | 社区普遍一致，存疑（未取官方页） |
| **新版 Teams、终端、手机连接（Phone Link）** | 商店/MSIX 应用的 StartupTask | 设置 › 应用 › 启动；或应用内设置 | 存疑：具体机制未在今日官方页核实 |
| **小组件（Widgets）** | 任务栏小组件按钮与后台进程 | 设置 › 个性化 › 任务栏 → 关闭"小组件"；Pro/企业版可用策略 `AllowNewsAndInterests`（见 `services-optimization.md`） | 机制 存疑 |
| **WPBT（固件执行厂商程序）** | 厂商通过 ACPI WPBT 在启动时投放程序，解释"重装系统后厂商助手自己回来" | 只读说明，不默认禁用 | 社区资料，存疑 |

---

## 高频机制详解

### 1. Run / RunOnce（最常见）

- **官方定义**：Run 每次登录执行；RunOnce 执行一次后删除。值名前缀 `!`=成功后才删、`*`=安全模式也执行；HKLM\RunOnce 仅管理员登录后执行。系统可能会延迟 Run 与启动文件夹项的启动。
- **利用者**：几乎所有需要常驻的软件——更新器、云盘、输入法、助手类、流氓全家桶、广告软件。
- **检出**：直接跑 T10（会同时读 StartupApproved，标出"已在任务管理器里禁用"的项）。手动快查：

```powershell
$keys = @(
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
)
foreach ($k in $keys) {
    if (Test-Path -LiteralPath $k) { Write-Host "== $k"; Get-ItemProperty -LiteralPath $k | Format-List }
}
```

### 3. 启动文件夹

- **路径**：用 `[Environment]::GetFolderPath('Startup')` 与 `GetFolderPath('CommonStartup')` 取真实路径（可能被 #7 重定向）。放 `.lnk / .bat / .vbs / .exe` 均可触发。
- **注意**：UAC 会阻止需要提权的程序从这里启动（官方说法）。流氓软件常藏 `.lnk`。
- **关闭**：`Set-WcoStartupApproved -Name '<文件名.lnk>' -Scope HKCU-StartupFolder -Enabled $false`；用户确认不要了再用 `t07-safe-recycle.ps1` 把文件移入回收站。
- **汇总查看**：`Get-CimInstance Win32_StartupCommand` 会把 Run 键与启动文件夹一并列出，适合第一轮快查；它不显示启用/禁用状态（存疑：很可能把已禁用项也列出来），以 T10 为准。

### 4. 任务计划程序（第二常见持久化点）

- 触发器类型（官方）：时间型 + 事件型（系统启动、用户登录、空闲、锁定/解锁、注册时等）。**登录/启动/空闲/解锁触发的任务 = 等价自启**。
- 可用 SYSTEM 身份运行、开机即跑。
- **检出**（`-TaskPath` 必须带上，子文件夹里的任务才能精确定位）：

```powershell
Get-ScheduledTask | Where-Object {
    ($_.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -match 'Logon|Boot|Idle|SessionStateChange|Event|Registration'
} | Select-Object TaskPath, TaskName, State,
    @{n='Trigger';e={($_.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','}},
    @{n='Action';e={($_.Actions | Select-Object -First 1 | ForEach-Object { "$($_.Execute) $($_.Arguments)" })}}
```

- **隐藏任务**：删掉 `TaskCache\Tree\<任务>` 下的 `SD` 值后，任务计划程序和 `schtasks` 都看不到该任务（微软安全博客 [Tarrask](https://www.microsoft.com/en-us/security/blog/2022/04/12/tarrask-malware-uses-scheduled-tasks-for-defense-evasion/)）。T24 用"注册表 Tree 与 `Get-ScheduledTask` 的差集"只读检出，需管理员。
- **关闭**：`Disable-WcoScheduledTask -TaskPath '\' -TaskName 'WpsUpdateTask_xxx'`（演练）→ 加 `-Apply`。根目录 `\` 下的任务常需管理员。

### 16. StartupApproved（"任务管理器里禁用了还是会自启"的关键）

- 任务管理器"启动"页和 设置 › 应用 › 启动 的开关，对 Run / 启动文件夹项**不删除 Run 值**，而是在 `...\Explorer\StartupApproved\Run`（或 `Run32`、`StartupFolder`）下写一个 12 字节的二进制值。
- **字节含义**：首字节 **`02` = 启用**，**`03` = 禁用**（另见 `06` = 启用、`07` = 禁用的变体）；禁用时第 5–12 字节是禁用时间（FILETIME）。**没有对应值 = 按启用处理**。微软没有公开此格式，依据为多个独立来源一致的实测：[H. Carvey 2022](http://windowsir.blogspot.com/2022/07/does-autostart-really-mean-autostart.html)、[Nutanix 2021](https://www.nutanix.com/en_gb/blog/windows-os-optimization-essentials-part-4-startup-items)、Stack Overflow 59847480（2026-11-11 核对）。
- HKCU 的 StartupApproved 是否也能抑制 HKLM Run 项：存疑，未实机验证；HKLM 项用 `-Scope HKLM-Run` / `HKLM-Run32`（需管理员）。
- **可逆关闭**：`Set-WcoStartupApproved -Name <Run 值名> -Scope HKCU-Run -Enabled $false`，它记录原字节（或"原本无值"），undo 恢复。
- **常见误区**：在设置里关了开关，Run 值还在；某些软件运行时会把 Run 值或开关状态写回——这类软件先关它自己的"开机启动"选项（浏览器见 `startup-audit.md`），再关系统开关。

### 18. WMI 事件订阅（无文件持久化）

- **背景**：触发规则（`__EventFilter`）+ 执行动作（`CommandLineEventConsumer` 或 `ActiveScriptEventConsumer`）+ 绑定（`__FilterToConsumerBinding`）写进 WMI 仓库，由系统 WMI 服务拉起，不在 Run 键、启动文件夹留痕迹。激活工具类恶意软件有用 `ActiveScriptEventConsumer` 定时跑 VBS 改快捷方式参数的案例（[火绒报告](https://www.huorong.cn/document/tech/vir_report/783)）。
- **只读检查**（需管理员；**查询失败时不能当作"干净"**）：

```powershell
foreach ($cls in '__EventFilter','CommandLineEventConsumer','ActiveScriptEventConsumer','__FilterToConsumerBinding') {
    try {
        $r = @(Get-CimInstance -Namespace root\subscription -ClassName $cls -ErrorAction Stop)
        Write-Host "== $cls：$($r.Count) 条"
        $r | Format-List Name, Query, CommandLineTemplate, ScriptText, Filter, Consumer
    } catch {
        Write-Host "== $cls：查询失败（通常需要管理员），未检查——不代表没有"
    }
}
```

- 干净系统通常为空，或只有微软/硬件厂商预置项（例如名为 `SCM Event Log Filter` 的系统项）。
- **清除（🔴 CRITICAL，不可一键还原）**：先确认三件套是同一来源、用户同意，并导出留档（`Get-CimInstance ... | Export-Clixml <会话目录>\wmi_<名称>.xml`，仅供人工重建）；再按 绑定 → 消费者 → 过滤器 的顺序用 `Remove-CimInstance` 删除。拿不准时交给安全软件处理。

---

## 普通用户核心审计清单（8 项）

按"性价比"排序，大多数真实自启问题在这 8 项里：

1. **Run / RunOnce 键 + WOW6432Node**（#1）：同时看 StartupApproved 状态（T10）。
2. **两个启动文件夹**（#3）：`.lnk/.bat/.vbs` 逐个辨认，不认识先禁用（StartupApproved），不要直接删。
3. **设置 › 应用 › 启动 / 任务管理器"启动"页**（#16）：官方推荐入口。
4. **登录/开机/空闲/解锁触发的计划任务**（#4）：重点看根目录 `\` 下的非微软任务。
5. **自动/延迟自动服务清单**（#12）：看 PathName 是否位于用户目录、Temp、奇怪盘符。
6. **Winlogon 的 Userinit / Shell / Notify**（#5）：**只读**——Userinit 应为 `userinit.exe`（可带逗号）、Shell 应为 `explorer.exe`；Notify 子键出现陌生 DLL 即高度可疑。
7. **Active Setup 的非微软 StubPath**（#8）：过滤掉 System32 路径后逐个确认。
8. **AppInit_DLLs 是否非空**（#9）：非空先查是什么 DLL、是否带签名；开启安全启动时它通常不生效。

> 铁律：#5、#9、#10、#11、#11b、#13、#15、#18、#19、#22、#23 在普通场景**只检不改**；软件/驱动异常交给安全软件或专业人员，手改注册表可能导致无法开机。

---

## 只检不改的高危机制

- **BootExecute**（#10）：内核启动早期由 smss.exe 执行，默认 `autocheck autochk *`。
- **AppInit_DLLs**（#9）：把 DLL 注入加载 user32 的进程，微软官方明确不推荐；安全启动开启时被禁用。
- **KnownDLLs**（#15）：系统 DLL 解析白名单，篡改即 DLL 劫持。
- **IFEO Debugger / SilentProcessExit**（#11、#11b）：系统自身有很多合法 IFEO 子键（如 MitigationOptions），**只看是否含 `Debugger` 值**，以及 SilentProcessExit 下的 `MonitorProcess`。
- **WMI 事件订阅**（#18）：正常系统应为空或仅系统项。
- **LSA 提供程序**（#19）：加载进 lsass，默认只有系统自带的包（具体列表随 Windows 版本变化，本仓库未逐版核对，存疑），出现陌生 DLL 高度可疑。
- **exefile 等打开命令**（#22）、**Winsock**（#23）：异常时优先用安全软件修复。

---

## 官方工具 Autoruns 使用指南

微软官方工具（Sysinternals），一次列出**全部类别**的自启动项，是审计的捷径。

- **官方页**：https://learn.microsoft.com/zh-cn/sysinternals/downloads/autoruns
- **下载**：https://download.sysinternals.com/files/Autoruns.zip （含 GUI 版 Autoruns64.exe 与命令行版 autorunsc64.exe）
- **运行**：右键"以管理员身份运行"Autoruns64.exe（管理员才能看到所有账户/驱动项）。
- **聚焦第三方**：菜单 Options → **Hide Microsoft Entries**（旧版叫 Hide Signed Microsoft Entries），只剩第三方自启。
- **禁用 vs 删除**：**取消勾选 = 禁用**（Autoruns 把值移到 `AutorunsDisabled` 子键或做等效处理，可勾回）；Delete 才是删除。只取消勾选，不删除。
- **导出 CSV**（默认不联网查毒）：

```cmd
autorunsc64.exe -accepteula -a * -c -h -s -m > Autostart-Report.csv
```

  参数（以官方页为准）：`-a *`=全部类别、`-c`=CSV、`-h`=显示文件哈希、`-s`=验证数字签名、`-m`=隐藏微软项（与 `-v` 同用时隐藏已签名项）。`-accepteula` 用于跳过首次许可弹窗，官方页未列出但广泛使用（存疑）。
- **VirusTotal**：需要用户**单独同意**（会把文件哈希上传到 VirusTotal）。查询要用 `-v`（或 `-vr` / `-vs`）；`-vt` 只表示接受 VirusTotal 条款，单独加 `-vt` 并不查询。同意后：`autorunsc64.exe -accepteula -a * -c -h -s -m -v -vt > report.csv`。导出后用 Excel 过滤"签名验证失败"与 VirusTotal 非零检出的条目。

---

## 相关文档

- 具体软件（Edge / Chrome）的"彻底关闭"、按机制可逆禁用 → `startup-audit.md`
- 服务类自启治理 → `services-optimization.md`
- 流氓软件识别与广告载体 → `bloatware-catalog.md`
- 踩坑记录 → `pitfalls.md`"自启动"一节
