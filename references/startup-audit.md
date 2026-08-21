# 自启动项审计与禁用（Startup Audit）

<!-- skill-doctor: allow-block SEC002（脚本示例路径用 <用户名> 占位，无真实用户路径） -->

> 用户开机慢、后台进程多、想关掉某些软件的自启——本节覆盖**所有 Windows 自启动机制**的审计与禁用方法。**所有禁用操作都可逆**——HKCU/HKLM Run 项可随时加回，计划任务可重新启用。

---

## 目录

- [Windows 自启动的 4 个机制](#windows-自启动的-4-个机制)
- [完整审计脚本](#完整审计脚本)
- [禁用方法（按机制）](#禁用方法按机制)
- [常见 bloatware 自启项识别](#常见-bloatware-自启项识别)
- [回退与验证](#回退与验证)

---

## Windows 自启动的 4 个机制

| 机制 | 路径 | 风险 |
|------|------|------|
| **1. 注册表 Run / RunOnce** | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`（用户级）<br>`HKLM\Software\Microsoft\Windows\CurrentVersion\Run`（系统级，需管理员） | LOW |
| **2. 启动文件夹** | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`（用户级）<br>`C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup`（系统级） | LOW |
| **3. 计划任务** | `schtasks` 管理的所有任务（数百个） | LOW-MEDIUM（看具体任务） |
| **4. 服务** | `services.msc` 显示的所有 Windows 服务 | 见 `services-optimization.md` |

> **服务**虽然也算"开机自启"，但风险更高（涉及系统组件），单独在 `services-optimization.md` 处理。本节只覆盖前 3 个机制。

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

# === 2. 注册表 Run / RunOnce (HKLM) ===
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

# === 4. 计划任务（含状态） ===
"===== [4] 计划任务 =====" | Out-File $outFile -Append
$tasks = Get-ScheduledTask -EA SilentlyContinue | Where-Object { $_.State -ne 'Disabled' }
$tasks | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -EA SilentlyContinue
    $action = ($_.Actions | Select-Object -First 1)
    $trigger = ($_.Triggers | Select-Object -First 1)
    $exe = if ($action.Execute) { Split-Path $action.Execute -Leaf } else { '' }
    "[$(if($_.State -eq 'Ready'){'启用'}else{$_.State})] $($_.TaskName) | $exe | 上次运行: $(if($info.LastRunTime){$info.LastRunTime.ToString('MM-dd HH:mm')}else{'从未'})" | Out-File $outFile -Append
}

# === 5. 当前后台进程（按软件族归类，辅助识别可疑软件）===
"" | Out-File $outFile -Append
"===== [5] 当前后台进程 =====" | Out-File $outFile -Append
$procs = Get-Process -EA SilentlyContinue | Where-Object { $_.SessionId -ne 0 }
$groups = $procs | Group-Object { $_.ProcessName }
foreach ($g in $groups | Sort-Object Count -Descending | Select-Object -First 30) {
    $firstProc = $g.Group | Select-Object -First 1
    $sz = "{0:N1} MB" -f (($g.Group | Measure-Object WorkingSet -Sum).Sum / 1MB)
    "($($g.Count)x) $($g.Name) - 内存: $sz - 路径: $($firstProc.Path)" | Out-File $outFile -Append
}

Write-Host "审计完成: $outFile"
```

**输出解读**：脚本生成 `C:\Users\<用户名>\AppData\Local\Temp\startup_audit.txt`，按 5 节列出所有自启项。**第 5 节的后台进程列表**与 `bloatware-catalog.md` 的进程名库对照，立即可识别流氓软件。

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

> 提示：`Remove-ItemProperty` 删除值不会进入回收站。**备份方式**：先 `Export-Item` 或用 `reg export` 备份整个注册表项。

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

---

## 常见 bloatware 自启项识别

下表列出常见 bloatware 的自启项模式。**审计脚本输出后，按这些关键词匹配**：

| 软件 | 自启项名 / 模式 | 进程名 |
|------|-----------------|--------|
| **WPS Office** | `WpsUpdateLogonTask_<用户名>`、`WpsUpdateTask_<用户名>` | `ksolaunch.exe` |
| **夸克 / 千问浏览器** | `QianwenUpdaterTaskUser<版本>` | `updater.exe` |
| **腾讯桌面整理** | `DeskGo` | `DesktopMgr64.exe`（**保留**——用户主动选择） |
| **Microsoft Edge** | `MicrosoftEdgeAutoLaunch_<hash>` | `msedge.exe` |
| **Adobe** | `AdobeAAMUpdater-*`、`AdobeARM` | `AcroRd32.exe` 等 |
| **Java** | `SunJavaUpdateSched`、`jusched.exe` | `jucheck.exe` |
| **NVIDIA** | `NvBackend` | `nvbackend.exe` |
| **Steam** | `Steam` | `steam.exe`（**保留**——游戏玩家） |
| **Wallpaper Engine** | `WallpaperEngine` | `wallpaper32.exe`（**保留**——用户主动选择） |

**审计脚本输出后，按下表分四档处理**：

| 档位 | 处理 |
|------|------|
| 🟢 明确无用（如 QianwenUpdater、Edge 后台） | 直接禁用 |
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

### 验证

```powershell
# 验证注册表 Run 已清理
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" |
    Select-Object -Property * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider

# 验证计划任务已禁用
Get-ScheduledTask | Where-Object { $_.State -eq 'Disabled' } | Select-Object TaskName
```

### 最终汇报示例

```
=== 自启动清理报告 ===

✅ 已禁用（5 项）
  - WpsUpdateLogonTask_20919（计划任务）
  - WpsUpdateTask_20919（计划任务）
  - QianwenUpdaterTaskUser1.0.0.7（HKCU Run + 计划任务）
  - MicrosoftEdgeAutoLaunch_*（HKCU Run）
  - （其他）

🟡 已保留（按用户要求）
  - DeskGo（腾讯桌面整理）
  - WallpaperEngine（动态壁纸）

🔄 回退方法
  - 恢复注册表项：编辑备份文件 run_backup_YYYYMMDD.reg 双击导入
  - 启用计划任务：Enable-ScheduledTask -TaskName <名称>
```
