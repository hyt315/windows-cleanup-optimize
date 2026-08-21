# 软件卸载与残留清理（Software Uninstall）

> 软件不只是删个图标那么简单——Windows 卸载程序通常**只删除 Program Files 下的安装目录和注册表项**，但 AppData 下的用户配置/缓存/聊天记录、计划任务、后台服务都不会自动清理。本节提供从"标准卸载"到"残留清理"再到"专项卸载（WPS / 钉钉 / 360）"的完整流程。

---

## 目录

- [完整卸载流程（5 步）](#完整卸载流程5-步)
- [Step 1：标准卸载（控制面板 / 设置）](#step-1标准卸载控制面板--设置)
- [Step 2：专用卸载工具（Geek / Revo / IObit）](#step-2专用卸载工具geek--revo--iobit)
- [Step 3：残留清理（AppData + 注册表 + 服务 + 计划任务）](#step-3残留清理appdata--注册表--服务--计划任务)
- [Step 4：浏览器劫持修复](#step-4浏览器劫持修复)
- [专项卸载：WPS Office](#专项卸载wps-office)
- [专项卸载：钉钉 (DingTalk)](#专项卸载钉钉-dingtalk)
- [专项卸载：360 家族（最难）](#专项卸载360-家族最难)
- [工具对比](#工具对比)

---

## 完整卸载流程（5 步）

```
Step 1：标准卸载（控制面板 / 设置）
        ↓
Step 2：专用工具扫描残留（Geek / Revo / IObit）
        ↓
Step 3：AppData + ProgramData 残留清理
        ↓
Step 4：注册表残留清理（备份后删）
        ↓
Step 5：计划任务 / 服务残留清理（提权）
```

每一步都可中断——如果标准卸载就能清干净，后面的步骤可跳过。

---

## Step 1：标准卸载（控制面板 / 设置）

**Win11**：
```
设置 → 应用 → 已安装的应用 → 找到目标 → 三点菜单 → 卸载
```

**Win10**：
```
设置 → 应用 → 应用和功能 → 找到目标 → 单击 → 卸载
```

**控制面板**（老方法，仍可用）：
```
Win+R → appwiz.cpl → Enter → 找到目标 → 右键 → 卸载
```

---

## Step 2：专用卸载工具（Geek / Revo / IObit）

标准卸载往往留大量垃圾——专用工具能扫出"控制面板看不到"的残留项。

| 工具 | 推荐 | 优势 | 下载 |
|------|------|------|------|
| **Geek Uninstaller** | ⭐⭐⭐⭐⭐ | 极轻量（6 MB）、免安装、强制删除（删除时跳过标准卸载，直接扫残留）、支持右键菜单集成 | https://geekuninstaller.com |
| **Revo Uninstaller Free** | ⭐⭐⭐⭐ | 内置 Hunter Mode（拖动瞄准镜到窗口定位卸载）、清理彻底 | https://www.revouninstaller.com |
| **IObit Uninstaller** | ⭐⭐⭐ | 中文 UI、有"软件健康"评分、批量卸载 | https://www.iobit.com |
| **HiBit Uninstaller** | ⭐⭐⭐⭐⭐ | 开源、轻量、功能齐全（强制卸载、批量、清理注册表、Startup 管理） | https://hibitsoft.ir |

**Geek Uninstaller 使用流程**（推荐）：
1. 下载（不安装，绿色版）
2. 右键目标软件 → "卸载"（先走标准流程）
3. 卸载完成后弹窗"扫描注册表残留" → 勾选全部 → 删除
4. 再扫描"文件残留" → 全部删除

**强制卸载**（标准卸载卡死/失败时）：
- Geek：右键 → "强制卸载"（直接删文件 + 注册表，跳过正常卸载）
- Revo：高级模式 → "强制卸载"

---

## Step 3：残留清理（AppData + 注册表 + 服务 + 计划任务）

### 3.1 AppData 残留

`%APPDATA%` 和 `%LOCALAPPDATA%` 下会有配置、缓存、聊天记录。

**审计**（扫描 Roaming + Local）：
```powershell
$targets = @("$env:APPDATA", "$env:LOCALAPPDATA")
foreach ($base in $targets) {
    Get-ChildItem $base -Directory -Force -EA SilentlyContinue | ForEach-Object {
        $size = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -EA SilentlyContinue |
               Measure-Object Length -Sum -EA SilentlyContinue).Sum / 1MB, 2)
        if ($size -gt 1) { Write-Host "$size MB  $($_.FullName)" }
    }
}
```

**判断残留**：与 `bloatware-catalog.md` 的 AppData 路径对比，确认是哪个软件。

**清理**（走回收站）：
```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
$paths = @(
    "$env:APPDATA\360safe",
    "$env:APPDATA\2345Security",
    "$env:APPDATA\Kingsoft\WPSUpdate",
    "$env:LOCALAPPDATA\360safe"
    # 添加确认的残留路径
)
foreach ($p in $paths) {
    if (Test-Path $p) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $p, 'OnlyErrorDialogs', 'SendToRecycleBin')
        Write-Host "[OK] -> 回收站: $p"
    }
}
```

### 3.2 ProgramData 残留

`C:\ProgramData\` 是系统级应用数据，部分卸载残留在这里：

```powershell
Get-ChildItem "C:\ProgramData" -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $size = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
           Measure-Object Length -Sum -EA SilentlyContinue).Sum / 1MB, 2)
    if ($size -gt 5) { Write-Host "$size MB  $($_.FullName)" }
}
```

### 3.3 注册表残留

**扫描可疑键**（基于已卸载软件的关键词）：
```powershell
$keywords = @("360safe", "2345Safe", "2345Live", "Kingsoft", "KSafe", "KSAVSvc", "AlibabaProtect", "DingTalk", "WPS")
foreach ($kw in $keywords) {
    $paths = @(
        "HKCU:\Software\$kw",
        "HKLM:\Software\$kw",
        "HKLM:\Software\WOW6432Node\$kw"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Write-Host "命中: $p"
            # 备份
            $backup = "$env:USERPROFILE\reg_backup_$kw_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
            reg export $p.Replace('HKCU:\', 'HKCU\').Replace('HKLM:\', 'HKLM\') $backup /y 2>$null
            # 删除
            Remove-Item $p -Recurse -Force -EA SilentlyContinue
            Write-Host "[OK] 删除: $p"
        }
    }
}
```

**⚠️ 重要警告**：
- 删除前**必须备份**（`reg export`）
- **不要批量删**——只删明确是残留的键
- 涉及 `HKLM` 需管理员权限

### 3.4 计划任务残留

```powershell
$taskPatterns = @("360SafeUpdate", "*2345*", "AlibabaProtect*", "DingTalk*", "WPS*")
foreach ($p in $taskPatterns) {
    Get-ScheduledTask -EA SilentlyContinue |
        Where-Object { $_.TaskName -like $p } |
        ForEach-Object {
            $t = $_
            if ($t.State -ne 'Disabled') {
                Disable-ScheduledTask -InputObject $t -EA SilentlyContinue
            }
            Unregister-ScheduledTask -InputObject $t -Confirm:$false -EA SilentlyContinue
            Write-Host "[OK] 删除计划任务: $($t.TaskName)"
        }
}
```

### 3.5 服务残留

```powershell
$servicePatterns = @("360*", "*2345*", "*KSafe*", "*AlibabaProtect*", "*DingTalk*")
foreach ($p in $servicePatterns) {
    Get-Service -EA SilentlyContinue |
        Where-Object { $_.Name -like $p -or $_.DisplayName -like $p } |
        ForEach-Object {
            $svc = $_
            Write-Host "发现服务: $($svc.Name) ($($svc.DisplayName)) - 状态: $($svc.Status)"
            # 停用并删除
            Stop-Service -Name $svc.Name -Force -EA SilentlyContinue
            sc.exe delete $svc.Name 2>$null
            Write-Host "[OK] 删除服务: $($svc.Name)"
        }
}
```

> 服务操作**需要管理员权限**——非管理员运行时脚本会失败，需提权重试。

---

## Step 4：浏览器劫持修复

如果 bloatware 修改了浏览器首页或默认搜索引擎：

### Chrome
1. 打开 Chrome → 设置 → 搜索引擎 → 改回 Google / 百度
2. 设置 → 启动时 → 删除可疑"打开特定页面"
3. 检查扩展：设置 → 扩展程序 → 删除可疑项

### Edge
1. 设置 → 开始、主页和新建标签页 → 关闭"由你的组织管理"
2. 设置 → 隐私、搜索和服务 → 地址栏和搜索 → 改回默认

### Firefox
1. about:preferences → 主页 → 改回 about:home
2. about:preferences#search → 改回默认搜索引擎

### 注册表层面修复（兜底）

```powershell
# Chrome 首页劫持修复
$chromePolicyKey = "HKCU:\Software\Policies\Google\Chrome"
if (Test-Path $chromePolicyKey) {
    Remove-Item $chromePolicyKey -Recurse -Force
    Write-Host "[OK] 清除 Chrome 策略"
}

# Edge 首页劫持修复
$edgePolicyKey = "HKCU:\Software\Policies\Microsoft\Edge"
if (Test-Path $edgePolicyKey) {
    Remove-Item $edgePolicyKey -Recurse -Force
    Write-Host "[OK] 清除 Edge 策略"
}
```

---

## 专项卸载：WPS Office

**WPS 残留场景**：即使控制面板卸载，`%APPDATA%\Kingsoft\office6` 配置目录、`addons/pool/win-i386/` 旧版插件、`VMCache` 缓存都不会清。

**专项清理流程**：

1. 控制面板卸载 WPS Office（三个入口都要试：WPS Office、WPS 加载项、Kingsoft Components）

2. **检测非标准安装路径（2026-08 实战教训）**。
   标准位置是 `C:\Program Files (x86)\Kingsoft\WPS Office`，但第三方渠道装的 WPS 常在 `<自定义安装根>/WPS Office/<版本号>/office6/` 或 `D:\Program Files\Kingsoft\`。先查注册表反推真实路径：
   ```powershell
   Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
       Where-Object { $_.DisplayName -match 'WPS|Kingsoft' } |
       Select-Object DisplayName, InstallLocation, DisplayVersion
   ```
   同时扫以下候选根找 `wps.exe` / `ksolaunch.exe`：
   ```powershell
   $candidates = @(
       "C:\Program Files (x86)\Kingsoft\WPS Office",
       "C:\Program Files\Kingsoft\WPS Office",
       "C:\Program Files (x86)\WPS Office",
       "<自定义安装根>/WPS Office",                # 用户自定义安装区
       "D:\Program Files (x86)\Kingsoft\WPS Office",
       "D:\Program Files\Kingsoft\WPS Office"
   )
   foreach ($p in $candidates) {
       foreach ($bin in @('office6\wps.exe','office6\ksolaunch.exe')) {
           $full = Join-Path $p $bin
           if (Test-Path $full) { Write-Host "找到: $full" }
       }
   }
   ```

3. 关闭所有 WPS 相关进程：
   ```powershell
   Get-Process | Where-Object { $_.Name -match '^wps|wpscloudsvr|kingsoft' } | Stop-Process -Force
   ```

4. 清理 AppData 残留：
   ```powershell
   $paths = @(
       "$env:APPDATA\kingsoft",         # 配置目录
       "$env:APPDATA\WPS Cloud Files",  # 云文档缓存
       "$env:LOCALAPPDATA\Kingsoft",    # 本地缓存
       "$env:APPDATA\Kingsoft\office6",
       "$env:APPDATA\Kingsoft\WPSUpdate"
   )
   ```

5. 清理 ProgramData（提权）：
   ```powershell
   "C:\ProgramData\Kingsoft"
   ```

6. 清理计划任务（提权）：
   ```powershell
   Disable-ScheduledTask -TaskName "WpsUpdateLogonTask_*" -EA SilentlyContinue
   Disable-ScheduledTask -TaskName "WpsUpdateTask_*" -EA SilentlyContinue
   Disable-ScheduledTask -TaskName "WpsWakeWnsLogonTask" -EA SilentlyContinue  # 消息推送中心
   ```

7. 清理注册表（备份后删）：
   ```powershell
   reg export "HKCU\Software\Kingsoft" "$env:USERPROFILE\kingsoft_backup.reg" /y
   Remove-Item "HKCU:\Software\Kingsoft" -Recurse -Force -EA SilentlyContinue
   ```

**如果只想保留 WPS 但清理垃圾**（不卸载）：
- 删 `addons/pool/win-i386/` 下**多版本插件中的旧版本**（保留最新）
- 删 `%LOCALAPPDATA%\Kingsoft\WPS Office\Temp\` 临时文件
- 关闭 WPS 推送通知与广告

### 治本：禁用 WPS 自动升级 + 关闭反复复活的更新任务（2026-08 实战沉淀）

**症状**：手动禁用 `WpsUpdateTask_<用户名>` 和 `WpsUpdateLogonTask_<用户名>` 后，下次开 WPS 这两个任务又被 `ksolaunch.exe /wpsupdate` 自动重写，任务计划程序里反复复活。

**根因**：WPS 启动器 `ksolaunch.exe` 在每次 WPS 主程序运行时检查并重新注册更新任务。`wpscloudsvr` 服务也会注册 `WpsWakeWnsLogonTask`。

**三层防护**（缺一不可，单独任何一层都会被绕过）：

| 层 | 操作 | 工具/权限 |
|---|---|---|
| ① 配置层（治本） | 改 `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo\UpdateMode` 从 `auto` → `manual`，同时把 `LastUpdateMode` 也改成 `manual`（防止 WPS 启动时用 LastUpdateMode 覆盖 UpdateMode） | 当前用户，无需管理员 |
| ② 任务层（兜底） | 禁用 3 个 WPS 任务：`WpsUpdateTask_<user>`、`WpsUpdateLogonTask_<user>`、`WpsWakeWnsLogonTask` | **根目录任务需管理员** |
| ③ 服务层（兜底） | 禁 `wpscloudsvr` 服务 | **需管理员** |

**完整修复脚本**（保存为 `fix_wps_never_again.ps1`，**非管理员部分可直接运行**）：

```powershell
# === 前置：备份注册表整键 ===
reg export "HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo" `
    "$env:USERPROFILE\wps_update_backup.reg" /y 2>&1 | Out-Null

# === 第 1 层（治本）===
$k = 'HKCU:\Software\Kingsoft\Office\6.0\Common\updateinfo'
if (Test-Path $k) {
    Set-ItemProperty -Path $k -Name 'UpdateMode' -Value 'manual' -Type String
    Set-ItemProperty -Path $k -Name 'LastUpdateMode' -Value 'manual' -Type String
    Set-ItemProperty -Path $k -Name 'UpdateNewPageAutoShown' -Value 'false' -Type String
    Write-Host "[OK] WPS UpdateMode=manual（治本层完成）"
}

# === 第 2 层 + 第 3 层（需管理员，单独跑） ===
# 单独保存为 fix_wps_never_again_admin.ps1，用户右键以管理员运行
# 内容：
# $tasks = @("\WpsUpdateTask_$env:USERNAME", "\WpsUpdateLogonTask_$env:USERNAME", "\WpsWakeWnsLogonTask")
# foreach ($t in $tasks) {
#     schtasks /change /tn $t /disable 2>&1 | Out-Null
#     if ($LASTEXITCODE -eq 0) { Write-Host "[OK] 禁用任务: $t" }
# }
# sc.exe config wpscloudsvr start= disabled
# sc.exe stop wpscloudsvr
```

**回退**：双击 `wps_update_backup.reg` 把注册表还原 + 用管理员跑 `schtasks /change /tn <task> /enable` 把任务恢复 + `sc config wpscloudsvr start= auto` 把服务恢复。

**注意**：用户找不到 WPS in-app "自动升级" 开关（某些版本菜单藏得深或根本没有）时，注册表改 UpdateMode 是**最快的治本路径**。这个开关 in-app UI 和注册表是**同一配置的不同表现层**。

---

## 专项卸载：钉钉 (DingTalk)

**钉钉卸载陷阱**：钉钉装了"钉钉保镖"安全服务，会拒绝标准卸载。

**专项清理流程**：

1. 控制面板卸载钉钉
2. **手动终止保镖进程**：
   ```powershell
   Get-Process | Where-Object { $_.Name -match 'AliApplet|DingTalk|Alibaba' } | Stop-Process -Force
   ```
3. 删除安装目录（提权）：
   ```powershell
   # 主要路径
   "C:\Program Files (x86)\DingTalk"
   "C:\Program Files (x86)\AlibabaProtect"  # 钉钉保镖
   ```
4. 清理注册表：
   ```powershell
   $keys = @(
       "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\DingTalk",
       "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AlibabaProtect",
       "HKLM:\SYSTEM\CurrentControlSet\Services\alibabaprotect"
   )
   foreach ($k in $keys) { if (Test-Path $k) { Remove-Item $k -Recurse -Force } }
   ```
5. 删除服务（提权）：
   ```powershell
   sc.exe delete alibabaprotect
   sc.exe delete AlibabaProtect
   ```

---

## 专项卸载：360 家族（最难）

360 自我保护最严——**普通标准卸载基本无效**，需要专用工具。

### 推荐工具

**GitHub 项目 `force-uninstall-360`**（[ROWENxAI/force-uninstall-360](https://github.com/ROWENxAI/force-uninstall-360)）：
- 提供 PowerShell 脚本，自动化处理 360 内核驱动
- 维护了完整的 360 内核驱动名列表：`360AvFlt`、`360Box`、`360FsFlt`、`360SelfProtection` 等
- 处理 `PendingFileRenameOperations`（被锁文件的删除机制）

### 手工流程（不推荐，复杂）

1. 进安全模式（开机按 F8 → 安全模式）
2. 删除 360 安装目录（多个：`C:\Program Files (x86)\360safe`、`C:\Program Files (x86)\360\360safe`）
3. 用 `sc.exe delete` 删除所有 360 服务
4. 删除内核驱动（用 `PendingFileRenameOperations`）
5. 重启后清理注册表

**⚠️ 风险警告**：360 内核驱动修改系统底层，**错误的删除可能导致系统无法启动**。强烈建议使用专用工具（GitHub 项目脚本）而不是手工操作。

### 360 残留检测

```powershell
# 检查 360 服务
Get-Service | Where-Object { $_.Name -like '*360*' -or $_.DisplayName -like '*360*' }

# 检查 360 驱动
$drivers = & pnputil /enum-drivers
$drivers | Select-String "360"

# 检查 360 启动项
Get-ScheduledTask | Where-Object { $_.TaskName -like '*360*' }
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" |
    ForEach-Object { $_.PSObject.Properties | Where-Object { $_.Name -like '*360*' } }
```

---

## 工具对比

| 工具 | 价格 | 卸载彻底性 | 强制卸载 | 中文 UI | 推荐场景 |
|------|------|-----------|---------|---------|----------|
| **Geek Uninstaller** | 免费（个人） | ⭐⭐⭐⭐⭐ | ✅ | ❌ | **首选**——轻量、强制删除 |
| **HiBit Uninstaller** | 免费 | ⭐⭐⭐⭐⭐ | ✅ | ❌ | Geek 替代品，开源 |
| **Revo Uninstaller Free** | 免费 | ⭐⭐⭐⭐ | ✅ | ❌ | Hunter Mode（瞄准镜拖到窗口） |
| **IObit Uninstaller** | 免费（基础） | ⭐⭐⭐ | ✅ | ✅ | 中文用户、批量卸载 |
| **Wise Program Uninstaller** | 免费 | ⭐⭐⭐ | ❌ | ✅ | 中文用户、简单场景 |

**推荐**：先试 Geek（强制卸载 + 注册表扫描），不行再上 IObit（中文 + 评分）。
