<p align="center">
  <img src="assets/banner.svg" alt="Windows Cleanup & Optimize Banner" width="100%" />
</p>

# 🧹 Windows 清理与优化助手 / Windows Cleanup & Optimization Assistant

<div align="center">

**先只读诊断、再分档给方案的 Windows 清理技能：14 份参考手册，22 个脚本模板。每个改动都先演练、经你确认才执行、自动留痕，并生成一键回退脚本。**

**Read-only diagnosis first, then a tiered plan: 14 reference manuals and 22 script templates. Every change is previewed, applied only after you confirm, logged, and reversible through a generated undo script.**

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

---

## ✨ 核心特性

| 核心模块 | 覆盖功能 | 带来价值 |
|---|---|---|
| **🛡️ 可回退的安全保障** | 写操作默认只演练，加 `-Apply` 才执行；改动写入 `changes.json` 并自动生成 `undo.ps1`；服务恢复成原启动类型 | 每一步都能看清、能撤回 |
| **🗑️ 真正可恢复的删除** | 删除只进回收站；遇到以下三种情况拒绝执行：无回收站的卷（U 盘、网络盘）、回收站设为直接删除、体积超过回收站上限 | 避免"以为进了回收站，其实永久删了" |
| **🔍 一个扫描入口** | `full_scan.ps1` 一次跑完全部只读模板，自动反推用户画像（家庭 / 开发者 / AI / 游戏 / 笔记本）；检测管理员权限；实测开机耗时 | 不用先回答问题，扫完直接出体检卡 |
| **🧹 流氓软件与弹窗根治** | winget 盘点卸载、IFEO 弹窗静音、3 秒定位弹窗进程、WMI 持久化与快捷方式劫持审计；360 / 2345 / WPS 专项（官方卸载优先） | 治标也治本 |
| **🤖 开发者与 AI 环境换盘** | Dev Drive 放包缓存（npm / pip / NuGet / Cargo / Gradle）；Ollama、Hugging Face、ModelScope、uv、Android AVD 环境变量迁移；WSL2 稀疏磁盘缩容 | 腾出几十 GB，而且不用关 Defender |
| **⚡ 深度优化与 Win11 适配** | 50+ 服务按画像精简；Win11 小组件和 WebView2 抑制；Copilot / Recall 开关；网卡级 TCP 调优；SSD TRIM | 只推荐有实测收益的项目 |
| **🔄 官方原生数据迁移** | 先用 Windows "清理建议"与存储感知；微信 4.x / 企业微信 / QQ NT / 钉钉走应用内迁移；`mklink` 只作兜底 | 不破坏软件升级机制 |
| **📋 14 份参考手册** | 磁盘清理、Windows.old、软件卸载、服务精简、自启动机制、聊天软件迁移，86 条踩坑加一组深水区官方基线 | Agent 按问题只读需要的那一份 |

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
       回收站预检 / 服务与注册表记原值 / 关键操作前建还原点
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
# 以管理员身份打开 PowerShell，进入仓库目录
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\full_scan.ps1   # 只读扫描，报告在 %TEMP%\wco
python scripts/selftest.py                                                    # 结构 / 计数 / BOM / 语法自测
Invoke-Pester ./tests                                                         # 公共模块单元测试（需 Pester 5+）
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
4. **改动可回退**：服务、注册表、IFEO 的改动都记下原值，并生成 `undo.ps1`；动驱动或系统组件前先建还原点。
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
| 📑 [**扫描脚本索引 (`scan-scripts.md`)**](references/scan-scripts.md) | 22 个模板各做什么、何时用；代码在 `scripts/templates/` | 执行具体检测与清理时 | 2 分钟 |
| 🛡️ [**避坑指南 (`pitfalls.md`)**](references/pitfalls.md) | 86 条实战踩坑，加深水区官方基线（DISM、Installer、VSS、云文件） | 制定方案前必查 | 5 分钟 |
| 🚀 [**自启动审计 (`startup-audit.md`)**](references/startup-audit.md) | 自启动项审计，Edge / Chrome 启动加速与后台模式的策略级关闭 | 治理开机慢时 | 3 分钟 |
| 🧩 [**自启动机制 (`startup-mechanisms.md`)**](references/startup-mechanisms.md) | 20+ 个自启动点的原理，WMI 持久化，AutoRuns 用法 | 排查顽固启动项时 | 3 分钟 |
| 🧹 [**流氓软件识别库 (`bloatware-catalog.md`)**](references/bloatware-catalog.md) | 360 / 2345 / 搜狗 / 百度等软件的进程特征，IFEO 弹窗静音 | 查杀弹窗广告时 | 3 分钟 |
| 🗑️ [**软件安全卸载 (`software-uninstall.md`)**](references/software-uninstall.md) | winget 盘点、深层残留清理、WPS / 360 / 钉钉专项（官方卸载优先） | 卸载软件时 | 4 分钟 |
| 💾 [**系统深度清理 (`system-cleanup.md`)**](references/system-cleanup.md) | 官方"清理建议"优先、Windows.old、cleanmgr、DISM、驱动库、休眠文件 | 腾 C 盘空间时 | 4 分钟 |
| ⚙️ [**服务精简指南 (`services-optimization.md`)**](references/services-optimization.md) | 50+ 服务按画像精简，Copilot / Recall 开关，记原值回退 | 优化后台时 | 4 分钟 |
| 🧠 [**内存优化 (`memory-optimization.md`)**](references/memory-optimization.md) | 真实内存泄漏识别、内存压缩、工作集分析 | 内存占用偏高时 | 3 分钟 |
| ⚡ [**性能调优 (`performance-tuning.md`)**](references/performance-tuning.md) | 电源计划、视觉效果、TRIM；Defender 排除只作最后手段，优先用 Dev Drive | 提升响应速度时 | 3 分钟 |
| 📂 [**官方大目录迁移 (`drive-migration-official.md`)**](references/drive-migration-official.md) | 迁移决策树，Dev Drive 放包缓存，AI 模型目录的环境变量 | 搬开发与模型目录时 | 4 分钟 |
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
├── manifest.json                     # 技能元数据清单
├── .github/workflows/ci.yml          # Ubuntu + Windows 双平台 CI
├── scripts/
│   ├── full_scan.ps1                 # 一键只读全量扫描
│   ├── templates/                    # 22 个模板（tNN-*.ps1）
│   ├── lib/Wco.Common.psm1           # 回收站预检、留痕、undo 生成
│   └── selftest.py                   # 自动化回归自测
├── data/volatile-paths.json          # 易变路径清单（带核实日期）
├── evals/                            # 触发评测与行为评测
├── tests/                            # Pester 单元测试
└── references/                       # 14 份参考手册
```

---

## ❓ 常见问题 (FAQ)

- **Q: 清理会不会误删我的重要文件？**
  A: 删除只进回收站。没有回收站的盘、回收站设为直接删除、文件超过回收站上限，这三种会变成永久删除的情况，脚本会直接拒绝执行。即便如此，清空回收站前也建议你看一眼。
- **Q: 为什么不帮我关 Defender 或 Windows Update？**
  A: 收益接近零，风险很大。开发者想提速，可以把代码和包缓存放到 Dev Drive，Defender 在上面会自动用性能模式。
- **Q: 微信 4.x / QQ NT 的聊天记录怎么安全迁移？**
  A: 用应用内自带的"存储位置"迁移，不用 mklink。迁完会验证 C 盘不再增长。
- **Q: 改错了怎么办？**
  A: 每次执行都会生成 `undo.ps1`。服务会恢复成原来的启动类型，注册表从执行前导出的备份还原。
- **Q: Windows 10 还能用吗？**
  A: 能用。但 Windows 10 已于 2025-10-14 停止常规支持，更不该关闭更新和安全软件。

---

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。如果这个技能对你有帮助，欢迎在 GitHub 上点个 [Star ⭐](https://github.com/hyt315/windows-cleanup-optimize/stargazers)！

---

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE) 开源。

---

> 🌏 **English: [README.en.md](./README.en.md)**
