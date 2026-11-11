# 自启动项审计与禁用（Startup Audit）

> 用户开机慢、后台进程多、想关掉某些软件的自启——本节给出审计方法和**可逆的**禁用方法。默认做法是"关开关、不删东西"：Run 和启动文件夹项改 StartupApproved 状态（和任务管理器、设置 › 应用 › 启动 是同一个开关），计划任务改为禁用，服务改启动类型。每一步先演练、确认后加 `-Apply` 执行，改动记入 `changes.json`，可用 `undo.ps1` 回退。删除 Run 值、删除任务只作为用户确认后的可选第二步。
>
> 浏览器（Edge / Chrome）的自启经常"关不干净"——根因是只删了 Run 值、没关浏览器自己的后台开关，浏览器一运行就把它写回。第三节给出官方依据和"先切开关层，再处理执行层"的顺序。

---

## 目录

- [自启动机制概览](#自启动机制概览)
- [审计：用哪些模板](#审计用哪些模板)
- [现代 Windows 的启动来源](#现代-windows-的启动来源)
- [浏览器专项：Edge / Chrome 彻底关闭自启动](#浏览器专项edge--chrome-彻底关闭自启动)
- [禁用方法（按机制）](#禁用方法按机制)
- [常见 bloatware 自启项识别](#常见-bloatware-自启项识别)
- [回退与验证](#回退与验证)

---

## 自启动机制概览

Windows 真实的自启动点有 20 多个（完整清单与按 Autoruns 类别的检查/关闭矩阵见 `startup-mechanisms.md`）。日常处理集中在前四类，其余只读检出：

| 机制 | 路径 | 可逆关闭 | 风险 |
|------|------|---------|------|
| **1. 注册表 Run / RunOnce / RunOnceEx** | HKCU + HKLM + WOW6432Node（`startup-mechanisms.md` #1） | `Set-WcoStartupApproved` | LOW |
| **2. 启动文件夹** | 用户 + 公共（#3） | `Set-WcoStartupApproved -Scope *-StartupFolder` | LOW |
| **3. 计划任务** | 登录/启动/空闲/解锁触发的任务（#4） | `Disable-WcoScheduledTask` | LOW-MEDIUM |
| **4. 服务** | `services.msc`（#12） | `Set-WcoServiceStartType`，见 `services-optimization.md` | MEDIUM |
| **5. 商店应用 StartupTask** | 设置 › 应用 › 启动（#16） | 在设置里关 | LOW |
| **6. 隐藏机制** | Winlogon / Active Setup / AppInit / 策略 Run / IFEO / WMI 等 | 🔴 只读检出，转 `startup-mechanisms.md` | — |

> **StartupApproved**：任务管理器"启动"页里"已禁用"的项，只是在 `...\Explorer\StartupApproved\Run`（或 `Run32`、`StartupFolder`）里写了状态，**Run 值本身还在**。首字节 **`02` = 启用，`03` = 禁用**（`06`/`07` 为同义变体），禁用时后 8 字节记录禁用时间；没有对应值按启用处理。微软未公开该格式，依据见 `startup-mechanisms.md` §16。审计时要读这个状态，否则会把用户已经关掉的项再报一遍。

---

## 审计：用哪些模板

全部是只读模板，不改系统：

| 模板 | 看什么 |
|------|-------|
| `scripts/templates/t10-audit-startup.ps1`（T10） | Run / RunOnce / WOW6432Node、启动文件夹，**连同 StartupApproved 启用状态和禁用时间**；计划任务（`TaskPath\TaskName`、首个动作、触发器类型、按最近运行时间排序） |
| `scripts/templates/t24-audit-autostart-extended.ps1`（T24） | RunOnceEx、Policies\Explorer\Run、Winlogon、IFEO Debugger、SilentProcessExit、AppInit、exefile 等打开命令、Active Setup、BootExecute、LSA、打印监视器、Winsock、隐藏计划任务、WMI 四类订阅、非微软驱动、`RestartApps`、Edge 启动相关策略、商店应用 StartupTask（尽力而为） |
| `scripts/templates/t23-audit-browser-hijack.ps1`（T23） | 浏览器策略（主页、启动页、搜索、强制扩展）、Native Messaging、代理/PAC、hosts、DNS、近期新增的根证书 |
| `scripts/templates/t19-audit-wmi-lnk-hijack.ps1`（T19） | 快捷方式参数劫持、WMI 消费者 |
| `scripts/templates/t11-detect-bloatware-process.ps1` / `t25-inventory-programs.ps1`（T11/T25） | 对照 `data/bloatware-catalog.json` 识别流氓软件 |

运行方式：保存/调用 `.ps1` 文件执行（`powershell -NoProfile -ExecutionPolicy Bypass -File <模板>`），不要把含 `$` 的脚本塞进 `-Command` 字符串。T24 的大部分检查需要管理员；没有管理员时，相关段落会写"需管理员，未检查"，**不能当作"没有问题"**。

**没有模板时的最小只读快查**（解码 StartupApproved 状态）：

```powershell
$pairs = @(
  @{ Run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
  @{ Run='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
  @{ Run='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
)
$skip = 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider'
foreach ($p in $pairs) {
    if (-not (Test-Path -LiteralPath $p.Run)) { continue }
    $ap = Get-ItemProperty -LiteralPath $p.Approved -ErrorAction SilentlyContinue
    (Get-ItemProperty -LiteralPath $p.Run).PSObject.Properties | Where-Object { $_.Name -notin $skip } | ForEach-Object {
        $b = if ($ap) { $ap.($_.Name) } else { $null }
        $state = if ($null -eq $b) { '启用(无标记)' } elseif (($b[0] -band 1) -eq 1) { '已禁用' } else { '启用' }
        '{0} | {1} | {2} | {3}' -f $state, $p.Run, $_.Name, $_.Value
    }
}
```

> 判断规则：首字节为奇数（`03`/`07`）= 禁用，偶数（`02`/`06`）= 启用。

若查完仍觉得"还有东西在跑"，用 `startup-mechanisms.md` 文末的 **Autoruns** 查全类别。

---

## 现代 Windows 的启动来源

| 现象 | 来源 | 处理 |
|------|------|------|
| 开机后上次开着的应用（含 Edge）自己打开 | 设置 › 账户 › 登录选项 →"自动保存我的可重启应用，并在我重新登录时重启它们" | 关闭该开关（微软 Edge 支持页列出的方法：[Stop Microsoft Edge from starting automatically](https://support.microsoft.com/en-us/edge/stop-microsoft-edge-from-starting-automatically)） |
| 设置里能看到但 Run 键里没有 | 商店/MSIX 应用的 StartupTask（新版 Teams、终端、手机连接等，具体机制 存疑） | 设置 › 应用 › 启动 关闭，或应用内设置 |
| OneDrive 开机启动 | HKCU Run 值 `OneDrive`（存疑，未取官方页） | OneDrive 设置 → 取消"登录 Windows 时自动启动" |
| 小组件进程常驻 | 任务栏小组件（机制 存疑） | 设置 › 个性化 › 任务栏 → 关闭"小组件" |
| Edge 后台常驻 / 开机弹窗 | Edge 启动提升、后台模式、`LaunchEdgeOnWindowsStartupEnabled` | 下一节 |
| 重装系统后厂商助手又回来 | 厂商驱动包附带应用、WPBT（存疑） | 解释原因，按需卸载；不默认改固件相关设置 |

---

## 浏览器专项：Edge / Chrome 彻底关闭自启动

**为什么"关了还会自启"**：Edge/Chrome 把自启拆成两层——**开关层**（浏览器内的启动提升/后台运行设置 + 企业策略）和**执行层**（注册表 Run 值 `MicrosoftEdgeAutoLaunch_xxx` / `GoogleChromeAutoLaunch_xxx`）。只删执行层、不动开关层，浏览器一运行/更新就把 Run 值写回（社区实证帖描述的现象与此一致）。**正确顺序：先切开关层，再处理执行层。**

> ⚠️ **纠偏**：**Chrome 没有「启动提升/Startup Boost」，那是 Edge 的功能。** 给 Chrome 做"彻底关闭"时不要去找不存在的开关。

### A. Microsoft Edge（6 个要点）

| # | 机制 | 位置 / 命令 | 管理员 | 官方依据与中文命名映射 |
|---|------|------------|--------|------------------------|
| 1 | **内置「启动提升」**（根因，须先关） | UI：`edge://settings/system` → 关闭「启动提升」；策略 `StartupBoostEnabled = 0` | 用户级否；策略级是 | [官方支持页（启动提升）](https://support.microsoft.com/zh-cn/edge/get-help-with-startup-boost)、[策略 StartupBoostEnabled](https://learn.microsoft.com/zh-cn/deployedge/microsoft-edge-policies/startupboostenabled)（策略中文名「启用启动增强」，设置 UI 为「启动提升」） |
| 2 | **后台运行扩展和应用**（后台模式） | UI：`edge://settings/system` → 关闭后台运行；策略 `BackgroundModeEnabled = 0` | 用户级否；策略级是 | [策略 BackgroundModeEnabled](https://learn.microsoft.com/zh-cn/deployedge/microsoft-edge-policies/backgroundmodeenabled)（策略中文名「允许后台应用继续运行」） |
| 3 | **执行层 Run 值**（最后处理） | `HKCU\...\Run` 下的 `MicrosoftEdgeAutoLaunch_<hash>` | 否 | [实证问题帖](https://superuser.com/questions/1904981/disabling-issue-for-microsoft-edge-at-startup) |
| 4 | **开机后打开窗口**（Edge ≥153 策略） | `HKLM\SOFTWARE\Policies\Microsoft\Edge\LaunchEdgeOnWindowsStartupEnabled = 0` | 是 | [策略 LaunchEdgeOnWindowsStartupEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/launchedgeonwindowsstartupenabled)（策略页正文无 Deprecated 标注，以正文为准） |
| 5 | **EdgeUpdate 计划任务/服务**（只影响更新，与自启无关，一般不动） | `MicrosoftEdgeUpdateTaskMachineCore/UA`；服务 `edgeupdate`/`edgeupdatem` | 部分 | [EdgeUpdate 更新策略](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies) |
| 6 | **Windows 启动应用开关 / 可重启应用** | `ms-settings:startupapps` → 关闭 Microsoft Edge；设置 › 账户 › 登录选项 → 关闭"自动保存我的可重启应用" | 否 | Windows 内置界面；[Edge 支持页](https://support.microsoft.com/en-us/edge/stop-microsoft-edge-from-starting-automatically) |

**Edge 关闭命令（PowerShell，按顺序；先演练，确认后加 `-Apply`）**：

> 口径：权威做法是 `edge://settings/system` 开关或 `HKLM\SOFTWARE\Policies\Microsoft\Edge` 策略（均有官方文档）。`HKCU\Software\Microsoft\Edge` 下的同名值是社区实测路径、无微软文档（真实用户设置在浏览器 profile 的 Preferences 文件里），只在用户不方便点界面时作兜底。

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1

# 第 1 步：浏览器内关闭「启动提升」「后台运行」（首选，无需管理员）。
#         命令行兜底（社区路径）：
Set-WcoRegistryValue -Key 'HKCU\Software\Microsoft\Edge' -Name StartupBoostEnabled   -Value 0 -Type DWord
Set-WcoRegistryValue -Key 'HKCU\Software\Microsoft\Edge' -Name BackgroundModeEnabled -Value 0 -Type DWord

# 第 2 步【推荐，防复发】：策略级强制（需管理员）。写入后 Edge 设置里的开关变灰，用户和浏览器都改不回去。
Set-WcoRegistryValue -Key 'HKLM\SOFTWARE\Policies\Microsoft\Edge' -Name StartupBoostEnabled   -Value 0 -Type DWord
Set-WcoRegistryValue -Key 'HKLM\SOFTWARE\Policies\Microsoft\Edge' -Name BackgroundModeEnabled -Value 0 -Type DWord
Set-WcoRegistryValue -Key 'HKLM\SOFTWARE\Policies\Microsoft\Edge' -Name LaunchEdgeOnWindowsStartupEnabled -Value 0 -Type DWord  # Edge 153+ 可选

# 第 3 步：执行层——把 AutoLaunch 项标记为禁用（与任务管理器开关相同，可回退）
$run = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$run.PSObject.Properties.Name | Where-Object { $_ -like 'MicrosoftEdgeAutoLaunch_*' } | ForEach-Object {
    Set-WcoStartupApproved -Name $_ -Scope HKCU-Run -Enabled $false
}
# 看完演练输出、用户确认后，把上面每行加 -Apply 再跑一遍，最后：
Export-WcoUndo
```

> 想连 Run 值也删掉：只在第 1、2 步完成、重启验证不再写回后，作为可选步骤，先 `reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" <会话目录>\run.reg` 再删。

### B. Google Chrome（4 个要点）

| # | 机制 | 位置 / 命令 | 管理员 | 官方依据 |
|---|------|------------|--------|----------|
| 1 | **后台运行应用**（开关层，根因） | UI：`chrome://settings/system` → 关闭「关闭 Google Chrome 后继续运行后台应用」 | 否 | [官方策略 BackgroundModeEnabled](https://chromeenterprise.google/policies/#BackgroundModeEnabled)、[Chromium 源码 auto_launch_util.cc](https://raw.githubusercontent.com/chromium/chromium/main/chrome/installer/util/auto_launch_util.cc) |
| 2 | **策略层强制**（防写回） | `HKLM\SOFTWARE\Policies\Google\Chrome\BackgroundModeEnabled = 0`（设为 0 才是强制关闭；删除该值 = 恢复由用户控制） | 是 | 同上 |
| 3 | **GoogleUpdate 计划任务**（只影响更新，非自启） | `GoogleUpdateTaskMachineCore/UA`、`GoogleUpdateTaskUserS-<SID>Core/UA` | 机器级是 | [Manage Chrome updates](https://support.google.com/chrome/a/answer/6350036)；任务命名见 [Omaha 设计文档](https://github.com/google/omaha/blob/main/omaha/doc/GoogleUpdateOnAScheduleOverview.html) |
| 4 | **gupdate / gupdatem 服务**（只影响更新） | 一般不建议动 | 是 | 同上 |

**Chrome 关闭命令（先演练，确认后加 `-Apply`）**：

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1
# 第 1 步：浏览器内关闭后台运行（UI）
# 第 2 步：策略强制关闭（需管理员）。undo 会删除该值，恢复为"未配置"
Set-WcoRegistryValue -Key 'HKLM\SOFTWARE\Policies\Google\Chrome' -Name BackgroundModeEnabled -Value 0 -Type DWord
# 第 3 步：执行层标记为禁用
$run = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$run.PSObject.Properties.Name | Where-Object { $_ -like 'GoogleChromeAutoLaunch_*' } | ForEach-Object {
    Set-WcoStartupApproved -Name $_ -Scope HKCU-Run -Enabled $false
}
```

> **GoogleUpdate / EdgeUpdate 任务建议保留**：禁用自动更新会挡安全补丁。这些任务不会拉起浏览器窗口，禁用它们解决不了"开机自启"。

### 验证（重启后，未手动打开浏览器）

```powershell
tasklist | findstr /i "msedge.exe"        # Edge：应无输出（msedgewebview2.exe 出现属正常）
tasklist /fi "imagename eq chrome.exe"    # Chrome：应"无任务在运行"
.\scripts\templates\t10-audit-startup.ps1 # AutoLaunch_* 显示为"已禁用"或已不存在
```

> Edge 的 `msedgewebview2.exe` 是网页渲染组件（很多应用用它跑界面），**不算** Edge 自启。

---

## 禁用方法（按机制）

所有命令先 `Import-Module .\scripts\lib\Wco.Common.psm1`；不带 `-Apply` 只打印计划，带 `-Apply` 才执行；结束后 `Export-WcoUndo` 生成回退脚本。HKLM、服务、根目录任务需要管理员，模块在非管理员下会直接拒绝并说明原因——这时把同样的命令放进管理员 PowerShell 再跑。

### 方法 1：Run 项（HKCU / HKLM / WOW6432Node）

```powershell
Set-WcoStartupApproved -Name 'QianwenUpdaterTaskUser1.0.0.7' -Scope HKCU-Run -Enabled $false          # 演练
Set-WcoStartupApproved -Name 'QianwenUpdaterTaskUser1.0.0.7' -Scope HKCU-Run -Enabled $false -Apply   # 执行
# HKLM\...\Run 用 -Scope HKLM-Run；HKLM\SOFTWARE\WOW6432Node\...\Run 用 -Scope HKLM-Run32（需管理员）
```

- 效果与任务管理器"禁用"相同，Run 值保留，随时可在设置里重新打开。
- 用户明确要"删掉"时：先确认软件不会再写回（关掉它自己的开机启动选项），再 `reg export` 整个 Run 键后删除该值。删除不是默认动作。
- RunOnce / RunOnceEx 只执行一次，通常无需禁用；出现可疑项交给 `startup-mechanisms.md` 的只读流程判断来源。

### 方法 2：启动文件夹

```powershell
# 值名就是文件名
Set-WcoStartupApproved -Name 'SomeTool.lnk' -Scope HKCU-StartupFolder -Enabled $false          # 用户启动文件夹
Set-WcoStartupApproved -Name 'SomeTool.lnk' -Scope HKLM-StartupFolder -Enabled $false          # 公共启动文件夹（管理员）
```

用户确认不再需要这个快捷方式时，再走回收站（可恢复、先演练）：

```powershell
$f = Join-Path ([Environment]::GetFolderPath('Startup')) 'SomeTool.lnk'
.\scripts\templates\t07-safe-recycle.ps1 -Path $f -Label '启动项快捷方式'          # 演练
.\scripts\templates\t07-safe-recycle.ps1 -Path $f -Label '启动项快捷方式' -Apply   # 执行
```

### 方法 3：计划任务

```powershell
# 先查出完整路径：任务可能在子文件夹里，不带 -TaskPath 只会匹配根目录 "\"
Get-ScheduledTask | Where-Object { $_.TaskName -like 'WpsUpdate*' } | Select-Object TaskPath, TaskName, State

Disable-WcoScheduledTask -TaskPath '\' -TaskName 'WpsUpdateLogonTask_20919'          # 演练
Disable-WcoScheduledTask -TaskPath '\' -TaskName 'WpsUpdateLogonTask_20919' -Apply   # 执行（根目录任务常需管理员）
```

**按模式批量**（逐个列出、确认后再执行）：

```powershell
$patterns = 'WpsUpdate*', '*QianwenUpdater*', '*AlibabaProtect*'
$hits = Get-ScheduledTask | Where-Object { $t = $_; $patterns | Where-Object { $t.TaskName -like $_ } }
$hits | Select-Object TaskPath, TaskName, State          # 先给用户看
foreach ($t in $hits) { Disable-WcoScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName }   # 演练；确认后加 -Apply
```

> 删除任务（`Remove-WcoScheduledTask`，先导出 XML、拒绝 `\Microsoft\` 下的任务）只用于卸载后的残留清理，见 `software-uninstall.md`。

### 方法 4：服务

见 `services-optimization.md`：`Set-WcoServiceStartType -Name <服务> -StartType disabled`（记录原启动类型，含"自动(延迟启动)"）。

---

## 常见 bloatware 自启项识别

识别以 T11/T25 对照 `data/bloatware-catalog.json` 的结果为准；下表是常见名字的速查：

| 软件 | 自启项名 / 模式 | 进程名 |
|------|-----------------|--------|
| **WPS Office** | 任务 `WpsUpdateLogonTask_<用户名>`、`WpsUpdateTask_<用户名>`、`WpsWakeWnsLogonTask` | `ksolaunch.exe`（**会反复重写任务**，三层修复见 `software-uninstall.md` WPS 专项） |
| **夸克 / 千问** | `QianwenUpdaterTaskUser<版本>` | `updater.exe` |
| **腾讯桌面整理** | `DeskGo` | `DesktopMgr64.exe`（用户主动选择的，**保留**） |
| **Microsoft Edge** | `MicrosoftEdgeAutoLaunch_<hash>`（Run） | `msedge.exe`（见上文） |
| **Google Chrome** | `GoogleChromeAutoLaunch_<hash>`（Run） | `chrome.exe`（见上文） |
| **Adobe** | `AdobeAAMUpdater-*`、`AdobeARM` | `AcroRd32.exe` 等 |
| **Java** | `SunJavaUpdateSched`、`jusched.exe` | `jucheck.exe` |
| **NVIDIA** | `NvBackend` | `nvbackend.exe` |
| **Steam** | `Steam` | `steam.exe`（游戏玩家，**保留**） |
| **Wallpaper Engine** | `WallpaperEngine` | `wallpaper32.exe`（用户主动选择，**保留**） |

**分四档处理**：

| 档位 | 处理 |
|------|------|
| 🟢 明确无用（如 QianwenUpdater） | 列给用户后可逆禁用 |
| 🟡 用户可能想保留（如 Adobe、Java 更新） | **询问用户** |
| 🟠 用户主动选择保留（如 DeskGo、Wallpaper Engine、Steam） | **不动** |
| 🔴 系统核心（如 Windows 安全中心 `SecurityHealth`） | **绝对不动** |

---

## 回退与验证

### 回退

- **本次会话的全部改动**：运行会话目录（`%TEMP%\wco\session_<时间>\`）里的 `undo.ps1`，按相反顺序恢复（StartupApproved 恢复原字节或删除新加的值，任务重新启用，策略值删除或恢复，服务恢复原启动类型）。
- **单项手动**：在 设置 › 应用 › 启动 里重新打开开关；`Enable-ScheduledTask -TaskPath '\' -TaskName '<名称>'`。
- **浏览器策略**：删除 `HKLM\SOFTWARE\Policies\Microsoft\Edge`（或 `...\Google\Chrome`）下**对应的那个值**即回到"未配置"，不要删整个策略键（里面可能有单位/用户自己的策略）。

### 验证

```powershell
.\scripts\templates\t10-audit-startup.ps1      # 目标项显示"已禁用"；任务状态为 Disabled
reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled    # Edge 策略
reg query "HKLM\SOFTWARE\Policies\Google\Chrome" /v BackgroundModeEnabled   # Chrome 策略
```

重启（建议完整重启而非关机再开，后者在开启快速启动时不是完整启动）后再看一次，确认没有被写回。

### 最终汇报示例

```
=== 自启动清理报告 ===

✅ 已禁用（可回退）
  - WpsUpdateLogonTask_20919、WpsUpdateTask_20919（计划任务，已禁用）
  - QianwenUpdaterTaskUser1.0.0.7（Run 项，已在启动开关中关闭）
  - Microsoft Edge（启动提升 + 后台模式策略 = 0；AutoLaunch 启动开关已关）

🟡 已保留（按用户要求）
  - DeskGo（腾讯桌面整理）、WallpaperEngine
  - Google 自动更新任务（保留，关掉会挡安全补丁）

🔄 回退方法
  - 运行 %TEMP%\wco\session_<时间>\undo.ps1
  - 或在 设置 › 应用 › 启动 里把对应开关打开
```

---

## 相关文档

- 全部启动机制、Autoruns 类别矩阵、WMI/IFEO 只读检查 → `startup-mechanisms.md`
- 服务类自启治理 → `services-optimization.md`
- 流氓软件识别与广告载体 → `bloatware-catalog.md`
- 自启反复复活的坑 → `pitfalls.md`"自启动"一节
