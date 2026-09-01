# Windows 自启动机制全清单（Startup Mechanisms）

<!-- skill-doctor: allow-block SEC002（示例路径为通用占位，无真实用户路径） -->

> 用户说"开机慢""有些软件明明关了还会自启""关不干净"——先读本文。Windows 的"自启动"远不止注册表 Run + 启动文件夹 + 计划任务 + 服务 4 类，常见软件/流氓软件走的启动点有 **20+ 个**。本文依据微软官方文档（Microsoft Learn / Sysinternals）与 MITRE ATT&CK 整理，标清每个机制的检出命令、风险等级与"能不能碰"。
>
> **一句话给普通用户**：先装微软官方工具 **AutoRuns** 一键看全（见文末），比手动逐项查快 10 倍。

---

## 目录

- [自启动机制全清单（表格）](#自启动机制全清单表格)
- [高频机制详解](#高频机制详解)
- [普通用户核心审计清单（8 项）](#普通用户核心审计清单8项)
- [只检不改的高危机制](#只检不改的高危机制)
- [官方工具 AutoRuns 使用指南](#官方工具-autoruns-使用指南)

---

## 自启动机制全清单（表格）

> 路径均为通用占位（`<用户>` 代表当前用户名）。依据分三档：**🟢 微软官方文档**、**🟡 高可信第三方**（MITRE，路径逐条核验）、**🔴 依据较弱**（工具文档/社区，已标注）。

| # | 机制 | 位置路径 | 依据 | 检出命令（简版） | 风险 |
|---|------|---------|------|------------------|------|
| 1 | **Run / RunOnce** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run(Once)`、`HKCU\Software\...\Run(Once)`、64 位系统 32 位程序另见 `HKLM\SOFTWARE\WOW6432Node\...\Run(Once)` | 🟢 [Run and RunOnce Registry Keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)、🟡 [Startup apps (wow64 nodes)](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/startup-apps) | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"` 等 6 个键 | ✅ 常规可查 |
| 2 | **RunServices / RunServicesOnce**（Win9x 遗留） | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices(Once)`、`HKCU\...\RunServices(Once)` | 🟡 MITRE T1547.001（WinNT 系是否执行无现行官方文档） | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices"` | ✅ 检出即可，通常为空 |
| 3 | **用户/系统启动文件夹** | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`（FOLDERID_Startup）、`%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp`（FOLDERID_CommonStartup） | 🟢 [KNOWNFOLDERID](https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid)、🟢 [Developing Applications that Run at Logon](https://learn.microsoft.com/en-us/previous-versions/bb325654(v=msdn.10)) | `Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Force` | ✅ 常规可查 |
| 4 | **任务计划程序（触发器）** | 任务存 `%SystemRoot%\System32\Tasks`；"登录时/启动时/事件触发"的任务等价于自启 | 🟢 [Task Triggers](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-triggers)、🟢 [schtasks](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks) | `Get-ScheduledTask \| Where-Object { $_.Triggers.CimClass.CimClassName -match 'LogonTrigger\|BootTrigger' } \| Select TaskName,State` | ⚠️ 谨慎 |
| 5 | **Winlogon：Shell / Userinit / Notify / AutoAdminLogon** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`（值 Shell、Userinit、子键 Notify） | 🟢 [Registry Entries（认证，Notify 全表）](https://learn.microsoft.com/en-us/windows/win32/secauthn/registry-entries)、🟢 [自动登录](https://learn.microsoft.com/en-us/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon) | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Userinit` | 🔴 只检不改 |
| 6 | **策略 Run 键** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`、`HKCU\...\Policies\Explorer\Run` | 🟡 MITRE T1547.001 | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"` | ⚠️ 先清策略来源 |
| 7 | **启动文件夹被重定向** | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders` 的 `Startup` 值 | 🟢 [个人文件夹位置排障](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/change-personal-folder-location-fails)、🟡 MITRE T1547.001 | `reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Startup` | ⚠️ |
| 8 | **Active Setup** | `HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\<组件>\StubPath` | 🟡 MITRE T1547.014 | `reg query "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components" /s` | ⚠️ 先分辨微软组件 |
| 9 | **AppInit_DLLs** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows` 值 `AppInit_DLLs` 等 | 🟢 [AppInit DLLs and Secure Boot](https://learn.microsoft.com/en-us/windows/win32/dlls/secure-boot-and-appinit-dlls)（官方明示不推荐、恶意软件常用） | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v AppInit_DLLs` | 🔴 只检不改 |
| 10 | **BootExecute / Session Manager** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager` 值 `BootExecute` | 🟢 [Inside Native Applications](https://learn.microsoft.com/en-us/sysinternals/resources/inside-native-applications) | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v BootExecute` | 🔴 不要碰 |
| 11 | **IFEO 映像劫持** | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<程序>` 值 `Debugger` | 🟢 [Registry entries for Silent Process Exit](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/registry-entries-for-silent-process-exit) | `reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s \| findstr /i "Debugger"` | 🔴 只检不改 |
| 12 | **服务（自动 / 自动延迟）** | `HKLM\SYSTEM\CurrentControlSet\Services\<服务>` Start=2 | 🟢 [Services 概述](https://learn.microsoft.com/en-us/windows/win32/services/services)、🟢 [sc config（delayed-auto）](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config) | `Get-CimInstance Win32_Service \| Where-Object StartMode -eq 'Auto'` | ⚠️ 逐项确认 |
| 13 | **内核驱动程序** | `HKLM\SYSTEM\CurrentControlSet\Services\<驱动>` Start=0/1/2 | 🟢 AutoRuns 官方页（autorunsc -s 含驱动） | `Get-CimInstance Win32_SystemDriver \| Where-Object StartMode -eq 'Auto'` | 🔴 不要动驱动 |
| 14 | **登录脚本（组策略）+ UserInitMprLogonScript** | GPO 用户登录脚本；注册表 `HKCU\Environment\UserInitMprLogonScript` | 🟡 MITRE T1037.001 | `reg query HKCU\Environment /v UserInitMprLogonScript` | ⚠️ 域环境问管理员 |
| 15 | **KnownDLLs** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs` | 🟢 [DLL 搜索顺序](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order) | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs"` | 🔴 不要碰 |
| 16 | **UWP/Store 启动应用 + StartupApproved** | 任务管理器"启动"页；禁用状态记在 `HKCU\...\Explorer\StartupApproved\Run、Run32、StartupFolder` | 🟢 [Startup apps](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/startup-apps)、🟢 [StartupTask API](https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask) | `Get-ScheduledTask -Path "\StartupAppTask\*"`；`reg query "HKCU\...\Explorer\StartupApproved" /s` | ✅ 常规可查 |
| 17 | **Shell 启动对象（ShellServiceObjects）** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad` 等 | 🔴 AutoRuns"Explorer add-ons"分类（无微软单页文档） | `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad"` | ⚠️ |
| 18 | **WMI 事件订阅** | WMI 仓库 `root\subscription` 的 `__EventFilter` / `CommandLineEventConsumer` / `__FilterToConsumerBinding` | 🟢 [CommandLineEventConsumer](https://learn.microsoft.com/en-us/windows/win32/wmisdk/commandlineeventconsumer)、🟡 MITRE T1546.003 | `Get-CimInstance -Namespace root\subscription -ClassName __EventFilter` | 🔴 罕见，改动需专业 |
| 19 | **LSA 安全提供程序（SSP）** | `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Security Packages` | 🟡 MITRE T1547.005 | `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "Security Packages"` | 🔴 不要碰 |
| 20 | **IE 加载项 / BHO** | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{CLSID}` | 🔴 AutoRuns"IE add-ons"分类 | `reg query "HKLM\...\Browser Helper Objects" /s` | ✅ 通常为空/微软项 |
| 21 | **屏幕保护程序** | `HKCU\Control Panel\Desktop` 值 `SCRNSAVE.EXE` | 🟡 MITRE T1546.002 | `reg query "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE` | ✅ |

> **重要纠偏（避免带用户进沟）**：网上流传的 `Explorer\Run` 独立自启键是**讹传**——真正被系统执行的是 `Policies\Explorer\Run`（#6）。不要让脚本去查 HKCU/HKLM 的 `Explorer\Run`。

---

## 高频机制详解

### 1. Run / RunOnce（最常见，90% 的开机慢来自这里）

- **官方定义**：Run 每次登录执行；RunOnce 执行一次后删除。值名前缀 `!`=成功后才删、`*`=安全模式也执行；HKLM\RunOnce 仅管理员登录后执行。
- **利用者**：几乎所有需要常驻的软件——更新器、云盘、输入法、助手类、流氓全家桶、广告软件。
- **检出**（6 个键一次列出）：

```powershell
$keys = @(
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
)
foreach ($k in $keys) {
    Write-Host "== $k"
    Get-ItemProperty $k -ErrorAction SilentlyContinue |
        Where-Object { $_ } |
        Format-List
}
```

### 3. 启动文件夹（第二常见）

- **精确路径**：用户 `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`；公共 `%ProgramData%\Microsoft\Windows\Start Menu\Programs\StartUp`。放 `.lnk / .bat / .vbs / .exe` 均可触发。
- **注意**：UAC 会阻止需要提权的程序从这里启动（官方说法）。流氓软件常藏 `.lnk`。
- **汇总查看**：`Get-CimInstance Win32_StartupCommand` 会把 Run 键与启动文件夹一并列出，适合第一轮快查。

### 4. 任务计划程序（恶意软件第二常见持久化点）

- 触发器类型（官方）：时间型 + 事件型（系统启动、用户登录、空闲、锁定等）。**凡触发器是"登录时/启动时"的任务 = 等价自启**。
- 优先级比 Run 高：可 SYSTEM 运行、开机即跑。
- **检出**：

```powershell
Get-ScheduledTask | Where-Object { $_.Triggers.CimClass.CimClassName -match 'LogonTrigger|BootTrigger|EventTrigger' } |
    Select-Object TaskPath, TaskName, State, @{n='Trigger';e={($_.Triggers | ForEach-Object CimClass.CimClassName) -join ','}}
```

### 16. UWP/Store 启动应用 + StartupApproved（"任务管理器里禁用了还是会自启"的关键）

- 任务管理器"启动"页的开关，实际写入 `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run`（字节首值 02=禁用 / 03=启用，社区实测值）。
- **常见误区**：用户在「设置→应用→启动」里关了某开关，但只改了 StartupApproved 标记、**Run 键里的值还在**——某些流氓软件检测到 Run 值被删会自己写回。彻底手法见 `startup-audit.md` 的"先切源头再清 Run 键"。

---

## 普通用户核心审计清单（8 项）

按"性价比"排序，普通用户做完这 8 项覆盖 **95% 以上**的真实自启问题：

1. **Run / RunOnce 六键 + WOW6432Node**（#1）：90% 开机慢来自这里。
2. **两个启动文件夹**（#3）：直接看文件，`.lnk/.bat/.vbs` 逐个辨认，不认识就禁。
3. **任务管理器"启动"页**逐个检查（#16）：右键可禁用，官方推荐入口。
4. **登录/开机触发的计划任务**（#4）：重点看 TaskPath 为 `\`（根目录）的非微软任务。
5. **自动/延迟自动服务清单**（#12）：看 PathName 是否位于用户目录、Temp、奇怪盘符。
6. **Winlogon 的 Userinit / Shell / Notify**（#5）：**只读**——Userinit 必须是 `userinit.exe`（可带逗号追加项）、Shell 必须是 `explorer.exe`；Notify 子键出现陌生 DLL 即高度可疑。
7. **Active Setup 的非微软 StubPath**（#8）：过滤掉 system32 路径后剩下的逐个确认。
8. **AppInit_DLLs 是否非空**（#9）：非空先查是什么 DLL、是否带签名；带签名的驱动类（如 NVIDIA）可保留，无签名可疑。

> 铁律：第 5、9、10、11、13、15、18、19 项在普通场景**只检不改**；软件/驱动异常建议交给杀软或专业人员，手改注册表可能无法开机。

---

## 只检不改的高危机制

- **BootExecute**（#10）：内核启动早期 smss.exe 执行，默认 `autocheck autochk *`，改这里=改系统启动内核路径。
- **AppInit_DLLs**（#9）：把 DLL 注入每个交互式进程，微软官方原话"大量恶意软件使用此机制…不推荐使用"。
- **KnownDLLs**（#15）：系统 DLL 解析白名单，篡改即 DLL 劫持。
- **IFEO Debugger**（#11）：调试器自动附加机制，恶意软件用它劫持登录启动的程序；系统自身有很多合法子键，**只看是否含 `Debugger` 值**。
- **WMI 事件订阅**（#18）：正常系统应为空，非空高度可疑，改动需专业。
- **LSA Security Packages**（#19）：登录加载进 lsass，默认只有 `cdp/kerberos/msv1_0/negoexts/ntlmssp`，出现陌生 DLL 高度可疑。

---

## 官方工具 AutoRuns 使用指南

微软官方工具（Sysinternals），一键列出**全部类别**的自启动项，是审计的捷径。

- **官方页**：https://learn.microsoft.com/zh-cn/sysinternals/downloads/autoruns
- **下载**：https://download.sysinternals.com/files/Autoruns.zip （解压含 GUI 版 Autoruns64.exe 与命令行版 autorunsc64.exe）
- **运行**：右键"以管理员身份运行"Autoruns64.exe（管理员才能看到所有账户/驱动项）。
- **聚焦第三方**：菜单 Options → **Hide Signed Microsoft Entries**（隐藏微软签名项），立刻只剩第三方自启——官方页明确推荐用此功能定位"added to your system"的项。
- **禁用/删除**：**取消勾选即禁用**（可勾回），删除用 Delete 菜单（改注册表/删文件夹）。建议只取消勾选不删除，可回退。
- **导出 CSV**（官方文档化命令）：

```cmd
autorunsc64.exe -a * -m -s -c -vt -h > Autostart-Report.csv
```

  参数含义（官方页逐项）：`-a *`=全部条目、`-m`=隐藏微软项、`-s`=验证数字签名、`-c`=CSV、`-vt`=提交 VirusTotal 查毒（需先同意其条款）、`-h`=显示哈希。导出后用 Excel 过滤"签名验证失败"与"VirusTotal 非零检出"的条目。

---

## 相关文档

- 具体软件（Edge / Chrome）的"彻底关闭"清单 → `startup-audit.md`
- 服务类自启治理 → `services-optimization.md`
- 流氓软件进程识别 → `bloatware-catalog.md`
- 踩坑记录 → `pitfalls.md`（含"只删 Run 键不关浏览器开关会复发"等）
