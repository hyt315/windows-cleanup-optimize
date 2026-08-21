# 扫描与清理脚本模板库

<!-- skill-doctor: allow-block SEC002（命令示例路径用 <用户名> / %USERPROFILE% 占位，无真实用户路径） -->

从 SKILL.md 抽取的完整 PowerShell 模板。**SKILL.md 只保留流程说明与关键逻辑，执行时按需回读本节对应模板**，不要凭记忆改写。

## 目录

- 一、通用扫描模板（Scan-Directory / Scan-NonSystemDrive）
- 二、残留检测模板（Roaming / 安装目录 / 更新包）
- 三、安全清理模板（ReparsePoint 预检 / SafeRecycle / Temp 被锁处理）
- 四、验证汇报模板（清理后对比）
- 五、新增模板（清理+优化双线）
- 六、Shell 扩展审计（2026-08 实战新增）

## 一、通用扫描模板

### 1. 用户目录分层扫描（SKILL.md 1.2）

```powershell
function Scan-Directory {
    param([string]$Path, [int]$TopN = 20)
    Get-ChildItem $Path -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }
        [PSCustomObject]@{
            Name    = $_.Name
            SizeMB  = [math]::Round($size / 1MB, 2)
            FullPath = $_.FullName
        }
    } | Sort-Object SizeMB -Descending | Select-Object -First $TopN
}
```

扫描顺序（从粗到细）：第一层 `$env:USERPROFILE` 一级目录（含隐藏）→ 第二层 `AppData\Local` → 第三层 `AppData\Roaming` → 第四层 `AppData\Local\Programs` → 第五层用户目录隐藏目录（.cache、.rustup、.hermes-web-ui 等）。对每一层调用 `Scan-Directory` 汇总。

> **模板作用域警告（2026-08 实战踩坑）：** 若要把扫描结果追加到脚本级变量（`$report += ...`），**必须写成 `$script:report += ...`**。PowerShell 函数内普通赋值会创建函数局部变量、不会写回外部变量——表现是扫描报告大片空白、白扫一轮。推荐做法：让函数直接返回对象数组（如上），由调用方 `$rows = Scan-Directory ...` 捕获输出。

> **进度反馈：** 全盘扫描耗时 2-6 分钟且无输出，用户会以为卡死。建议每完成一层输出一行 `Write-Host "[1/5] 用户目录扫描完成 ..."`；Bash 调用设 `timeout 300000ms` 以上。

### 2. 非系统盘根目录扫描（SKILL.md 1.5.1）

```powershell
function Scan-NonSystemDrive {
    param([string]$DriveLetter = "D")
    $root = "${DriveLetter}:\"
    Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }
        [PSCustomObject]@{
            Name      = $_.Name
            SizeMB    = [math]::Round($size / 1MB, 0)
            FullPath  = $_.FullName
            Hidden    = if ($_.Attributes -match 'Hidden') { 'Y' } else { 'N' }
            LastWrite = $_.LastWriteTime.ToString('yyyy-MM-dd')
        }
    } | Sort-Object SizeMB -Descending
}
```

非系统盘不做 AppData 式逐层扫描，只做根目录一级展开；对可疑大目录再深入一层。**不要对非系统盘全盘 `-Recurse`**（几十到上百 GB 会非常慢）。

## 二、残留检测模板

### 3. Roaming 残留软件检测（SKILL.md 1.4）

```powershell
# Step 1: 扫描 Roaming 目录
$roamingResults = @()
Get-ChildItem $env:APPDATA -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($null -eq $size) { $size = 0 }
    $roamingResults += [PSCustomObject]@{
        Name     = $_.Name
        SizeMB   = [math]::Round($size / 1MB, 2)
        FullPath = $_.FullName
        LastWrite = $_.LastWriteTime.ToString("yyyy-MM")
    }
}

# Step 2: 读取已安装应用（注册表 + 开始菜单）
$installedNames = @()
# HKLM 64-bit
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# HKLM 32-bit
Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# HKCU
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } | ForEach-Object { $installedNames += $_.DisplayName }
# 开始菜单快捷方式名称
$startMenuNames = @()
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
    ForEach-Object { $startMenuNames += $_.BaseName }
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
    ForEach-Object { $startMenuNames += $_.BaseName }

# Step 3: 交叉比对 — 模糊匹配 Roaming 目录名与已安装应用名
$installedLower = ($installedNames + $startMenuNames) | ForEach-Object { $_.ToLower() } | Select-Object -Unique

foreach ($dir in $roamingResults) {
    $dirLower = $dir.Name.ToLower()
    $match = $installedLower | Where-Object { $_ -match [regex]::Escape($dirLower) -or $dirLower -match [regex]::Escape($_) }
    if ($match) {
        $dir | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'INSTALLED'
    } else {
        $dir | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'RESIDUAL'
    }
}

# 输出分类结果
Write-Host "=== 已卸载软件的残留（可安全清理）==="
$roamingResults | Where-Object { $_.Status -eq 'RESIDUAL' -and $_.SizeMB -gt 0 } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB, LastWrite -AutoSize

Write-Host "`n=== 正在使用的软件（不要动）==="
$roamingResults | Where-Object { $_.Status -eq 'INSTALLED' } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB -AutoSize
```

匹配结果不一定 100% 准确（目录名和应用名可能不完全对应），需要人工审视后呈现给用户确认。对于标记为 `RESIDUAL` 的目录，按大小排序呈现，让用户确认后批量清理。

### 4. 安装目录残留检测（SKILL.md 1.4.1）

**Roaming 检测只覆盖配置残留，最大的卸载残留往往在安装目录里**（2026-08 实战：`C:\Program Files\JetBrains` 2.4 GB + D 盘 IDEA/PyCharm 4.4 GB，均一年多未用；`C:\Program Files (x86)\ByteDance` 295 MB 搬家备份；`AlibabaProtect` 396 MB 钉钉卸载残留——这些全部在安装目录而非 Roaming）。必须在 Roaming 检测之外**单独做安装目录比对**：

```powershell
# 步骤 1：收集已安装应用匹配词（注册表 DisplayName + 开始菜单，同模板 3 的 Step 2）
# 步骤 2：扫描安装目录一级 vs 匹配词，无匹配即"疑似残留"
$progBases = @("C:\Program Files", "C:\Program Files (x86)",
               "D:\Program Files", "D:\Program Files (x86)", "$env:LOCALAPPDATA\Programs")
$knownSys = @('common files','windows nt','internet explorer','windows defender',
              'microsoft shared','windows media player','reference assemblies',
              'msbuild','dotnet','windows kits','windowsapps','modifiablewindowsapps',
              'windows powershell')  # 系统/共享目录，跳过
foreach ($pb in $progBases) {
    if (-not (Test-Path $pb)) { continue }
    Get-ChildItem $pb -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $dirLower = $_.Name.ToLower()
        if ($knownSys -contains $dirLower) { return }
        $match = $installedLower | Where-Object {
            $_ -match [regex]::Escape($dirLower) -or $dirLower -match [regex]::Escape($_)
        } | Select-Object -First 1
        if (-not $match) {
            # 输出: 大小 | 目录名 | 路径 | 最后写入时间
        }
    }
}
```

判定要点（务必执行，防止误删在用软件）：
- **交叉比对只是筛选，不是结论**。对每个"疑似残留"必须核对：目录内部 LastWriteTime 是否超过 6 个月、进程列表是否有对应进程、注册表是否有其他条目（软件改名/公司名目录常见误判，如 `Tencent`、`Microsoft` 这类目录名会被目录匹配词覆盖，需人工核对内部装了谁）。
- 目录名是公司名（`AlibabaProtect`、`ByteDance`、`Netease` 等）时，用"公司名 + 已卸载"搜索注册表安装列表，确认该公司的软件是否都已卸载。
- **空壳目录**（0-5 MB 且内部无有效文件）可直接判定为残留，但要识别 `ModifiableWindowsApps`、`WindowsPowerShell` 等系统目录（加入 `$knownSys`）。

> **2026-08 新增**：本模板假设软件装在标准路径，但**非标准路径的检测见 pitfalls 59**——务必用 Uninstall 注册表反查实际路径作为兜底。

### 5. 更新包残留检测（SKILL.md 1.6）

**用户场景"更新了很多软件，更新包没清理"对应的完整检测流程**（2026-08 实战：一次扫出 5 个 electron-updater 残留共 2.2 GB）。分四个专项扫描：

```powershell
# A. AppData 下 update/updater 类目录（主战场）
# 前置：需先执行模板 3 的 Step 2 构建 $installedLower（本专项不依赖它，但流程上先跑更完整）
foreach ($base in @($env:LOCALAPPDATA, $env:APPDATA)) {
    Get-ChildItem $base -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'update|updater|patch|installer|pending' } |
        ForEach-Object { # 输出大小 >5MB 的目录及 LastWriteTime }
}

# B. 各软件安装目录下的 Update/updater/pending 子目录
# 前置：需先执行模板 4 构建 $progBases（安装目录列表）
foreach ($pb in $progBases) {
    Get-ChildItem $pb -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($sub in @('Update','updater','pending','updateTemp')) {
            $updDir = Join-Path $_.FullName $sub
            if (Test-Path $updDir) { # 输出 >20MB 的及所属软件 }
        }
    }
}

# C. 系统级更新缓存（只读统计）
#   C:\Windows\SoftwareDistribution\Download        Windows 更新下载缓存
#   C:\Windows\SoftwareDistribution\DeliveryOptimization  更新 P2P 缓存
#   C:\Windows\Installer                            MSI 缓存（第四档，不可删）
#   C:\NVIDIA  C:\AMD  C:\Intel                     驱动安装包解压缓存
#   C:\ProgramData\Package Cache                    安装器缓存（第四档）

# D. Downloads 与 Temp 中的安装包
#   %USERPROFILE%\Downloads 下 *.exe/*.msi/*.zip/*.iso >50MB 的文件
```

**"已装完残留" vs "等待安装包" 的判断（关键技巧）：** electron-updater 的 `pending\installer.exe` 可能是"更新完没清理"也可能是"等下次启动安装"。判断方法——**对比安装包版本号与已安装版本号**：

```powershell
# 安装包版本
(Get-Item "$env:LOCALAPPDATA\xxx-updater\pending\installer.exe").VersionInfo.ProductVersion
# 已安装版本（主程序）
(Get-Item "$env:LOCALAPPDATA\Programs\AppName\AppName.exe").VersionInfo.ProductVersion
# 相等 → 已装完，纯残留，可安全清理
# 不等或读不到版本 → 按"待安装"处理：告知用户先重启该软件完成更新，
#   或直接移入回收站（可恢复；软件下次更新会重新下载，只是停留在当前版本）
```

清理口径：更新包残留全部归**第一档**（移入回收站可恢复 + 可重新下载，双保险）。

## 三、安全清理模板

### 6. ReparsePoint 预检（SKILL.md 4.0，必须在删除前执行）

对每个待清理目录，先检查是否为 junction/symlink（ReparsePoint）。如果是，**不能直接 SendToRecycleBin**——需要判断指向的目标是否仍在使用：

```powershell
function Test-ReparsePoint {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    if ($item.Attributes -match 'ReparsePoint') {
        # 注意：$item.Target 仅 PowerShell 6+ 存在，PS 5.1 下取不到目标。
        # 如需显示 junction 目标，用: cmd /c dir /AL "<父目录>" 查看
        Write-Host "[JUNCTION] $Path"
        return $true
    }
    return $false
}
```

处理规则：
- **是 junction 且目标在 C 盘活跃路径** → 只删 junction 本身（用 `cmd /c rmdir "$Path"`，不带 `/s`），不删目标
- **是 junction 且目标已不存在** → 直接 `cmd /c rmdir "$Path"` 删除空壳
- **不是 junction** → 正常走 `SafeRecycle`

实战案例：`D:\zcode\TRAE SOLO CN`（0 MB）疑似 junction 空壳，必须先确认属性再决定删除方式。

### 7. SendToRecycleBin 函数（SKILL.md 4.1）

所有直接删除操作走这个函数：

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic

function SafeRecycle {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Write-Host "[SKIP] $Label - 路径不存在: $Path"
        return
    }
    try {
        $item = Get-Item $Path -Force
        $sizeMB = [math]::Round(
            (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB, 2)
        if ($null -eq $sizeMB) { $sizeMB = 0 }

        if ($item.PSIsContainer) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        Write-Host "[OK]   $Label ($sizeMB MB) -> 回收站"
    } catch {
        Write-Host "[LOCK] $Label - 文件被占用，已跳过: $($_.Exception.Message)"
    }
}
```

### 8. Temp 被锁文件处理（SKILL.md 4.3）

```powershell
$tempPath = "$env:LOCALAPPDATA\Temp"
$cleaned = 0; $skipped = 0

Get-ChildItem $tempPath -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        $cleaned++
    } catch {
        $skipped++
    }
}
# 对子目录同理
Get-ChildItem $tempPath -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
            $_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        $cleaned++
    } catch {
        $skipped++
    }
}
Write-Host "Temp: 清理 $cleaned 项, 跳过 $skipped 项（被占用）"
```

被锁文件是正常的，告诉用户"重启电脑后再清即可"。

## 四、验证汇报模板

```powershell
# 对每个扫描过的盘分别获取清理后可用空间
$drives = @("C", "D")  # 根据实际扫描的盘列表调整
foreach ($letter in $drives) {
    $afterFree = [math]::Round((Get-PSDrive $letter).Free / 1GB, 2)
    Write-Host "$letter 盘清理后可用: $afterFree GB"
}
```

管理员权限判定与提权（SKILL.md 4.4）：

```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
    .IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# 非管理员时提权执行（会弹 UAC，需提前告知用户）：
Start-Process powershell -Verb RunAs -Wait -ArgumentList
    '-NoProfile','-ExecutionPolicy','Bypass','-File','C:\...\clean_admin.ps1'
```

提权脚本要点：
- **日志必须写绝对路径**（`Out-File 'C:\Users\<用户名>\AppData\Local\Temp\report.txt'`），不要用 `$env:TEMP`——提权进程的 TEMP 可能指向不同位置，导致报告"丢失"。
- 提权后 SendToRecycleBin 通常即可成功；若仍失败（被锁），对已确认的残留空壳可回退 `Remove-Item -Recurse -Force`（前提：内容已核实是残留，且用户明确授权）。
- 空壳目录（0 项内容）回收失败的另类原因：目录内有 0 字节/隐藏文件未被统计——先 `Get-ChildItem -Recurse -Force` 核对项数，再决定 `rmdir`（只删空目录，非空自动失败，安全）。
- 一次 UAC 弹窗处理尽量合并所有需提权的目录，减少打扰。

---

## 五、新增模板（清理+优化双线）

### 10. 自启动项审计（对应 `startup-audit.md`）

完整脚本见 `references/startup-audit.md` 的"完整审计脚本"节。核心逻辑：

```powershell
# === HKCU/HKLM Run 扫描 ===
foreach ($key in @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)) {
    if (Test-Path $key) {
        Get-ItemProperty $key -EA SilentlyContinue | ForEach-Object {
            $_.PSObject.Properties |
                Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                ForEach-Object { "自启: $($_.Name) = $($_.Value)" }
        }
    }
}

# === 启动文件夹扫描 ===
foreach ($sp in @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)) {
    if (Test-Path $sp) {
        Get-ChildItem $sp -File -EA SilentlyContinue | ForEach-Object { "$($_.FullName)" }
    }
}

# === 计划任务扫描（启用状态）===
Get-ScheduledTask -EA SilentlyContinue |
    Where-Object { $_.State -ne 'Disabled' } |
    ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo -EA SilentlyContinue
        "任务: $($_.TaskName) | 状态: $($_.State) | 上次: $(if($info.LastRunTime){$info.LastRunTime.ToString('MM-dd HH:mm')}else{'从未'})"
    }
```

### 11. Bloatware 进程批量识别（对应 `bloatware-catalog.md`）

```powershell
$bloatwareProcesses = @(
    "360safe","360sd","ZhuDongFangYu","360TSMain","QHWatchdog","360SafeClean",
    "2345Safe","2345Guard","2345Live","2345Ime","2345Pinyin","2345Explorer","2345Pic","HaoZip",
    "KSAVSvc","kxescore","kxetray","QQPCMgr","QQPCRtp","TQMCenter",
    "LDSMain","LDSService","DriverGenius","DGService","DTLSoft","DrvLife",
    "SogouService","SogouIM","SGMain","QQPinyinService",
    "360Desktop","360DesktopLite","KingsoftDesktop","MojingWallpaper","HaoZhuoDao",
    "360se","360chrome","QQBrowser","SogouExplorer","UCBrowser",
    "FlashCenter","FlashHelperService","TodayHot","NewsPush","HotNews",
    "KuaiZip","BaiduNetdisk","Meitu"
)

# 用户主动保留的白名单
$whitelist = @("DeskGo","DesktopMgr64","Steam","wallpaper32","WallpaperEngine","HuorongEs")

$hits = Get-Process -EA SilentlyContinue | Where-Object {
    $_.ProcessName -in $bloatwareProcesses -and $_.ProcessName -notin $whitelist
}

if ($hits) {
    $hits | Group-Object ProcessName | ForEach-Object {
        $first = $_.Group | Select-Object -First 1
        "[$($_.Count)x] $($_.Name) - 路径: $($first.Path) - 占用: $([math]::Round((($_.Group | Measure-Object WorkingSet -Sum).Sum)/1MB,0)) MB"
    }
} else {
    "未检测到已知 bloatware 进程"
}
```

### 12. 服务快照（优化前备份，对应 `services-optimization.md`）

```powershell
# 导出所有服务状态（备份用）
$backupFile = "$env:USERPROFILE\services_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Get-Service | Select-Object Name, DisplayName, StartType, Status |
    Export-Csv $backupFile -NoTypeInformation
"已备份: $backupFile"

# 列出可优化的服务（按画像筛选）
$optimizable = @(
    "DiagTrack","dmwappushservice","diagnosticshub.standardcollector.service","DusmSvc",
    "XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","BcastDVRUserService",
    "RemoteRegistry","Fax","WerSvc","lfsvc","MapsBroker",
    "WbioSrvc","SCardSvr","SCPolicySvc","CertPropSvc",
    "AdobeARMservice","AdobeUpdateService","GoogleUpdate*","JavaUpdateSched"
)
Get-Service | Where-Object { $_.Name -in $optimizable -or $_.Name -like "GoogleUpdate*" } |
    Format-Table Name, DisplayName, StartType, Status -AutoSize
```

### 13. 内存基线（优化前后对比，对应 `memory-optimization.md`）

```powershell
# 实时内存状态
$mem = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
$freeGB = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
$usedGB = $totalGB - $freeGB
$usedPct = [math]::Round($usedGB / $totalGB * 100, 1)
"物理内存: 总 $totalGB GB / 可用 $freeGB GB / 已用 $usedGB GB ($usedPct%)"

# Top 10 内存占用进程
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 |
    Format-Table Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} -AutoSize

# 提交字节（虚拟内存）
Get-Counter '\Memory\Committed Bytes' | Select-Object -ExpandProperty CounterSamples |
    Select-Object CookedValue, Path

# 导出基线（用于泄漏检测对比）
$baselineFile = "$env:USERPROFILE\memory_baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} |
    Export-Csv $baselineFile -NoTypeInformation
"基线已记录: $baselineFile"
```

### 14. 电源计划与视觉效果（对应 `performance-tuning.md`）

```powershell
# 当前电源计划
powercfg /getactivescheme

# 可用电源计划列表
powercfg /list

# 切换到高性能
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# 启用隐藏的"卓越性能"计划（管理员）
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

# TRIM 检查
fsutil behavior query DisableDeleteNotify

# Defender 排除列表（管理员）
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
```

### 15. 内存泄漏检测（两次采样对比，对应 `memory-optimization.md`）

```powershell
# === 第一次运行：记录基线 ===
$baselineFile = "$env:USERPROFILE\memory_baseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}} |
    Export-Csv $baselineFile -NoTypeInformation
"基线已记录到: $baselineFile"
Write-Host "请等待 30 分钟后再次运行对比脚本。"

# === 第二次运行：找出泄漏进程 ===
# 读取最新的基线文件
$latestBaseline = Get-ChildItem "$env:USERPROFILE\memory_baseline_*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestBaseline) {
    $baseline = Import-Csv $latestBaseline.FullName
    $current = Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}}
    $leaks = $baseline | ForEach-Object {
        $now = $current | Where-Object { $_.Name -eq $_.Name -and $_.Id -eq $_.Id }
        if ($now -and ($now.WS_MB - $_.WS_MB) -gt 50) {
            [PSCustomObject]@{
                Name = $_.Name
                Id = $_.Id
                Baseline_MB = $_.WS_MB
                Current_MB = $now.WS_MB
                Delta_MB = $now.WS_MB - $_.WS_MB
            }
        }
    }
    $leaks | Sort-Object Delta_MB -Descending | Format-Table -AutoSize
}
```

---

## 六、Shell 扩展审计（2026-08 实战新增）

### 16. 右键菜单 / Shell 扩展审计

审计用户问"我的右键菜单有没有被篡改 / 流氓软件 / 缺失项"时使用。完整对照 `bloatware-catalog.md` 的进程名单判断是否为可疑项。

**前置陷阱**：**永远不要用 `Registry::HKEY_CLASSES_ROOT\*\...` 通配符枚举**——HKCR 树几十万节点，10 分钟都跑不完（参见 pitfalls 60）。

**只读审计脚本**：

```powershell
# === 1. 已知良性基线（Microsoft 自带 + 用户主动安装）===
# 用户装过 WPS、DeskGo（Tencent 桌面整理）、NVIDIA，所以这些的 shell 扩展是预期内
$expectedGood = @(
    'FileSyncEx','EncryptionMenu','EPP','Sharing','WorkFolders',           # 系统
    'New','NvCplDesktopContext','EnhancedStorageShell',                    # 系统
    'Open With kwpsshellext','Open With qingshellext',                    # WPS
    'QingNseContextMenu','qkdesktopshellext',                              # WPS
    'CF444751-60FC-48B8-AC0F-363063EB2A9E'                                  # DeskGo (CDeskmgrShellMenu)
)

# === 2. 已知流氓 / bloatware shell 扩展关键词（与 bloatware-catalog.md 对齐）===
$bloatwarePatterns = @('360','2345','HaoZip','KuaiZip','FlashCenter',
                       'SogouService','QQPCMgr','LDSMain','BaiduNetdisk',
                       'MojingWallpaper','HaoZhuoDao','TodayHot','NewsPush',
                       'Meitu','AlibabaProtect','KSafe','KXETray')

# === 3. 收集所有 CLSID（用精确路径，不要通配）===
$allClsids = @()
$roots = @(
    'HKLM:\Software\Classes\Directory\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKLM:\Software\Classes\Drive\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKCU:\Software\Classes\Directory\shellex\ContextMenuHandlers'
)
foreach ($root in $roots) {
    Get-ChildItem $root -EA SilentlyContinue | ForEach-Object {
        $allClsids += (Split-Path $_.PSPath -Leaf)
    }
}
$allClsids = $allClsids | Where-Object { $_ -match '^\{[\w-]+\}$' } | Select-Object -Unique

# === 4. CLSID 解析 + 命中检测 ===
$finding = @{ 'Good' = @(); 'Bloatware' = @(); 'Unknown' = @() }
foreach ($c in $allClsids) {
    $nm = (Get-ItemProperty "HKLM:\Software\Classes\$c" -EA SilentlyContinue)."(default)"
    $inproc = (Get-ItemProperty "HKLM:\Software\Classes\$c\InprocServer32" -EA SilentlyContinue)."(default)"
    $locsvr = (Get-ItemProperty "HKLM:\Software\Classes\$c\LocalServer32" -EA SilentlyContinue)."(default)"
    $impl  = if ($inproc) { $inproc } elseif ($locsvr) { $locsvr } else { '?' }
    $bag = [PSCustomObject]@{ CLSID = $c; Name = $nm; Impl = $impl }

    # 判断是否已知良性
    $isGood = $false
    foreach ($g in $expectedGood) {
        if ($c -like "*$g*" -or "$nm" -like "*$g*") { $isGood = $true; break }
    }
    # 判断是否匹配 bloatware
    $isBloat = $false
    foreach ($b in $bloatwarePatterns) {
        if ($impl -match $b -or "$nm" -match $b) { $isBloat = $true; break }
    }
    if ($isBloat) { $finding.Bloatware += $bag }
    elseif ($isGood) { $finding.Good += $bag }
    else { $finding.Unknown += $bag }
}

# === 5. 输出 ===
Write-Host "===== 良性 Shell 扩展 ====="
$finding.Good | ForEach-Object { Write-Host ("  {0,-40} {1}" -f $_.CLSID, $_.Name) }

Write-Host ""
Write-Host "===== 警告 疑似 bloatware ====="
if ($finding.Bloatware.Count -eq 0) { Write-Host "  （无）" }
$finding.Bloatware | ForEach-Object { Write-Host ("  {0,-40} {1}  -> {2}" -f $_.CLSID, $_.Name, $_.Impl) }

Write-Host ""
Write-Host "===== 未知 / 待定 ====="
$finding.Unknown | ForEach-Object { Write-Host ("  {0,-40} {1}  -> {2}" -f $_.CLSID, $_.Name, $_.Impl) }

# === 6. 可选：列出 HKLM Approved 白名单（很少，主要用于诊断）===
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" -EA SilentlyContinue |
    Get-Member -MemberType NoteProperty | Where-Object Name -notmatch '^(PS|Provider)' |
    ForEach-Object { Write-Host ("Approved: {0}" -f $_.Name) }
```

**判读逻辑**：
- **良性**：Name/CLSID 含系统或预期装过的软件关键词（Microsoft / OneDrive / 加密 / WPS / DeskGo）
- **bloatware**：实现路径（InprocServer32）含 360 / 2345 / HaoZip / KuaiZip / SoGou / QQPCMgr / AlibabaProtect / BaiduNetdisk / Meitu 等关键词
- **未知**：都不是。**给用户看**，让用户确认是否认识/需要（不是自动禁用）

**用户问"我以前的XX去哪了"时**：让用户说出具体名字 → 用 `Get-ChildItem "HKLM:\Software\Classes\<ext>\shell" -Recurse` 或精确路径查那个注册表项。如果键不存在 = 真缺失（被删/未装）；如果存在但不在 Approved = 可能被禁；呈现给用户决定。

**所有审计 .ps1 一律写到 `$env:TEMP` 或 `C:\Windows\Temp`**，不要放用户目录（参见 pitfalls 64）。
