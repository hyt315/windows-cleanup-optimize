---
name: windows-cleanup-optimize
description: Diagnoses and cleans up Windows 10/11 PCs - frees C drive space, removes bloatware and pop-up ads, audits startup items, tunes services/memory/performance, and moves large app data to another drive using official methods first. Scans are read-only; every change is previewed, confirmed by the user, logged, and reversible via a generated undo script. Use when the user says things like "C盘满了/C盘红了", "电脑卡/开机慢", "弹窗广告/流氓软件", "卸不干净", "微信/QQ占空间太大", "把软件搬到D盘", "clean up my PC", "disk full", "slow boot". Not for hardware faults, blue screens, malware incident response, macOS/Linux, or reinstalling Windows.
---

# Windows 清理与优化

只读诊断 → 体检卡 → 分档方案 → 用户确认 → 执行并留痕 → 对比验证并给出回退。目标是让用户少花时间、不丢东西。

## 安全底线（任何时候都成立）

1. **诊断只读**：阶段 1 的所有脚本不改任何设置、不删不移任何文件。
2. **先演练、再确认、后执行**：写操作脚本默认只演练（打印"将会做什么、能释放多少"），用户同意后才加 `-Apply`。第一档可以列成清单一次确认、批量执行；第二档按组确认；第三档逐项确认；第四档默认不做。
3. **删除只进回收站**：统一用 `Invoke-WcoRecycle`（模板 7）。它会拒绝以下三种情况，因为这时"移入回收站"会变成永久删除：所在卷没有回收站、回收站设为直接删除、体积超过回收站上限。不用 `Remove-Item` 删用户文件。
4. **改动可回退**：服务、注册表、IFEO 的改动都走 `scripts/lib/Wco.Common.psm1`。它会记下原值，写进 `%TEMP%\wco\session_*\changes.json`，并生成 `undo.ps1`。涉及驱动、服务或系统组件时，先建还原点。
5. **系统目录和安全组件不碰**：`C:\Windows`、`Program Files`、`ProgramData` 只读；不关 Defender、不关 Windows Update、不执行 `/ResetBase`、不清空 `C:\Windows\Installer`。
6. **官方入口优先**：清理先用"设置 › 系统 › 存储 › 清理建议"；迁移先用软件内置的"更改存储位置"、环境变量或 Dev Drive；mklink 只作兜底。
7. **拿不准就问**："疑似残留""可能不用了"都先呈报给用户，不擅自批量处理。

## 工作流

### 阶段 1：只读诊断

0. 开始前用一句话告诉用户：扫描只读、可以照常用电脑、通常几分钟；最好用管理员窗口（会弹 UAC）。真正执行前，再提醒保存手头工作、关掉要清理的软件（微信、浏览器等）。
1. 直接运行 `scripts/full_scan.ps1`。不用先问用户属于哪类画像，脚本会自动反推。报告开头的"运行前检查"列出缺的条件（权限、待重启、还原点未开、C 盘不足 5 GB）和修法，先把这些处理掉再进入执行阶段。
2. 以管理员身份运行最完整。普通权限下，报告开头会写明哪几项数据不全。
3. 用户只问某一个具体问题（比如"微信占了多少""开机为什么慢"）时，跳过全量扫描，只跑对应模板（见下方路由表）。

### 阶段 2：体检卡与分档

先出一张「Windows 分层体检卡」，每层写实测值、基线和判定：

| 层级 | 实测指标 | 基线 |
|---|---|---|
| L1 磁盘 | 各盘剩余空间；可清缓存体积 | C 盘剩余 >20%，或 >30 GB |
| L2 开机 | 开机耗时（T0，事件 100 的平均值）；自启项数 | 和用户自己的前后对比为准 |
| L3 软件 | 命中的捆绑/弹窗软件数 | 0 |
| L4 后台 | 内存占用率；疑似泄漏进程 | 无持续增长的进程 |

再按四档列出处理方案：

| 档 | 风险 | 例子 | 确认方式 |
|---|---|---|---|
| 🟢 第一档 | LOW，可恢复、可再生 | 包缓存、Temp、已装完的更新包 | 清单一次确认，批量执行 |
| 🟡 第二档 | MEDIUM，功能微调 | 卸轻度捆绑软件、关 Xbox 服务、聊天软件缓存 | 按组确认 |
| 🟠 第三档 | HIGH，影响明显 | 电源计划、SysMain、IFEO 静音、Defender 排除、Windows.old | 逐项确认，说明代价 |
| 🔴 第四档 | CRITICAL | 关 Defender、关更新、手删系统库、第三方强卸脚本 | 默认不做 |

排序规则：按"能释放的 GB ÷ 风险"从高到低，先给"先做这 3 件"。收益很小的调优（Nagle、内存清理、视觉效果）只在用户点名时才给。

### 阶段 3：用户选择预设

让用户在三档预设里选一个，或者自己勾选具体项：

- **只清缓存**：只做第一档。
- **标准**：第一档，加上用户确认过的第二档。
- **深度**：在标准的基础上，第三档逐项确认后执行。

### 阶段 4：执行

先演练，把结果给用户看，确认后加 `-Apply` 执行。每个模块怎么做，见路由表里对应的手册。

### 阶段 5：验证与回退

| 模块 | 验证 | 回退 |
|---|---|---|
| 磁盘 | 对比 `(Get-PSDrive C).Free` | 回收站还原 |
| 服务、注册表、IFEO | 复查原值 | 运行 `undo.ps1`（服务会恢复成原来的启动类型，不是一律 auto） |
| 开机 | 再跑一次 T0，对比开机秒数 | `undo.ps1` |
| 迁移 | 软件内显示的新路径；一周后看 C 盘是否回涨 | 见对应迁移手册 |

### 阶段 6：汇报

汇报只写一页，包括：

- 释放了多少空间；
- 开机前后各几秒；
- 改了哪几项；
- `undo.ps1` 在哪里；
- 提醒用户**清空回收站才真正释放空间**。

维护建议只给两条：

- 打开存储感知；
- 每季度跑一次 `full_scan.ps1`。

## 路由表（按用户的问题找手册，用到才读）

| 用户的问题 | 先读 | 模板 |
|---|---|---|
| C 盘满了、系统文件、Windows.old、WinSxS | `references/system-cleanup.md` | T5、T9、T21、T22 |
| 软件缓存、更新包、卸载残留 | `references/scan-scripts.md`（模板索引） | T1–T8 |
| 开机慢、关了还自启 | `references/startup-audit.md`，查不到启动源时读 `references/startup-mechanisms.md` | T0、T10、T19 |
| 弹窗广告、流氓软件、卸不干净 | `references/bloatware-catalog.md`、`references/software-uninstall.md` | T11、T16、T18、T20 |
| 卡顿、后台多、服务、内存、Copilot/Recall | `references/services-optimization.md`、`references/memory-optimization.md`、`references/performance-tuning.md` | T12–T15 |
| 搬到 D 盘（含 Dev Drive） | `references/drive-migration-official.md` | — |
| 微信、QQ、钉钉、企业微信占空间 | `references/chat-apps-migration.md` | — |
| 官方没有迁移方案，只能 mklink | `references/mklink-migration.md`、`references/migration-cases.md` | T6 |
| 遇到异常、深水区（DISM、Installer、VSS、云文件） | `references/pitfalls.md` | — |

脚本的位置：

- 全量扫描：`scripts/full_scan.ps1`
- 模板：`scripts/templates/tNN-*.ps1`
- 公共模块：`scripts/lib/Wco.Common.psm1`
- 易变路径清单（带核实日期）：`data/volatile-paths.json`

## 运行环境

- **系统**：Windows 10/11，Windows PowerShell 5.1 或 PowerShell 7。Windows 10 已于 2025-10-14 停止常规支持，这类用户更不能关更新和 Defender。
- **编码**：所有 `.ps1` 和 `.psm1` 都以 UTF-8 BOM 保存，否则 5.1 读中文会乱码。新增脚本必须照做，`selftest` 会检查。
- **运行方式**：`powershell -NoProfile -ExecutionPolicy Bypass -File <脚本>`。
- **临时文件**：一律写到 `%TEMP%\wco`，不往用户目录里丢。

## 回归测试

- `python scripts/selftest.py`：结构、引用、计数、BOM、易变路径时效、PowerShell 语法。没装 PowerShell 时，语法检查跳过并标 SKIP。
- `Invoke-Pester ./tests`：公共模块的单元测试（回收站预检、留痕、undo 顺序、服务原值）。
- `evals/`：触发评测与行为评测，改动 SKILL.md 后人工或用 Agent 跑一遍。
