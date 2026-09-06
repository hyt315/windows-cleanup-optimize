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
- AppData 累积的缓存（uv / npm / pnpm / 软件日志 / TRAE / WPS / WorkBuddy / 本地大模型等）
- 软件卸载后残留（注册表、AppData、安装目录、计划任务、服务）
- 自启动项过多，开机慢（支持 WMI 事件订阅持久化常驻与桌面/开始菜单快捷方式劫持深度审计）
- 流氓软件 / 捆绑软件治理与弹窗根治（刚需软件免卸载静音、IFEO 映像劫持阻断弹窗、3 秒活动弹窗进程秒级定位、360 / 2345 等）

**优化类：**
- Windows 服务精简（遥测、Xbox、第三方更新器等可安全禁用的服务，Win11 小组件后台与网络抑制）
- 内存优化（识别真正的内存泄漏进程；批判性看待"内存清理工具"）
- 系统性能调优（电源计划、视觉效果、SSD TRIM、TCP Nagle 协议栈精准调优等）
- 按用户画像定制（家庭用户 / 开发者 / AI 创作者 / 游戏玩家 / 笔记本）

**高级：**
- 自启动"彻底关闭"（Edge/Chrome 启动提升 + 后台模式 + 20+ 隐藏启动点，含 WMI 事件订阅持久化与快捷方式劫持，用官方工具 AutoRuns 一键审计）
- C 盘大目录搬 D 盘：**官方方案优先**（应用内迁移 / 系统重定向 / 官方配置项），mklink 仅作兜底
- 微信 4.x(及3.x孤岛清理)/企业微信/QQ/钉钉/浏览器/开发工具/AI模型/安卓AVD 等大目录的官方迁移到 D 盘

---

## 核心安全原则（零伤害与只读优先保证）

> 本技能**绝不永久删除**任何用户文件。所有操作遵循「只读优先」与「治理操作须用户授权」原则。

1. **只读排查优先（Zero-Mutation 原则）** — 阶段 1 诊断阶段（`scripts/full_scan.ps1` 与所有探测脚本）均为纯只读排查，绝不擅自修改任何系统配置、绝不删除或移动任何文件，不动任何设置。
2. **治理建议须用户授权** — 所有涉及移入回收站、删除文件、注册表更改、服务禁用、IFEO 映像劫持阻断、目录迁移等破坏性写操作，仅作为针对性治理建议向用户呈报，**须用户明确同意后手动执行（须用户授权）**，绝不擅自越界变更。
3. **所有清理走回收站** — 使用 `SendToRecycleBin`（`Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory`），不用 `Remove-Item`（模板见 `scan-scripts.md` 模板 7），保证 100% 可恢复。
4. **优化项分四级风险** — 每项明确标注 🟢 LOW / 🟡 MEDIUM / 🟠 HIGH / 🔴 CRITICAL。
5. **不动系统目录** — `C:\Windows`、`C:\Program Files`、`C:\ProgramData` 默认只读扫描；卸载残留需交叉比对且经用户确认后处理。
6. **关键操作前建还原点** — 涉及驱动/服务/系统组件时，执行 `Checkpoint-Computer -Description "BeforeXxx"`。
7. **提供完整回退对策与安全恢复命令** — 每个禁用项/优化项都给出安全恢复与"如何恢复"的完整回退对策。
8. **被锁文件跳过不强制** — 遇到 `IOException` 占用错误时跳过并记录，不中断流程。
9. **优先官方清理命令** — 如 `npm cache clean --force`、`pip cache purge` 等。
10. **清空回收站才算释放** — `SendToRecycleBin` 只是移入回收站，需提醒用户清空才真正释放磁盘。
11. **操作前记录基准** — 清理/优化前先记录目标磁盘剩余空间与指标，结束后对比。
12. **不确定就问用户** — 任何模糊判断（"疑似残留"、"可能不在用"）都呈现给用户确认，不擅自批量执行。

---

## 参考文档矩阵（按需加载）

> 以下详细内容已拆分为独立参考文件，遇到对应场景时 **必须先 Read 对应文件** 再操作，不要凭记忆执行。

| 文件 | 何时阅读 / 覆盖内容 |
|------|-------------------|
| [references/scan-scripts.md](references/scan-scripts.md) | 执行任何扫描/清理/优化时，按编号取对应 PowerShell 模板（1-20） |
| [references/pitfalls.md](references/pitfalls.md) | 遇到异常/边界情况时，先查踩坑记录（含 86 条权威踩坑规避） |
| [references/startup-audit.md](references/startup-audit.md) | 开机慢、自启动多、需要禁用自启（含 Edge/Chrome「彻底关闭」、WMI 常驻与快捷方式审计） |
| [references/startup-mechanisms.md](references/startup-mechanisms.md) | "关了还会自启/找不到怎么启动的"（Windows 20+ 隐藏启动点、WMI 事件订阅持久化 + AutoRuns） |
| [references/bloatware-catalog.md](references/bloatware-catalog.md) | 识别 360、2345、弹窗广告等流氓软件与可疑进程库（含刚需软件 IFEO 静音 SOP 与快捷方式劫持清理） |
| [references/software-uninstall.md](references/software-uninstall.md) | 卸载软件与深层残留清理（含 WPS/钉钉/360 专项清理与活动弹窗进程定位器） |
| [references/system-cleanup.md](references/system-cleanup.md) | 系统级清理（Windows 更新残留、休眠文件、DriverStore 驱动库等） |
| [references/services-optimization.md](references/services-optimization.md) | 服务优化、后台进程多、禁用遥测/Xbox/更新器（50+ 服务按画像分类，含 Win11 小组件与现代后台调优） |
| [references/memory-optimization.md](references/memory-optimization.md) | 内存不足、电脑卡顿（真泄漏识别 + 内存工具 placebo 批判性分析） |
| [references/performance-tuning.md](references/performance-tuning.md) | 性能调优、电源计划/视觉效果/网卡 GUID 级 TCP 调优/Defender 排除列表 |
| [references/trae-guide.md](references/trae-guide.md) | 扫描结果出现 `TRAE SOLO CN` / `.trae-cn` / 用户提到 TRAE |
| [references/drive-migration-official.md](references/drive-migration-official.md) | C 盘大目录搬 D 盘（**官方方案优先决策树**：应用内/系统重定向/配置项） |
| [references/chat-apps-migration.md](references/chat-apps-migration.md) | 微信 4.x/QQ NT/钉钉 占 C 盘、"改了保存位置还涨"（官方迁移+缓存清理） |
| [references/mklink-migration.md](references/mklink-migration.md) | 官方无方案时的 `mklink /J` 兜底（兼容性预检、官方限制、真实失败案例） |
| [references/case-study.md](references/case-study.md) | 执行 mklink 迁移前参考（TRAE 含稀疏文件 / VS Code / 通用三案例） |

---

## 工作流（六阶段）

### 阶段 0：入口选择（首次执行时）

AI 开场白（**首次执行时询问一次，之后不再重复**）：

> 这次扫描你想怎么处理？两个选项：
>
> **🅰️ 全量扫描** —— 一次性扫完所有 20 个模板，自动反推你的用户画像。
> 适合"想给电脑做一次彻底清洁 / 我也不知道哪些该清"的用户。
>
> **🅱️ 画像扫描** —— 先告诉我你属于哪类用户（家庭用户 / 开发者 / 游戏玩家 / 笔记本用户），AI 按画像给定制化的清理/优化建议。适合"我知道自己的方向，只想要针对性结果"的用户。
>
> 直接回 A / B，或者告诉我你想要的。

**两种入口处理流程**：
- **🅰️ 全量扫描** → 直接进入阶段 1，跳过阶段 0.5 画像确认
- **🅱️ 画像扫描** → 进入阶段 0.5 用户画像确认 → 阶段 1

> **为什么分开**：很多用户不是开发者/玩家，就是"想给电脑做一次彻底清洁"。画像应该是**推荐维度**而非**执行阻塞**——把选择权交给用户。

### 阶段 0.5：用户画像（仅🅱️ 画像扫描模式）

明确用户类型，影响后续所有推荐（**一次画像后不重复询问**）：
- **家庭用户**：弹窗广告清理、家庭友好服务优化
- **开发者**：不影响开发工具链（保留 Hyper-V/WSL/Docker/调试服务）
- **游戏玩家**：高性能电源、GPU 相关优化、游戏平台数据迁移
- **笔记本用户**：注重续航，不推荐禁用电源管理类服务

---

### 阶段 1：全面诊断（只读扫描）

**🅰️ 全量扫描模式**：直接调用 `scripts/full_scan.ps1`，一次性跑完所有 20 个模板（详见 `references/scan-scripts.md` 模板 0）。**不再分步执行各模板**。

**🅱️ 画像扫描模式**：按顺序执行只读扫描，摸清系统全貌（PowerShell 脚本保存为 `.ps1` 文件执行）：

1. **磁盘基准与分区**：运行 `scan-scripts.md` 模板 9（`Get-PSDrive`）记录空间基准。
2. **用户目录分层扫描**：调用 `scan-scripts.md` 模板 1（`Scan-Directory`）扫描 Profile 各层（Local / Roaming / Programs）。
3. **常见大缓存与更新包**：运行 `scan-scripts.md` 模板 5 扫描更新包残留（`electron-updater` 等）。
4. **软件卸载残留比对**：运行 `scan-scripts.md` 模板 3（`installedLower` 注册表与快捷方式交叉比对）与模板 4（安装目录残留）。
5. **非系统盘扫描**：对 D/E 盘调用 `scan-scripts.md` 模板 2（`Scan-NonSystemDrive`）。
6. **自启动项与后台进程**：调用 `startup-audit.md` 审计脚本输出报告，结合 `bloatware-catalog.md` 比对进程。
7. **服务与内存压力**：参考 `services-optimization.md` 和 `memory-optimization.md` 记录服务及内存基线。

---

### 阶段 2：四档风险分级与汇总

**🅰️ 全量扫描模式**额外执行"画像自动反推"——根据扫描发现自动给出画像标签：

| 画像标签 | 触发条件（任一）|
|---|---|
| 🏠 家庭用户 | 装了 WPS / 360 / 2345 / 腾讯管家等 |
| 👨‍💻 开发者 | 装了 Docker Desktop / WSL / VS Code / JetBrains / 任意 AI IDE |
| 🤖 AI创作者/虚拟化 | 装了 Ollama / HuggingFace / ModelScope / Android AVD / WSL2 / Docker |
| 🎮 游戏玩家 | 装了 Steam / 暴雪 / GeForce Experience / 任意 Game Bar 服务 |
| 💼 办公用户 | 装了 Office / 钉钉 / 飞书 / 企业微信 |
| 💻 笔记本/OEM | 系统制造商电源计划（Acer/Lenovo/Dell 等 OEM 方案）|

每个画像给出该画像**专属的优化建议**（如家庭用户重点是弹窗广告清理，开发者重点是保留 Hyper-V/WSL/Docker）。

将扫描发现自动归类呈报：

| 档位 | 级别 | 含义 | 处理策略 |
|------|------|------|----------|
| 🟢 **第一档** | LOW | 零风险，可恢复 | 默认推荐自动执行（包缓存、Temp、更新包残留） |
| 🟡 **第二档** | MEDIUM | 轻度风险 / 部分功能微调 | 用户确认后执行（卸轻度 bloatware、关 Xbox 服务） |
| 🟠 **第三档** | HIGH | 中度风险 / 显著功能影响 | **逐项确认**（改电源计划、视觉效果、禁用 SysMain） |
| 🔴 **第四档** | CRITICAL | 破坏性或安全风险 | 默认不动（关 Defender、关 Windows Update、手删系统库） |

### 标准交付成果：Windows 分层体检事实卡 (Fact Card)

在完成阶段 1 只读排查后，必须向用户出具标准格式的「Windows 分层体检事实卡」，用确凿客观指标说话：

| 层级 | 检查项 (Metric/Item) | 测量实值 (Value) | 正常基线 (Baseline) | 状态判定 (Status) |
|---|---|---|---|:---:|
| L1 磁盘与缓存 | C 盘可用容量与 AppData 缓存体积 | 实测指标 (如 14.2GB 可用 / 21GB 缓存) | 剩余空间 >20% 且 冗余缓存 <10GB | 🟢 正常 / 🔴 空间告急 |
| L2 自启动与驻留 | 自启动项总数与 WMI 事件持久化常驻 | 实测指标 (如 自启 18 项 / 零隐蔽 WMI) | 自启 <10 项 且 零隐蔽 WMI 常驻 | 🟢 正常 / 🟡 冗余偏多 |
| L3 软件与弹窗 | 疑似捆绑流氓软件数与活动弹窗进程 | 实测指标 (如 命中 2 款已知弹窗软件) | 零流氓捆绑 且 弹窗源头受控 | 🟢 正常 / 🔴 弹窗骚扰 |
| L4 服务与内存效能 | 真实内存泄漏进程与无用后台常驻服务 | 实测指标 (如 内存使用率 68% / 0 泄漏) | 内存水位健康 且 无异常常驻服务 | 🟢 正常 / 🟡 待精简 |

【确凿定位根因】基于各层测量实值定位系统迟滞或空间爆满核心瓶颈。  
【针对性治理建议（须用户明确同意后手动执行）】根据四档风险分级列出治理措施，并附带完整回退命令。

---

### 阶段 3：用户确认（关键控制点）

向用户呈现清晰的分级报告与预计释放空间，让用户明确选择清理/优化范围：
- "只清理（不优化）" / "只优化（不清理）" / "清理 + 优化（全部）" / "先不操作"
- 若涉及第三档项，必须逐项列出影响并获得明确授权。

---

### 阶段 4：分模块执行

按用户选择，调用对应手册的安全执行流程：
- **磁盘清理**：使用 `scan-scripts.md` 模板 7（`SafeRecycle`）移入回收站，遇到占用自动跳过。
- **自启动清理**：按 `startup-audit.md` 执行（Edge/Chrome 按"先切开关层，再清 Run 键"防复发）。
- **软件卸载**：按 `software-uninstall.md` 规范卸载并清理残留。
- **服务优化**：按 `services-optimization.md` 执行服务禁用（`sc config <svc> start= disabled`）。
- **性能调优**：按 `performance-tuning.md` 调整电源计划与系统参数。
- **数据迁移**：按 `drive-migration-official.md` 四步决策树执行（官方迁移优先，`chat-apps-migration.md` 治聊天软件，`mklink-migration.md` 兜底）。

---

### 阶段 5：验证与回退

每个模块执行后立即对比基准，并准备好回退命令：

| 模块 | 验证方法 | 快速回退命令 |
|------|----------|-------------|
| 磁盘清理 | `(Get-PSDrive C).Free` 对比 | 回收站恢复 |
| 自启动 | `Get-ScheduledTask` / 注册表复查 | 重新启用 Run 项 / 任务 |
| 服务优化 | `Get-Service <svc>` | `sc config <svc> start= auto` |
| 性能调优 | `powercfg /getactivescheme` | `powercfg /setactive <原 GUID>` |
| 数据迁移 | 官方 UI 路径与磁盘大小复查 | 恢复旧目录 / 删除 junction |

---

### 阶段 6：汇报与长期维护建议

1. 输出最终汇报：释放空间量、禁用的自启动项与服务数、已建还原点。
2. 提供最小维护习惯：每周清回收站、每月跑一次诊断、每季度检查自启、避免来源不明软件。

---

## 回归测试与依赖

- **回归测试**：改动技能后执行 `python scripts/selftest.py`（零外部依赖，仅 Python 3 标准库，验证结构与深度内容断言）。
- **零外部依赖**：`scripts/` 仅使用 Python 3 标准库；系统执行依赖 Windows 10/11 内置 PowerShell 5.1+ 及自带命令行工具（`cleanmgr`, `pnputil`, `powercfg`, `sc.exe`, `schtasks`, `fsutil`, `reg.exe`），无需安装任何第三方包或第三方清理软件。
