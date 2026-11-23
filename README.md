<p align="center">
  <img src="assets/banner.svg" alt="Windows Cleanup & Optimize Banner" width="100%" />
</p>

# 🧹 Windows 清理与优化助手 / Windows Cleanup & Optimization Assistant

<div align="center">

**先只读诊断、再分档给方案的 Windows 清理技能：14 份参考手册，25 个脚本模板，84 条实战避坑。每个改动都先演练、经你确认才执行、自动留痕，并生成一键回退脚本。**

**Read-only diagnosis first, then a tiered plan: 14 reference manuals, 25 script templates, and 84 real-world pitfalls. Every change is previewed, applied only after you confirm, logged, and reversible through a generated undo script.**

[![Version](https://img.shields.io/badge/Version-v2.2.1-10b981)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](CHANGELOG.md)
[![CI](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 这是什么？

C 盘爆红、开机变慢、弹窗屡禁不止、后台卡顿——**Windows 清理与优化助手**是一个给 AI Agent 用的 Windows 10 / 11 治理技能，也可以自己直接运行里面的脚本。

它不走"一键清理"的路子。原则是：

- 先只读扫描，用数字说话；
- 删除只进回收站，并且先确认回收站真能接住；
- 迁移数据优先用官方方案；
- 每一项改动都标风险等级，先演练、经你确认才执行，并留下回退脚本。

## 🆕 最新版本 v2.2.1（2026-11-23）

这一版重点把「不误删、不误判、改错了能撤回」用测试做实，并补强网络代理二进制残留、多网关抢占与系统启动报错等隐蔽问题的只读定位能力。

- **undo 真的会告诉你有没有还原成功**：`undo.ps1` 逐步执行并检查结果，某一步失败（比如没用管理员窗口）会继续执行其余步骤，最后列出失败项并以退出码 1 结束；可重复运行。
- **Windows 验证与 CI 写操作闭环**：补齐 Windows PowerShell 5.1 与 PowerShell 7 双环境验证及 HKCU 可逆闭环测试；CI 的 Windows runner 上进一步对注册表值、IFEO、注册表整键删除、服务启动类型与删除、计划任务停用与删除、启动项开关做「执行 → undo → 逐字对比」。
- **网络、单连接代理与启动报错诊断深化（T23 / T24 / 避坑 83–84）**：T23 新增 `Connections` 二进制单连接与拨号项 `byte[8]` 代理标志审计（排查 `ProxyEnable=0` 但关代理/次日开机仍断网）、多物理网卡默认网关竞争（桥接光猫假网关抢占致设置页转圈）与管理员 TCP 静态排除端口段检查；T24 新增 `Run` 键与登录计划任务重复自启通道检测，并关联近 7 天 SCM 启动报错（Event `7000`/`7023`/`7026`）。
- **误判修复**：名称规范化不再用 `\b`（对汉字无效），「微信4.1.0.34」「钉钉v7.6.5」「QQ9.9.15」能正确对上已安装程序；全量扫描的流氓软件段改用特征库原样规则并标出置信度，不再把低置信度家族和百度网盘、美图这类常用软件一律标 ⚠️。
- **回收站多一道防线**：路径途经 junction 时拒绝移入回收站（实际所在卷可能不是盘符那个，策略无法确认）。
- **负对照**：逐条关掉 39 处安全检查，每一处都有测试会失败；文档里的模板数、手册数、避坑条数、家族数和函数名由自测自动核对。
- **时效更正（核实于 2026-11-23）**：Recall 快照库路径更正为 `CoreAIPlatform.00\UKP\{GUID}`；WSL `--compact` 稳定版 3.0.1 起可用；NTFS 访问时间默认是「系统管理」；Win11 26H2 已发布；企业微信、`Weixin.exe` 等改为有官方出处。完整列表见 [CHANGELOG.md](CHANGELOG.md)。

v2.2.0 及更早的主要能力沉淀：

- **Win32 原生极速扫盘、代理死端口与虚拟网卡排查、孤儿自启/服务/驱动与 `StartupApproved` 幽灵检出、2025–2026 AI 工具缓存覆盖**（v2.2.0）。

- **流氓软件与可回退卸载**：特征库 `data/bloatware-catalog.json` + 程序盘点 T25 + `Invoke-WcoUninstall` / `Remove-WcoAppxPackage` / `Find-WcoLeftover`（服务/任务/注册表删前导出备份、可用 `undo.ps1` 还原；残留名称比对一律只标 🟡 疑似）。
- **Autoruns 级扩展自启动与浏览器劫持审计**：T24 覆盖 RunOnceEx、Winlogon、IFEO/SilentProcessExit、AppInit、LSA、Winsock、隐藏任务、WMI 订阅、非微软驱动等 16 类启动点；T23 审查浏览器策略、强制扩展、代理/hosts/DNS/根证书。
- **扫描可靠性与统一口径**：全量扫描输出 `[CHK]` 分段执行状态（出错标 ⚠️，不把失败当干净）；体积统计统一走 `Measure-WcoDirectory`，不跟随 junction 重复计数。

---

## ✨ 核心特性

| 核心模块 | 覆盖功能 | 带来价值 |
|---|---|---|
| **🛡️ 可回退的安全保障** | 写操作默认只演练，加 `-Apply` 才执行；改动写入 `changes.json` 并自动生成 `undo.ps1`；服务恢复成原启动类型 | 每一步都能看清、能撤回 |
| **🗑️ 真正可恢复的删除** | 删除只进回收站；遇到以下三种情况拒绝执行：无回收站的卷（U 盘、网络盘）、回收站设为直接删除、体积超过回收站上限，超长路径报 `LongPath` | 避免"以为进了回收站，其实永久删了" |
| **🔍 一个扫描入口** | `full_scan.ps1` Win32 原生高速跑完全部只读诊断（含 `[EXT]` T23–T25 摘要与 `[CHK]` 分段健康检查），自动反推用户画像（家庭 / 开发者 / AI / 游戏 / 笔记本） | 不用先回答问题，扫完直接出体检卡 |
| **🧹 流氓软件与孤儿残留识别** | 64 个家族特征库按发布者 / 签名 / 进程 / 服务 / 任务 / 驱动匹配；浏览器策略、`Connections` 二进制代理、多网关/TCP 排除端口审计；`StartupApproved` 幽灵、重复自启与 SCM 启动报错关联；IFEO 弹窗静音、3 秒定位弹窗进程 | 卸完有复扫打分核对，残留清理可回退 |
| **🤖 2026 开发与 AI 环境治理** | Dev Drive 放包缓存 + npm/pnpm/uv/pip/NuGet/Go/Docker 官方 CLI 清理矩阵；2025–2026 主流 AI IDE & Agent 缓存及 Ollama/HF/AVD/LM Studio 迁移；WSL2 磁盘压缩（`wsl --manage --compact`） | 腾出几十 GB，而且不用关 Defender |
| **⚡ 深度优化与 Win11 24H2+ 适配** | 50+ 服务按画像精简；Win11 小组件调优；Copilot / Recall（快照库）开关与检测；虚拟网卡路由/跃点数、多网关假网关与无线电池节能排查；平衡电源计划 + SSD TRIM | 每项注明官方依据和代价，没依据的标「存疑」 |
| **🔄 官方原生数据迁移** | 先用 Windows "清理建议"与存储感知；微信 4.x / 企业微信 / QQ NT / 钉钉走应用内迁移；`mklink` 只作兜底 | 不破坏软件升级机制 |
| **📋 14 份参考手册** | 磁盘清理、Windows.old、软件卸载、服务精简、自启动机制、聊天软件迁移，84 条按主题归类的避坑 | Agent 按问题只读需要的那一份 |

---

## 📊 六阶段全流程架构

```
[输入: 用户报告 C 盘爆满 / 开机慢 / 系统卡顿 / 弹窗]
                          │
       [阶段 1: 只读诊断]
       full_scan.ps1 全量扫描 / 自动反推画像 / 权限检测 / 开机耗时实测
                          │
       [阶段 2: 体检卡与分档]
       磁盘·开机·软件·后台四层实测值 / 🟢🟡🟠🔴 四档方案
                          │
       [阶段 3: 用户选择预设]
       只清缓存 / 标准 / 深度，或自己勾选
                          │
       [阶段 4: 先演练，确认后执行]
       回收站预检 / 删除前先备份、记原值 / 关键操作前建议建还原点
                          │
       [阶段 5: 验证与回退]
       空间与开机耗时前后对比 / undo.ps1 一键回退
                          │
       [阶段 6: 一页汇报]
       释放多少、改了什么、回退脚本在哪
```

---

## 🚀 快速开始

这是一个标准的 AI Agent Skill，安装到你的 AI 助手后即可使用。

### 方式 A：把一句话发给任意 Agent（最推荐、最通用）

把下面这句话直接复制发给你的 AI 助手，它会自动识别环境，并克隆到正确的技能目录：

> 请安装 windows-cleanup-optimize 技能：克隆 `https://github.com/hyt315/windows-cleanup-optimize` 到你的 skills 目录（如 `~/.claude/skills/windows-cleanup-optimize` 或 `~/.agents/skills/windows-cleanup-optimize`），并确认安装成功。以后我报告「C 盘满了 / 开机慢 / 有弹窗 / 系统卡」时，按 SKILL.md 的六阶段流程处理：先只读诊断，每个改动先演练、经我确认再执行。

### 方式 B：GitHub CLI 2.90+（一行命令）

```bash
gh skill install hyt315/windows-cleanup-optimize windows-cleanup-optimize --agent claude-code --scope user
```

### 方式 C：多平台手动安装

| 平台 | 安装命令 |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Codex** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.agents/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |
| **通用 Agents 目录** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.agents/skills/windows-cleanup-optimize` |

### 方式 D：不用 Agent，自己跑扫描与自测

```powershell
# 以管理员身份打开 PowerShell，进入仓库目录；扫描只读，报告开头会列出缺的条件和修法
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\full_scan.ps1   # 只读扫描，报告在 %TEMP%\wco
python scripts/selftest.py                                                    # 结构 / 计数 / BOM / 语法自测
Invoke-Pester ./tests                                                         # 公共模块单元测试（需 Pester 5+）
python tests/negative_controls.py                                             # 负对照：逐条关掉安全检查，确认测试能抓住
```

---

## 🔒 安全原则

1. **诊断只读**：扫描脚本不改设置、不删文件。CI 会在 Windows 上真跑一遍扫描，对比运行前后的服务、自启动键和电源计划，以此证明扫描不改任何东西。
2. **先演练、再确认、后执行**：
   - 🟢 第一档列成清单，确认一次后批量执行；
   - 🟡 第二档按组确认；
   - 🟠 第三档逐项确认，并说明代价；
   - 🔴 第四档默认不做。
3. **删除可恢复**：删除只进回收站；可能变成永久删除的三种情况会被拒绝执行。
4. **改动可回退**：服务、注册表、IFEO 的改动都记下原值，并生成 `undo.ps1`；服务、计划任务、注册表键删除前先导出备份；动驱动或系统组件前建议先建还原点。
5. **官方原生优先**：清理先用系统自带的"清理建议"；迁移先用软件内置功能、环境变量或 Dev Drive；`mklink /J` 只作最后手段。
6. **不碰安全底线**：不关 Defender，不关 Windows Update，不执行 `/ResetBase`，不清空 `C:\Windows\Installer`。

---

## 📥 下载与获取

| 方式 | 命令 / 链接 |
|---|---|
| **HTTPS** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git` |
| **SSH** | `git clone git@github.com:hyt315/windows-cleanup-optimize.git` |
| **GitHub CLI** | `gh repo clone hyt315/windows-cleanup-optimize` |
| **ZIP 压缩包** | [下载 ZIP](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip) |
| **Tar 归档** | [下载 Tar](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.tar.gz) |
| **单文件 (SKILL.md)** | `curl -O https://raw.githubusercontent.com/hyt315/windows-cleanup-optimize/main/SKILL.md` |

---

## 📖 14 份参考手册导读

| 参考手册 | 核心内容 | 推荐阅读时机 | 预估耗时 |
|---|---|---|---|
| 📑 [**扫描脚本索引 (`scan-scripts.md`)**](references/scan-scripts.md) | 25 个模板各做什么、何时用；代码在 `scripts/templates/` | 执行具体检测与清理时 | 2 分钟 |
| 🛡️ [**避坑指南 (`pitfalls.md`)**](references/pitfalls.md) | 84 条按主题归类的踩坑（安全底线、删除与权限、误判、自启动、卸载、迁移、性能与代理网络） | 制定方案前必查 | 5 分钟 |
| 🚀 [**自启动审计 (`startup-audit.md`)**](references/startup-audit.md) | 自启动项与 `StartupApproved` 幽灵审计，Edge/Chrome 策略关闭及 `wscript.exe //B` 零黑框守护技巧 | 治理开机慢时 | 3 分钟 |
| 🧩 [**自启动机制 (`startup-mechanisms.md`)**](references/startup-mechanisms.md) | 对照 Autoruns 全类别的自启动点、检查模板与可回退的关闭方式 | 排查顽固启动项时 | 3 分钟 |
| 🧹 [**流氓软件识别库 (`bloatware-catalog.md`)**](references/bloatware-catalog.md) | 360 / 2345 / 搜狗 / 百度等软件与独立安全子组件特征，IFEO 弹窗静音 | 查杀弹窗广告时 | 3 分钟 |
| 🗑️ [**软件安全卸载 (`software-uninstall.md`)**](references/software-uninstall.md) | winget 盘点、深层残留清理、WPS / 360 / 钉钉专项（官方卸载优先） | 卸载软件时 | 4 分钟 |
| 💾 [**系统深度清理 (`system-cleanup.md`)**](references/system-cleanup.md) | 官方"清理建议"、Windows.old、cleanmgr、DISM、驱动库、Win11 24H2 Recall 与开发 CLI 清理矩阵 | 腾 C 盘空间时 | 4 分钟 |
| ⚙️ [**服务精简指南 (`services-optimization.md`)**](references/services-optimization.md) | 50+ 服务按画像精简，Copilot / Recall 开关，记原值回退 | 优化后台时 | 4 分钟 |
| 🧠 [**内存优化 (`memory-optimization.md`)**](references/memory-optimization.md) | 真实内存泄漏识别、内存压缩、工作集分析 | 内存占用偏高时 | 3 分钟 |
| ⚡ [**性能调优 (`performance-tuning.md`)**](references/performance-tuning.md) | 电源计划、视觉效果、TRIM、Dev Drive，以及代理二进制残留/多网卡假网关/TCP 排除端口与无线电池节能排查 | 提升响应速度时 | 3 分钟 |
| 📂 [**官方大目录迁移 (`drive-migration-official.md`)**](references/drive-migration-official.md) | 迁移决策树、Dev Drive 包缓存、Ollama/HF 与 2025–2026 AI IDE/Agent 目录治理 | 搬开发与模型目录时 | 4 分钟 |
| 💬 [**通讯软件迁移 (`chat-apps-migration.md`)**](references/chat-apps-migration.md) | 微信 4.x / 企业微信 / QQ NT / 钉钉的官方迁移与缓存清理 | 清理聊天记录占用时 | 3 分钟 |
| 🔗 [**目录联接兜底 (`mklink-migration.md`)**](references/mklink-migration.md) | `mklink /J` 兜底迁移：官方限制、安全预检、失败案例 | 只能用联接兜底时 | 3 分钟 |
| 📚 [**迁移实战案例 (`migration-cases.md`)**](references/migration-cases.md) | 端到端真实案例，含 TRAE / VS Code 等 AI IDE 专项 | 学习整体思路时 | 4 分钟 |

---

## 📁 文件结构

```
windows-cleanup-optimize/
├── SKILL.md                          # 安全底线、六阶段流程、按问题找手册的路由表
├── README.md                         # 中文说明文档
├── README.en.md                      # 英文说明文档
├── CHANGELOG.md                      # 版本发布记录
├── LICENSE                           # MIT 开源许可证
├── CONTRIBUTING.md                   # 社区贡献指南
├── CODE_OF_CONDUCT.md                # 行为准则
├── SECURITY.md                       # 安全策略
├── PSScriptAnalyzerSettings.psd1     # PSScriptAnalyzer 静态检查规则配置
├── manifest.json                     # 技能元数据清单
├── assets/banner.svg                 # 项目横幅
├── .github/workflows/ci.yml          # Ubuntu + Windows 双平台 CI
├── scripts/
│   ├── full_scan.ps1                 # 一键只读全量扫描
│   ├── templates/                    # 25 个模板（tNN-*.ps1）
│   ├── lib/Wco.Common.psm1           # Win32 高速测体积、回收站预检、留痕、undo 与自启动/卸载
│   └── selftest.py                   # 自动化回归自测
├── data/volatile-paths.json          # 易变路径清单（带核实日期）
├── data/bloatware-catalog.json       # 流氓与独立残留特征库（64 个家族）
├── evals/                            # 触发评测与行为评测
├── tests/                            # Pester 单元测试、Windows 写操作闭环、负对照
└── references/                       # 14 份参考手册（含 84 条避坑）
```

---

## ❓ 常见问题 (FAQ)

- **Q: 清理会不会误删我的重要文件？**
  A: 删除只进回收站。没有回收站的盘、回收站设为直接删除、文件超过回收站上限，这三种会变成永久删除的情况，脚本会直接拒绝执行。即便如此，清空回收站前也建议你看一眼。
- **Q: 为什么不帮我关 Defender 或 Windows Update？**
  A: 收益接近零，风险很大。开发者想提速，可以把代码和包缓存放到 Dev Drive，Dev Drive 受信任且 Defender 实时保护开着时，Defender 会自动对它用性能模式。
- **Q: 微信 4.x / QQ NT 的聊天记录怎么安全迁移？**
  A: 用应用内自带的"存储位置"迁移，不用 mklink。迁完会验证 C 盘不再增长。
- **Q: 改错了怎么办？**
  A: 每次执行都会生成 `undo.ps1`。服务会恢复成原来的启动类型，注册表从执行前导出的备份还原。
- **Q: Windows 10 还能用吗？**
  A: 能用。但 Windows 10 已于 2025-10-14 停止常规支持；个人版扩展安全更新（ESU）到 2027-10-12，可在 Windows 更新页注册。更不该关闭更新和安全软件。

---

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。如果这个技能对你有帮助，欢迎在 GitHub 上点个 [Star ⭐](https://github.com/hyt315/windows-cleanup-optimize/stargazers)！

---

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE) 开源。

---

> 🌏 **English: [README.en.md](./README.en.md)**
