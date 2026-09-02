# 自启动项审计与禁用（Startup Audit）

<!-- skill-doctor: allow-block SEC002（脚本示例路径用 <用户名> 占位，无真实用户路径） -->

> 用户开机慢、后台进程多、想关掉某些软件的自启——本节覆盖**所有 Windows 自启动机制**的审计与禁用方法。**所有禁用操作都可逆**——HKCU/HKLM Run 项可随时加回，计划任务可重新启用。
>
> **重点更新（v1.2）**：新增 Edge / Chrome 浏览器"彻底关闭"专项（第三节）。这两款浏览器的自启经常"关不干净"——根因是**只删了注册表 Run 键、没关浏览器自己的后台开关，浏览器一运行/更新就把 Run 键写回**。本节给出官方依据和"先切源头再清 Run 键"的正确顺序。

---

## 目录

- [Windows 自启动的 N 个机制](#windows-自启动的-n-个机制)
- [完整审计脚本](#完整审计脚本)
- [浏览器专项：Edge / Chrome 彻底关闭自启动](#浏览器专项edge--chrome-彻底关闭自启动)
- [禁用方法（按机制）](#禁用方法按机制)
- [常见 bloatware 自启项识别](#常见-bloatware-自启项识别)
- [回退与验证](#回退与验证)

---

## Windows 自启动的 N 个机制

Windows 真实的自启动点有 20+ 个（完整清单见 `startup-mechanisms.md`）。审计脚本覆盖**最常用的前三类**，其余做只读提醒：

| 机制 | 路径 | 风险 |
|------|------|------|
| **1. 注册表 Run / RunOnce** | HKCU + HKLM + WOW6432Node 共 6 键（见 `startup-mechanisms.md` #1） | LOW |
| **2. 启动文件夹** | 用户 + 系统（`startup-mechanisms.md` #3） | LOW |
| **3. 计划任务** | 触发器为"登录时/启动时"的任务（`startup-mechanisms.md` #4） | LOW-MEDIUM |
| **4. 服务** | `services.msc`（`startup-mechanisms.md` #12） | 见 `services-optimization.md` |
| **5. 隐藏机制** | Winlogon / Active Setup / AppInit / 策略 Run 等 | 🔴 只读检出，转 `startup-mechanisms.md` |

> 注意：任务管理器「启动」页里"已禁用"的项，实际只是被标记（`StartupApproved\Run`），**Run 键里的值通常还在**。这正是"看起来关了还会自启"和"删了又被某软件写回"的根源之一。

---

## 完整审计脚本

把以下脚本保存为 `.ps1` 文件执行（不要通过 `-Command` 传，避免 `$` 被 bash 吃掉——参考 `pitfalls.md` 陷阱 1/21）：

```powershell
$outFile = "C:\Users\<用户名>\AppData\Local\Temp\startup_audit.txt"
"===== 自启动项全面审计 =====" | Out-File $outFile
"生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $outFile -Append
"" | Out-File $outFile -Append

# === 1. 注册表 Run / RunOnce (HKCU) ===
"===== [1] HKCU 注册表 Run/RunOnce =====" | Out-File $outFile -Append
foreach ($key in @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
                   "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce")) {
    if (Test-Path $key) {
        "--- $key ---" | Out-File $outFile -Append
        Get-ItemProperty $key -EA SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                ForEach-Object { "$($_.Name) = $($_.Value)" | Out-File $outFile -Append }
        }
    }
}
"" | Out-File $outFile -Append

# === 2. 注册表 Run / RunOnce (HKLM + WOW6432Node) ===
"===== [2] HKLM 注册表 Run/RunOnce =====" | Out-File $outFile -Append
foreach ($key in @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
                   "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
                   "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
                   "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce")) {
    if (Test-Path $key) {
        "--- $key ---" | Out-File $outFile -Append
        Get-ItemProperty $key -EA SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                ForEach-Object { "$($_.Name) = $($_.Value)" | Out-File $outFile -Append }
        }
    }
}
"" | Out-File $outFile -Append

# === 3. 启动文件夹 ===
"===== [3] 启动文件夹 =====" | Out-File $outFile -Append
foreach ($sp in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                  "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    if (Test-Path $sp) {
        "--- $sp ---" | Out-File $outFile -Append
        Get-ChildItem $sp -File -EA SilentlyContinue |
            ForEach-Object { "$($_.Name)  ($($_.Length) bytes)" | Out-File $outFile -Append }
    }
}
"" | Out-File $outFile -Append

# === 4. 计划任务（含状态 + 触发器） ===
"===== [4] 计划任务 =====" | Out-File $outFile -Append
$tasks = Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.State -ne 'Disabled' }
foreach ($t in $tasks) {
    $info = $t | Get-ScheduledTaskInfo -EA SilentlyContinue
    $action = ($t.Actions | Select-Object -First 1)
    $triggers = ($t.Triggers | ForEach-Object CimClass.CimClassName) -join ','
    $exe = if ($action.Execute) { Split-Path $action.Execute -Leaf } else { '' }
    "[$(if($triggers -match 'Logon|Boot|Event'){'<登录/开机触发>'}else{$t.State})] $($t.TaskName) | $exe | $triggers" | Out-File $outFile -Append
}

# === 5. StartupApproved（任务管理器的"已禁用"标记） ===
"" | Out-File $outFile -Append
"===== [5] StartupApproved 禁用标记（字典：首字节 03=启用 / 02=禁用）=====" | Out-File $outFile -Append
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" | Out-File $outFile -Append

# === 6. 当前后台进程（按软件族归类） ===
"" | Out-File $outFile -Append
"===== [6] 当前后台进程 =====" | Out-File $outFile -Append
$procs = Get-Process -EA SilentlyContinue | Where-Object { $_.SessionId -ne 0 }
$groups = $procs | Group-Object { $_.ProcessName }
foreach ($g in $groups | Sort-Object Count -Descending | Select-Object -First 30) {
    $firstProc = $g.Group | Select-Object -First 1
    $sz = "{0:N1} MB" -f (($g.Group | Measure-Object WorkingSet -Sum).Sum / 1MB)
    "($($g.Count)x) $($g.Name) - 内存: $sz - 路径: $($firstProc.Path)" | Out-File $outFile -Append
}

Write-Host "审计完成: $outFile"
```

**输出解读**：脚本生成 `C:\Users\<用户名>\AppData\Local\Temp\startup_audit.txt`，按 6 节列出所有自启项。**第 6 节的后台进程列表**与 `bloatware-catalog.md` 的进程名库对照，立即可识别流氓软件。若脚本查完仍觉得"还有东西在跑"，用 `startup-mechanisms.md` 文末的 **AutoRuns** 官方工具查全类别。

---

## 浏览器专项：Edge / Chrome 彻底关闭自启动

**为什么"关了还会自启"**：Edge/Chrome 把自启拆成两层——**开关层**（浏览器内的启动提升/后台运行设置 + 企业策略）和**执行层**（注册表 Run 键 `MicrosoftEdgeAutoLaunch_xxx` / `GoogleChromeAutoLaunch_xxx`）。只删执行层、不动开关层，浏览器一运行/更新就把 Run 键写回（有真实社区实证帖子描述与该现象完全一致）。**正确顺序：先切开关层，再删执行层。**

> ⚠️ **纠偏**：**Chrome 没有「启动提升/Startup Boost」，那是 Edge 的功能。** 中文网上很多文章把两者混为一谈。给 Chrome 做"彻底关闭"时不要去找不存在的"启动提升"开关。

### A. Microsoft Edge 彻底关闭（6 个要点）

| # | 机制 | 位置 / 命令 | 管理员 | 官方依据与中文命名映射 |
|---|------|------------|--------|------------------------|
| 1 | **内置「启动提升」**（根因，须先关） | UI：`edge://settings/system` → 关闭「启动提升」；注册表：`HKCU\Software\Microsoft\Edge\StartupBoostEnabled = 0` | 用户级否；策略级是 | [官方支持页（启动提升）](https://support.microsoft.com/zh-cn/edge/get-help-with-startup-boost)、[策略 StartupBoostEnabled](https://learn.microsoft.com/zh-cn/deployedge/microsoft-edge-policies/startupboostenabled)（注：官方策略中文名为「启用启动增强」，设置 UI 为「启动提升」） |
| 2 | **后台运行扩展和应用**（后台模式） | UI：`edge://settings/system` → 关闭后台运行；注册表：`HKCU\Software\Microsoft\Edge\BackgroundModeEnabled = 0` | 用户级否；策略级是 | [策略 BackgroundModeEnabled](https://learn.microsoft.com/zh-cn/deployedge/microsoft-edge-policies/backgroundmodeenabled)（注：官方策略中文名为「允许后台应用继续运行」，设置 UI 为「在关闭后继续运行后台扩展和应用」） |
| 3 | **执行层 Run 键**（最后清） | `reg query "HKCU\...\Run"` 下删 `MicrosoftEdgeAutoLaunch_<hash>*` | 否 | [实证问题帖（现象与用户反馈一致）](https://superuser.com/questions/1904981/disabling-issue-for-microsoft-edge-at-startup) |
| 4 | **开机后可见启动**（Edge ≥153 新增策略） | `HKLM\SOFTWARE\Policies\Microsoft\Edge\LaunchEdgeOnWindowsStartupEnabled = 0` | 是 | [策略 LaunchEdgeOnWindowsStartupEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/launchedgeonwindowsstartupenabled)（**策略页正文无 Deprecated 标注**——索引页摘要里的 "Deprecated." 是相邻章节标题拼接误报，以正文为准） |
| 5 | **EdgeUpdate 计划任务/服务**（只影响更新，与自启无关，一般不动） | `MicrosoftEdgeUpdateTaskMachineCore/UA`（机器级需管理员）；服务 `edgeupdate`/`edgeupdatem` | 部分 | [EdgeUpdate 更新策略](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies)（这些任务不拉起浏览器窗口） |
| 6 | **Windows 启动应用开关** | `Win+R` → `ms-settings:startupapps` → 关闭 Microsoft Edge | 否 | Windows 内置界面 |

**Edge 彻底关闭命令（PowerShell，按顺序执行）**：

> 口径说明：权威做法是 `edge://settings/system` 开关或 `HKLM\SOFTWARE\Policies\Microsoft\Edge` 策略（两者均有官方文档）。下方 `HKCU\Software\Microsoft\Edge` 用户级键为**社区实测路径，无微软官方文档**（真实用户级存储是浏览器 profile 内的 Preferences 文件，见 Chromium 源码 `background_mode.enabled`），仅作为命令行化开关的兜底，且**优先推荐官方开关/策略**。

```powershell
# 第 1 步：关用户级开关（无需管理员）
New-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "StartupBoostEnabled"   -PropertyType DWord -Value 0 -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Edge" -Name "BackgroundModeEnabled" -PropertyType DWord -Value 0 -Force

# 第 2 步【强烈推荐，防复发】：策略级强制（需管理员，弹 UAC）
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled"   -PropertyType DWord -Value 0 -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -PropertyType DWord -Value 0 -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "LaunchEdgeOnWindowsStartupEnabled" -PropertyType DWord -Value 0 -Force  # Edge 153+ 可选

# 第 3 步：删执行层 Run 键（按前缀批量删，hash 因机器而异）
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-ItemProperty $runKey | Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -like "MicrosoftEdgeAutoLaunch_*" } | ForEach-Object {
        Remove-ItemProperty -Path $runKey -Name $_.Name -Force
        Write-Host "[OK] 已删除 $($_.Name)"
    }
```

> 防复发原理：第 2 步的 `HKLM\SOFTWARE\Policies\Microsoft\Edge` 策略写入后，Edge 设置里的开关会变灰不可改（官方策略页说明"配置后用户不可改"），从源头杜绝浏览器把自己写回启用。

### B. Google Chrome 彻底关闭（4 个要点）

| # | 机制 | 位置 / 命令 | 管理员 | 官方依据 |
|---|------|------------|--------|----------|
| 1 | **后台运行应用**（开关层，根因） | UI：`chrome://settings/system` → 关闭「关闭 Google Chrome 后继续运行后台应用」；注册表删 Run 键 `GoogleChromeAutoLaunch_<hash>` | 否 | [官方策略 BackgroundModeEnabled（登录时启动进程）](https://chromeenterprise.google/policies/#BackgroundModeEnabled)、[Chromium 源码 auto_launch_util.cc](https://raw.githubusercontent.com/chromium/chromium/main/chrome/installer/util/auto_launch_util.cc) |
| 2 | **策略层强制**（防用户/后台改写） | `HKLM\SOFTWARE\Policies\Google\Chrome\BackgroundModeEnabled = 0` 或删该值 | 是 | 官方策略列表同上 |
| 3 | **GoogleUpdate 计划任务**（只影响更新，非自启） | `GoogleUpdateTaskMachineCore/UA`（机器级）、`GoogleUpdateTaskUserS-<SID>Core/UA`（用户级） | 机器级是 | [Google 官方「Manage Chrome updates」](https://support.google.com/chrome/a/answer/6350036)；任务命名源自 Google Update（Omaha）开源组件[设计文档](https://github.com/google/omaha/blob/main/omaha/doc/GoogleUpdateOnAScheduleOverview.html)（Google 帮助页未逐名公开） |
| 4 | **gupdate / gupdatem 服务**（只影响更新） | `sc config gupdate start= disabled`（一般不建议动） | 是 | Google 官方确认 Google Update 组件存在（同上） |

**Chrome 彻底关闭命令**：

```powershell
# 第 1、2 步：切开关层 + 策略层强制（第 2 步需管理员）
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "BackgroundModeEnabled" -Force -ErrorAction SilentlyContinue

# 第 3 步：删执行层 Run 键
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-ItemProperty $runKey | Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -like "GoogleChromeAutoLaunch_*" } | ForEach-Object {
        Remove-ItemProperty -Path $runKey -Name $_.Name -Force
        Write-Host "[OK] 已删除 $($_.Name)"
    }
```

> **GoogleUpdate 任务建议保留**：禁用 Google 自动更新会挡安全补丁，官方不推荐（Google 官方文档有明确警告）。只有当用户确需"零后台"时才动，且要先告知风险。**这些任务不会拉起 chrome.exe 窗口，禁用它们解决不了"开机自启"问题。**

### 验证（重启后，未手动打开浏览器）

```powershell
tasklist | findstr /i "msedge.exe"        # Edge：应无输出（msedgewebview2.exe 出现属正常）
tasklist /fi "imagename eq chrome.exe"    # Chrome：应"无任务在运行"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"   # 两边都无 AutoLaunch_*
```

> 注意：Edge 的 `msedgewebview2.exe` 是网页内容渲染组件（很多应用用它跑界面），**不算** Edge 浏览器自启，看到它不要误判为失败。

---

## 禁用方法（按机制）

### 方法 1：禁用 HKCU/HKLM 注册表 Run 项

**普通权限**（删除 HKCU 项，不需要管理员）：
```powershell
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "<项名>" -Force
```

**管理员权限**（删除 HKLM 项，需提权）：
```powershell
# 先检测
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "需管理员权限，将弹 UAC..."
    Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\path\to\your_script.ps1'
    return
}
Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "<项名>" -Force
```

> 提示：`Remove-ItemProperty` 删除值不会进入回收站。**备份方式**：先 `reg export` 备份整个注册表项。

**批量禁用示例**（来自实战，2026-08-19）：
```powershell
$itemsToDisable = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "QianwenUpdaterTaskUser1.0.0.7" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "MicrosoftEdgeAutoLaunch_73DFD279AF967847B683ABB01AFB8244" }
    # 注释：保留 DeskGo（用户主动选择）和 WallpaperEngine（在用）
)
foreach ($item in $itemsToDisable) {
    if (Test-Path $item.Path) {
        Remove-ItemProperty -Path $item.Path -Name $item.Name -Force -EA Stop
        Write-Host "[OK] 删除: $($item.Path)\$($item.Name)"
    }
}
```

### 方法 2：清空启动文件夹

**用户级启动文件夹**：
```powershell
$userStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
Get-ChildItem $userStartup -File -EA SilentlyContinue | ForEach-Object {
    # 移到回收站（不直接删除）
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
}
```

**系统级启动文件夹**（需管理员）：
```powershell
$sysStartup = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
# 同样走回收站
```

### 方法 3：禁用计划任务

**普通权限**（普通用户的任务可禁用）：
```powershell
Disable-ScheduledTask -TaskName "WpsUpdateLogonTask_20919"
Disable-ScheduledTask -TaskName "WpsUpdateTask_20919"
```

**管理员权限**（系统级任务，需要提权）：
```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\path\to\script.ps1'
    return
}
Disable-ScheduledTask -TaskName "<系统任务名>"
```

**按模式禁用**（一次禁用多个）：
```powershell
$taskPatterns = @(
    "WpsUpdate*",
    "*QianwenUpdater*",
    "*AlibabaProtect*"
)
foreach ($pattern in $taskPatterns) {
    $tasks = Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.TaskName -like $pattern }
    foreach ($t in $tasks) {
        Disable-ScheduledTask -InputObject $t | Out-Null
        Write-Host "[OK] 禁用: $($t.TaskName)"
    }
}
```

> **陷阱提醒**（详见 `pitfalls.md`）：根目录（`\`）下的计划任务禁用通常需要管理员；`schtasks /change` 失败时 stderr 可能被 PowerShell 吞掉，务必用 `Start-Process` 抓真错误。

---

## 常见 bloatware 自启项识别

下表列出常见 bloatware 的自启项模式。**审计脚本输出后，按这些关键词匹配**：

| 软件 | 自启项名 / 模式 | 进程名 |
|------|-----------------|--------|
| **WPS Office** | `WpsUpdateLogonTask_<用户名>`、`WpsUpdateTask_<用户名>` | `ksolaunch.exe`（**会反复重写任务**，三层防护见 `pitfalls.md` 61） |
| **夸克 / 千问浏览器** | `QianwenUpdaterTaskUser<版本>` | `updater.exe` |
| **腾讯桌面整理** | `DeskGo` | `DesktopMgr64.exe`（**保留**——用户主动选择） |
| **Microsoft Edge** | `MicrosoftEdgeAutoLaunch_<hash>`（Run 键） | `msedge.exe`（彻底关闭见上文） |
| **Google Chrome** | `GoogleChromeAutoLaunch_<hash>`（Run 键） | `chrome.exe`（彻底关闭见上文） |
| **Adobe** | `AdobeAAMUpdater-*`、`AdobeARM` | `AcroRd32.exe` 等 |
| **Java** | `SunJavaUpdateSched`、`jusched.exe` | `jucheck.exe` |
| **NVIDIA** | `NvBackend` | `nvbackend.exe` |
| **Steam** | `Steam` | `steam.exe`（**保留**——游戏玩家） |
| **Wallpaper Engine** | `WallpaperEngine` | `wallpaper32.exe`（**保留**——用户主动选择） |

**审计脚本输出后，按下表分四档处理**：

| 档位 | 处理 |
|------|------|
| 🟢 明确无用（如 QianwenUpdater） | 直接禁用 |
| 🟡 用户可能想保留（如 Adobe、Java 更新） | **询问用户** |
| 🟠 用户主动选择保留（如 DeskGo、Wallpaper Engine、Steam） | **不动** |
| 🔴 系统核心（如 Windows Defender、SecurityHealth） | **绝对不动** |

---

## 回退与验证

### 回退注册表 Run 项

```powershell
# 恢复单个值
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "<项名>" -Value "<原值>"
```

**预防**：删除前先备份：
```powershell
$backupFile = "$env:USERPROFILE\run_backup_$(Get-Date -Format 'yyyyMMdd').reg"
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" $backupFile /y
```

### 回退计划任务

```powershell
Enable-ScheduledTask -TaskName "WpsUpdateLogonTask_20919"
```

### 回退浏览器策略（恢复可改）——删除即可回到"未配置"

```powershell
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Force -ErrorAction SilentlyContinue
```

### 验证

```powershell
# 验证注册表 Run 已清理
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Select-Object -Property * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider

# 验证计划任务已禁用
Get-ScheduledTask | Where-Object { $_.State -eq 'Disabled' } | Select-Object TaskName

# 验证浏览器开关层已关（策略生效后开关变灰）
reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled   # Edge
reg query "HKLM\SOFTWARE\Policies\Google\Chrome" /v BackgroundModeEnabled  # Chrome
```

### 最终汇报示例

```
=== 自启动清理报告 ===

✅ 已禁用（5 项）
  - WpsUpdateLogonTask_20919（计划任务）
  - WpsUpdateTask_20919（计划任务）
  - QianwenUpdaterTaskUser1.0.0.7（HKCU Run + 计划任务）
  - Microsoft Edge（启动提升 + 后台模式 + AutoLaunch Run 键，策略级强制）
  - （其他）

🟡 已保留（按用户要求）
  - DeskGo（腾讯桌面整理）
  - WallpaperEngine（动态壁纸）
  - Google 自动更新任务（保留，挡安全补丁有风险）

🔄 回退方法
  - 恢复注册表项：编辑备份文件 run_backup_YYYYMMDD.reg 双击导入
  - 启用计划任务：Enable-ScheduledTask -TaskName <名称>
  - 恢复浏览器策略：删除 HKLM\SOFTWARE\Policies\Microsoft\Edge 下对应值即可
```

---

## 相关文档

- 其他 20+ 启动机制（Winlogon / Active Setup / AppInit 等）与 AutoRuns 工具 → `startup-mechanisms.md`
- 服务类自启治理 → `services-optimization.md`
- 流氓软件识别 → `bloatware-catalog.md`
- 自启反复复活的坑（WPS 三层防护、浏览器写回 Run 键）→ `pitfalls.md`
