---
name: windows-cleanup-optimize
description: Diagnoses and cleans Windows disk space, identifies and uninstalls bloatware/bundled software, audits/disables startup items, and optimizes Windows services/memory/performance. Use when user reports full C drive, slow boot, pop-up ads, suspicious background processes, laggy apps, or wants general PC tune-up. Zero-harm guarantee: every operation reversible via Recycle Bin or restoration command.
---

# Windows 清理与优化助手（PC Cleanup & Optimization Assistant）

> 一个**零伤害**的 Windows 调优技能：清理（磁盘 + 软件 + 自启动）+ 优化（服务 + 内存 + 性能）+ 高级（数据迁移）。所有方案严格遵守"对电脑零负面影响"原则——所有清理走回收站可恢复，所有优化项标四级风险且提供回退命令。

---

## 适用场景

**清理类：**
- 磁盘空间不足 / C 盘红了
- AppData 累积的缓存（npm / pnpm / 软件日志 / TRAE / WPS / WorkBuddy 等）
- 软件卸载后残留（注册表、AppData、计划任务、服务）
- 自启动项过多，开机慢
- 流氓软件 / 捆绑软件识别与清理（360 / 2345 / 各类弹窗广告）

**优化类：**
- Windows 服务精简（遥测、Xbox、第三方更新器等可安全禁用的服务）
- 内存优化（识别真正的内存泄漏进程；批判性看待"内存清理工具"）
- 系统性能调优（电源计划、视觉效果、SSD TRIM、网络等）
- 按用户画像定制（家庭用户 / 开发者 / 游戏玩家 / 笔记本）

**高级：**
- C 盘大目录通过 `mklink /J` 迁移到 D 盘（TRAE、VS Code、Kimi 等任意软件）

---

## 核心安全原则（零伤害保证）

> 本技能**绝不永久删除**任何用户文件。所有操作可回退、可恢复。

1. **所有清理走回收站** — 使用 `SendToRecycleBin`（`Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory`），不用 `Remove-Item`。
2. **优化项分四级风险** — 每项明确标注 ✅ LOW / ⚠️ MEDIUM / 🔴 HIGH / ❌ CRITICAL。
3. **不动系统目录** — `C:\Windows`、`C:\Program Files`、`C:\ProgramData` 默认只读扫描。
4. **关键操作前建还原点** — 涉及驱动/服务/系统组件时，`Checkpoint-Computer -Description "BeforeXxx"`。
5. **提供完整回退命令** — 每个禁用项/优化项都给出"如何恢复"的命令。
6. **不确定就问用户** — 任何模糊判断（"疑似残留"、"可能不在用"）都呈现给用户确认，不擅自处理。

---

## 工作流（六阶段）

### 阶段 0：用户画像（首次执行时）

明确用户类型，影响后续所有推荐：

| 画像 | 特征 | 优化侧重点 |
|------|------|-----------|
| **家庭用户** | 普通办公、上网、看视频 | 弹窗广告清理、家庭友好服务 |
| **开发者** | 装 IDE、跑 Docker、用各种 AI 客户端 | 不影响开发工具链的服务优化 |
| **游戏玩家** | 打游戏为主 | 高性能电源、GPU 相关、游戏平台数据 |
| **笔记本用户** | 注重续航 | 不推荐禁用电源管理类服务 |

> 一次画像后**不重复询问**——除非用户明确改变身份。

---

### 阶段 1：全面诊断

按以下顺序扫描，输出统一报告：

| 扫描项 | 输出 | 参考文档 |
|--------|------|----------|
| 磁盘空间 | C 盘/各非系统盘的可用/已用 | SKILL.md 阶段 1.0-1.1 |
| AppData 缓存 | npm/pnpm/TRAE/WPS/WorkBuddy 等大缓存 | SKILL.md 阶段 1.2-1.3 |
| 软件残留 | AppData\Roaming + 安装目录 + 注册表交叉比对 | SKILL.md 阶段 1.4 |
| 更新包残留 | electron-updater 类更新器残留 | SKILL.md 阶段 1.6 |
| 非系统盘 | 根目录一级扫描（视频缓存、旧 IDE 等） | SKILL.md 阶段 1.5 |
| **自启动项** | HKCU Run + HKLM Run + 计划任务 + 启动文件夹 | `startup-audit.md` |
| **Windows 服务** | 按风险等级分组的可优化服务清单 | `services-optimization.md` |
| **后台进程** | 按软件族归类的内存占用 + 是否可疑 | `bloatware-catalog.md` 交叉比对 |
| **流氓软件识别** | 按进程名匹配已知 bloatware 库 | `bloatware-catalog.md` |
| **内存压力** | Working Set / Standby / Available | `memory-optimization.md` |

所有扫描都是**只读**——这一阶段不修改任何东西。

---

### 阶段 2：风险分级与方案汇总

将扫描发现按风险/收益分四档：

| 档位 | 含义 | 典型操作 |
|------|------|----------|
| 🟢 **第一档（推荐自动执行）** | 零风险，可恢复 | 清缓存、清回收站、删更新包残留、卸明显 bloatware |
| 🟡 **第二档（需用户确认）** | 轻度风险或部分功能损失 | 卸中等 bloatware、关 Xbox 服务、禁用 SysMain |
| 🟠 **第三档（用户逐项确认）** | 中度风险或显著功能影响 | 卸安全软件、改电源计划、改视觉效果 |
| 🔴 **第四档（强烈不建议动）** | 破坏性或安全风险 | 关 Defender、关 Windows Update、删系统文件 |

---

### 阶段 3：用户确认（关键控制点）

用 `AskUserQuestion` 让用户选择清理/优化力度：

```
问题："你想从哪些模块开始？"
选项：
  - "只清理（不优化）"        → 阶段 4 只跑清理主题
  - "只优化（不清理）"        → 阶段 4 只跑优化主题
  - "清理 + 优化（全部）"     → 阶段 4 全跑
  - "只看看报告"              → 阶段 1-2 完就停
```

如果用户选了"全部"或"优化"，**第三档项必须逐项确认**（不能批量自动执行）。

---

### 阶段 4：分模块执行

按用户选择，调用对应参考文档的执行流程：

#### 清理模块
- **磁盘清理**：见 SKILL.md 阶段 4（`SafeRecycle`、被锁处理、清空回收站）
- **自启动清理**：见 `startup-audit.md`（HKCU Run + HKLM Run + 计划任务）
- **软件卸载**：见 `software-uninstall.md`（标准卸载 → 残留清理）

#### 优化模块
- **服务优化**：见 `services-optimization.md`（按画像选择 ✅ 列表）
- **内存优化**：见 `memory-optimization.md`（识别真泄漏 + 浏览器 Memory Saver + 页面文件）
- **性能调优**：见 `performance-tuning.md`（电源计划 + 视觉效果 + SSD TRIM）

每个模块执行完毕后，**立即输出本模块的小计**（释放了多少 / 关了多少项）。

---

### 阶段 5：验证与回退

| 模块 | 验证方法 | 回退命令 |
|------|----------|----------|
| 磁盘清理 | `Get-PSDrive C.Free` 对比 | 回收站恢复 |
| 自启动清理 | 计划任务 `Get-ScheduledTask` 查状态 | 重新启用 Run 项 / 任务 |
| 服务优化 | `Get-Service` 查状态 | `sc config <svc> start= auto` |
| 内存优化 | `Get-Counter '\Memory\*'` 查压力 | 重启电脑 |
| 性能调优 | `powercfg /getactivescheme` 查电源计划 | `powercfg /setactive <原 GUID>` |

---

### 阶段 6：长期维护建议

给用户一套"长期保持电脑健康"的最小习惯：

1. **每周**：清回收站（`Clear-RecycleBin -Force`）
2. **每月**：跑一次本技能的诊断扫描（仅阶段 1-2）
3. **每季度**：检查自启动项是否新增（`startup-audit.md`）
4. **每年**：升级/卸载长期不用的软件；考虑 mklink 迁移累积的大目录
5. **避免**：安装未知来源软件（用 7-Zip 替代好压、用 SumatraPDF 替代福昕、用火绒替代 360）

---

## 参考文档（按需加载）

> 以下详细内容已拆分为独立文件，遇到对应场景时 **必须先 Read 对应文件** 再操作，不要凭记忆执行。

| 文件 | 何时阅读 |
|------|---------|
| [references/scan-scripts.md](references/scan-scripts.md) | 执行任何扫描/清理/优化时，按编号取对应 PowerShell 模板（1-15） |
| [references/pitfalls.md](references/pitfalls.md) | 遇到异常/边界情况时，先查踩坑记录（含 30+ 优化主题踩坑） |
| [references/startup-audit.md](references/startup-audit.md) | 用户提到开机慢、自启动多、需要禁用某软件自启 |
| [references/bloatware-catalog.md](references/bloatware-catalog.md) | 用户提到 360、2345、弹窗广告、要识别可疑软件 |
| [references/software-uninstall.md](references/software-uninstall.md) | 用户要卸载某软件（含 WPS/钉钉/360 专项清理） |
| [references/system-cleanup.md](references/system-cleanup.md) | 用户需要系统级清理（Windows 更新残留、休眠文件、DriverStore 等） |
| [references/services-optimization.md](references/services-optimization.md) | 用户提到服务优化、后台进程多、需要禁用遥测/Xbox/第三方更新器（50+ 服务按画像分类） |
| [references/memory-optimization.md](references/memory-optimization.md) | 用户提到内存不足、电脑卡顿、需要优化内存（含"内存清理工具都是 placebo"批判性分析） |
| [references/performance-tuning.md](references/performance-tuning.md) | 用户提到电脑慢、想提升性能、电源计划/视觉效果/网络优化（含 Defender 排除列表） |
| [references/trae-guide.md](references/trae-guide.md) | 扫描结果出现 `TRAE SOLO CN` / `.trae-cn` / 用户提到 TRAE |
| [references/mklink-migration.md](references/mklink-migration.md) | 用户想把 C 盘大目录迁移到 D 盘（任意软件 mklink /J 通用方案，含兼容性矩阵） |
| [references/case-study.md](references/case-study.md) | 执行 mklink 迁移前参考（TRAE 含稀疏文件、VS Code 典型 IDE、通用模式三案例） |

---

## 核心安全规则

1. **绝不永久删除用户文件。** 所有清理操作使用 `SendToRecycleBin`（移入回收站），而非 `Remove-Item`。**唯一例外：** 已核实为卸载残留（空壳/旧备份）、且用户明确授权后，可 `Remove-Item`——除此之外一律走回收站。
2. **被锁文件跳过不强制。** 遇到 `IOException` / 占用错误时 catch 并记录，不中断流程。
3. **优先使用官方清理命令。** 如 `npm cache clean --force`、`uv cache clean`、`pip uninstall` 等，比直接删文件夹更干净。
4. **清空回收站才算释放。** `SendToRecycleBin` 只是移动文件，空间不会立刻释放——必须提醒用户清空回收站。
5. **不碰系统目录。** `C:\Windows`、`C:\Program Files`、`C:\ProgramData` 等路径绝不扫描写入，只读分析。**例外：** 已通过残留检测交叉比对确认"卸载残留"的安装目录，经用户逐项确认后可清理（需管理员权限）。
6. **操作前记录基准。** 清理/优化前先记录目标磁盘剩余空间和关键状态，结束后对比，给用户明确的数字反馈。
7. **非系统盘扫描策略不同。** C 盘重点是 AppData/用户目录/系统缓存；D 盘等非系统盘重点是根目录一级扫描（安装目录、迁移备份、开发工具、游戏缓存、临时文件），不做 AppData 式逐层扫描。
8. **优化项风险等级必须标。** 服务/性能/注册表类操作，每项必须标 ✅ LOW / ⚠️ MEDIUM / 🔴 HIGH / ❌ CRITICAL，让用户知情决策。
9. **用户画像驱动推荐。** 同一优化项在不同画像下风险不同（如 SysMain 在 SSD 上可关、HDD 上不应关），必须按画像过滤。
10. **不确定就问用户。** 任何"疑似"判断都呈现给用户确认，绝不擅自批量执行。

---

## 工作流（详细版）

### 阶段 1：诊断扫描

目标：摸清系统全貌，输出按大小/风险排序的清单。

#### 1.0 检测所有磁盘分区

先列出系统上所有固定磁盘（排除光驱、U 盘等可移动设备）：

```powershell
Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeGB = [math]::Round($_.FreeSpace / 1GB, 2)
    $totalGB = [math]::Round($_.Size / 1GB, 2)
    $usedGB = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
    Write-Host "$($_.DeviceID) Total: $totalGB GB | Used: $usedGB GB | Free: $freeGB GB"
}
```

#### 1.1 获取磁盘基准

```powershell
$drive = Get-PSDrive C
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$usedGB = [math]::Round($drive.Used / 1GB, 2)
$totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
Write-Host "Total: $totalGB GB | Used: $usedGB GB | Free: $freeGB GB"
```

#### 1.2 逐层扫描用户目录

扫描顺序（从粗到细）：

```
第一层：$env:USERPROFILE 下所有一级目录（含隐藏）
第二层：AppData\Local 下各目录
第三层：AppData\Roaming 下各目录
第四层：AppData\Local\Programs 下各目录
第五层：用户目录下的隐藏目录（.cache、.rustup、.hermes-web-ui 等）
```

对每一层调用 `Scan-Directory`（完整模板见 `scan-scripts.md` 模板 1）。

> **进度反馈：** 全盘扫描耗时 2-6 分钟且无输出。建议每完成一层输出一行进度；Bash 调用设 `timeout 300000ms` 以上。

#### 1.3 补充扫描常见大户

- `%LOCALAPPDATA%\Temp`、`%LOCALAPPDATA%\npm-cache`、`%LOCALAPPDATA%\pnpm` 等包管理器缓存
- `%LOCALAPPDATA%\ms-playwright`（Playwright 浏览器）
- `$env:USERPROFILE\.trae-cn`、`%APPDATA%\TRAE SOLO CN`（TRAE）
- `%APPDATA%\Code`、`.vscode`（VS Code）
- `$env:USERPROFILE\.workbuddy`、`%APPDATA%\WorkBuddy`（WorkBuddy）

#### 1.4 AppData\Roaming 残留软件检测

Windows 卸载程序通常只删除 `Program Files` 下的安装目录和注册表项，但 `%APPDATA%` 里的用户配置、缓存、聊天记录默认保留。对不再使用的软件来说，这些就是纯垃圾。

检测流程（完整 PowerShell 模板见 `scan-scripts.md` 模板 3）：

1. 扫描 Roaming 全部目录及大小
2. 读取已安装应用列表（注册表 + 开始菜单快捷方式）
3. **交叉比对**——与 `bloatware-catalog.md` 的已知流氓软件名单交叉验证
4. Roaming 目录分为三类：已卸载残留 / 正在使用 / 无法判断

匹配结果不一定 100% 准确，**最终结论必须由用户确认**。

#### 1.4.1 安装目录残留检测

最大的卸载残留往往在安装目录里。必须在 Roaming 检测之外单独做安装目录比对：

- 收集已安装应用匹配词（注册表 DisplayName + 开始菜单）
- 扫描 `C:\Program Files`、`C:\Program Files (x86)`、`$env:LOCALAPPDATA\Programs` 一级
- 无匹配即"疑似残留"
- **判定要点**：交叉比对只是筛选，不是结论——对每个"疑似残留"必须核对内部 LastWriteTime、进程列表、注册表其他条目

#### 1.5 非系统盘扫描（D/E 盘等）

非系统盘的目录结构和 C 盘完全不同——没有 AppData 分层。重点是**根目录一级扫描**（完整模板见 `scan-scripts.md` 模板 2）。

非系统盘常见可清理项目按风险分四档，详见 `scan-scripts.md` 模板 2 和主扫描阶段 1.5.2。

#### 1.6 更新包残留检测

electron-updater 应用的 `pending\installer.exe` 残留是常见空间大户。专项扫描：

- AppData 下 update/updater 类目录（主战场）
- 各软件安装目录下的 Update/updater/pending 子目录
- 系统级更新缓存（`SoftwareDistribution\Download` 等）
- Downloads 与 Temp 中的安装包

完整模板见 `scan-scripts.md` 模板 5。

#### 1.7 自启动项扫描（转 `startup-audit.md`）

详细流程见 `startup-audit.md`。

#### 1.8 Windows 服务扫描（转 `services-optimization.md`）

详细流程见 `services-optimization.md`。

#### 1.9 流氓软件进程扫描（转 `bloatware-catalog.md`）

按进程名匹配已知 bloatware 库。详细流程见 `bloatware-catalog.md`。

#### 1.10 内存压力基线（转 `memory-optimization.md`）

记录当前 Working Set / Standby / Available MBytes，作为优化前后对比基准。详细命令见 `memory-optimization.md`。

---

### 阶段 2：四档风险分级

将扫描结果按以下标准自动归类：

| 档位 | 颜色 | 含义 | 处理 |
|------|------|------|------|
| 第一档 | 🟢 | 零风险，可恢复 | 默认自动执行 |
| 第二档 | 🟡 | 轻度风险 | 用户确认后执行 |
| 第三档 | 🟠 | 中度风险 | **逐项确认** |
| 第四档 | 🔴 | 不可逆/安全风险 | 默认不动 |

详细档位定义见 `pitfalls.md` 各章节与各参考文档。

---

### 阶段 3：用户确认

用 `AskUserQuestion` 让用户选择：

```
问题 1："你想从哪些模块开始？"
选项：
  - "清理（磁盘 + 软件 + 自启动）"
  - "优化（服务 + 内存 + 性能）"
  - "全部"
  - "先不操作"

问题 2（如果选了"全部"或含第三档项）："第三档项需要逐项确认，请选择确认方式"
选项：
  - "每项单独问我"
  - "按类别一次性确认"
  - "只跑第一档+第二档"
```

---

### 阶段 4：分模块执行

按用户选择执行相应模块。每个模块完成后立即输出小计。

#### 4.0 通用准备

**所有清理操作的安全封装**（来自 `scan-scripts.md` 模板 7）：

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
function SafeRecycle {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { return }
    try {
        $item = Get-Item $Path -Force
        $sizeMB = [math]::Round(
            (Get-ChildItem $Path -Recurse -Force -EA SilentlyContinue |
             Measure-Object Length -Sum -EA SilentlyContinue).Sum / 1MB, 2)
        if ($item.PSIsContainer) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        Write-Host "[OK]   $Label ($sizeMB MB) -> 回收站"
    } catch {
        Write-Host "[LOCK] $Label - 文件被占用已跳过"
    }
}
```

**管理员提权**（涉及 Program Files / 服务时）：
```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# 非管理员时：
Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<script.ps1>'
# 会弹 UAC，需要用户提前知情
```

#### 4.1 清理 - 磁盘

调用 `Scan-Directory` 报告后，对第一档项（缓存、更新包残留、Temp 等）执行 `SafeRecycle`。

#### 4.2 清理 - 软件（流氓软件）

按 `software-uninstall.md` 流程：标准卸载 → 残留清理。

#### 4.3 清理 - 自启动

按 `startup-audit.md` 流程：HKCU/HKLM Run 移除 + 计划任务禁用。

#### 4.4 优化 - 服务

按 `services-optimization.md` 流程：`sc config <svc> start= disabled` + `sc stop <svc>`。

#### 4.5 优化 - 内存

按 `memory-optimization.md` 流程：识别真泄漏 + 浏览器 Memory Saver + 页面文件检查。

#### 4.6 优化 - 性能

按 `performance-tuning.md` 流程：`powercfg` + 视觉效果 + `fsutil` 等。

#### 4.7 高级 - mklink 迁移

按 `mklink-migration.md` 流程：参考 `case-study.md` 选择最接近的案例。

---

### 阶段 5：验证与回退

每个模块执行完毕后，对比优化前记录：

| 模块 | 验证命令 |
|------|----------|
| 磁盘 | `Get-PSDrive C \| Select Free` |
| 自启动 | `Get-ScheduledTask \| Where State -eq Disabled \| Measure` |
| 服务 | `Get-Service \| Where StartType -eq Disabled \| Measure` |
| 内存 | `Get-Counter '\Memory\Available MBytes'` |
| 电源 | `powercfg /getactivescheme` |
| 性能 | 主观体验 + 启动时间 |

---

### 阶段 6：汇报与维护建议

最终汇报格式（示例）：

```
=== 清理优化报告 ===

🧹 清理（C 盘 141 GB → 149.33 GB，释放 8.33 GB）
  - 第一档：3.5 GB（缓存 + 更新包）
  - 第二档：730 MB（WPS 旧版插件）
  - 第三档：396 MB（钉钉残留，提权清理）

⚡ 优化
  - 自启动：禁用 5 项（计划任务 + HKCU Run）
  - 服务：禁用 8 项（遥测 + Xbox）
  - 性能：电源计划改为"高性能"

🔒 未执行项（需你逐项确认）
  - SysMain 禁用
  - 视觉效果优化

✅ 长期建议
  - 每周清回收站
  - 每月跑一次诊断
  - 推荐替代：2345 好压 → 7-Zip，360 → 火绒
```

---

## 进阶策略：符号链接迁移（mklink 通用）

C 盘占用大的目录（任何软件的 AppData、用户目录下的隐藏目录等）可以用 `mklink /J` 物理迁移到 D 盘而保持逻辑路径不变。

**迁移不是万能解药**：
- 不是所有软件都兼容（Outlook / 微信 PC / QQ / Docker Desktop 等不兼容）
- 含稀疏文件的目录（虚拟磁盘镜像类）需要混合复制策略
- 部分软件有**官方配置项**可改路径，比 mklink 更稳

**完整通用方案**（适用性矩阵 + 6 步流程 + 复制工具坑 + 兼容性测试与回退）见 `references/mklink-migration.md`。
**实战案例**（TRAE 含稀疏文件 / VS Code 典型 IDE / 任意软件通用模式）见 `references/case-study.md`。

**执行迁移前必须先阅读 `mklink-migration.md` 的兼容性矩阵**，确认目标软件在 ✅ 列表里。

---

## 常见陷阱

执行清理/优化过程中的踩坑记录已拆到 `references/pitfalls.md`。**遇到异常或边界情况时先查阅该文件再操作**，尤其高频条目：

- 陷阱 1/21/27：PowerShell `$` 被 bash 吃掉、函数内变量丢失——一律 .ps1 文件执行
- 陷阱 2：SendToRecycleBin 不释放空间，必须清空回收站
- 陷阱 7/8：浏览器/微信 QQ 缓存不要直接删，建议应用内清理
- 陷阱 15：mklink 迁移时 robocopy 稀疏文件膨胀（通用迁移必读）
- 陷阱 22：`C:\Program Files` 下删除失败的误导性报错，需提权
- 陷阱 28：DriverStore 驱动存储库绝不手删，用 pnputil
- 陷阱 30+：优化主题踩坑（内存清理工具 placebo / SysMain 决策 / Defender 排除列表等）

---

## 回归测试（改动后验证）

技能改动（新增 reference 文件、修改工作流、调整风险等级）后，先跑自带的 selftest 确认门都还在：

```bash
# 自带的 selftest（验证结构完整性）
python scripts/selftest.py
```

**selftest**（`scripts/selftest.py`）覆盖：
- 好夹具：本技能自身结构完整（SKILL.md 有 frontmatter、所有引用的 references 在盘、scan-scripts.md 含 9 个关键模板、pitfalls.md 含 30+ 陷阱条目）
- 负向夹具：构造"引用缺失文件 + 缺关键模板"的坏技能，验证 `validate()` 函数会拦

回归失败时，根据 selftest 输出修复。如需深度审查（含 token 估算、shell 卫生、绝对路径检查等），使用 `skill-doctor` 技能——它的静态审查器会扫描本技能并生成详细报告。

---

## 依赖声明

**零外部依赖。** 仅依赖 Windows 自带组件：

- **PowerShell 5.1+**（Windows 内置）：执行所有清理/优化脚本
- **Python 3 标准库**（仅用于验证脚本）：验证技能自身完整性
- **Windows 自带工具**：`cleanmgr`、`pnputil`、`powercfg`、`sc.exe`、`schtasks`、`fsutil`、`reg.exe`、`taskkill`

无需安装任何第三方包。
