# 🐧 Windows 清理与优化助手 Skill

<div align="center">

**零伤害 Windows 调优技能：清理磁盘、优化服务、卸载残留、迁移大目录、审计右键菜单**

**Zero-harm Windows cleanup & optimization Agent Skill: disk, services, bloatware, mklink migration, shell audit**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.0-green.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-SKILL.md-green)](SKILL.md)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

[English](#english) | [中文](#中文)

</div>

---

## 中文

### 📖 这是什么？

一个给 AI Agent（Claude Code / Codex / Cursor 等）用的 Windows 清理与优化技能。遵循 **零伤害原则**——所有清理走回收站可恢复、所有优化项标四级风险并提供回退命令。覆盖中国用户最常遇到的问题：C 盘空间不足、WPS 反复自动升级、开机变慢、流氓软件残留（360/2345/钉钉等）、AI 客户端缓存膨胀。

**核心价值**：不推荐"优化大师"类工具，用官方命令 + 可回退的脚本，真正可逆地解决电脑慢、满、肿。

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🧹 **磁盘清理** | Temp、electron-updater 更新包残留、npm/uv 缓存、AppData 卸载残留，全部走回收站 |
| ⚡ **服务/任务优化** | 50+ Windows 服务按风险分级（遥测/Xbox/第三方更新器），含管理员提权方案 |
| 🔧 **软件残留检测** | 覆盖 Office、QQ、2345、钉钉、360 等的卸载脏数据；**多路径检测**支持非标准安装路径 |
| 📁 **符号链接迁移** | Trae/VS Code/C 盘大目录用 `mklink /J` 迁到 D 盘，逻辑路径不变 |
| 🐕 **WPS 自动升级根治** | 配置(UpdateMode)+任务+服务三层防护，永久防止 ksolaunch 反复重写更新任务 |
| 🔍 **右键菜单审计** | shell 扩展篡改检测 + 已知流氓软件白名单比对（2026-08 新增） |

### 🚀 快速开始

1. 把本技能安装到你的 AI Agent 的 skills 目录（见下方表格）
2. 对它说：**"C 盘红了，帮我清理"** 或 **"WPS 老是自己升级，怎么关"**
3. 技能会自动：只读诊断 → 风险分四档 → 你逐项确认 → 分步执行 → 验证并给出回退命令

### 📥 安装 / Installation

**Skill 项目（AI Agent）——按平台装到对应 skills 目录：**

| 平台 | 安装命令 |
|------|----------|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Codex** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.codex/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |

**下载 / Download：**

| 方式 | 命令 / 链接 |
|------|------------|
| HTTPS | `git clone https://github.com/hyt315/windows-cleanup-optimize.git` |
| SSH | `git clone git@github.com:hyt315/windows-cleanup-optimize.git` |
| GitHub CLI | `gh repo clone hyt315/windows-cleanup-optimize` |
| ZIP 源码 | [下载 ZIP](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip) |
| Tar 源码 | [下载 Tar](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.tar.gz) |
| Release 最新版 | [Releases](https://github.com/hyt315/windows-cleanup-optimize/releases) |

### 📁 文件结构

```
windows-cleanup-optimize/
├── SKILL.md                     # 入口：六阶段工作流 + 零伤害原则 + 四档风险
├── references/                  # 12 个专题文档
│   ├── scan-scripts.md          # 16 个 PowerShell 模板（含 shell 审计模板 16）
│   ├── pitfalls.md              # 66 条实战踩坑
│   ├── bloatware-catalog.md     # 流氓软件清单 + 多路径检测方法
│   ├── software-uninstall.md    # 卸载与残留专项（WPS/钉钉/360）
│   ├── services-optimization.md # Windows 服务分级优化
│   ├── mklink-migration.md      # 符号链接迁移通用指南
│   └── ...                      # 其余 6 个专题
├── scripts/selftest.py          # 技能自检（零依赖）
└── .github/                     # Issue/PR 模板
```

### 🛡️ 核心理念 / Core Philosophy

- **所有清理走回收站**（可恢复）——不用 `Remove-Item`
- **不动系统目录**：`C:\Windows`、`C:\Program Files`、`C:\ProgramData` 默认只读
- **关键操作前可建还原点**（`Checkpoint-Computer`）
- **每个优化项标风险等级 + 完整回退命令**
- **不确定就问用户**，绝不擅自批量执行

### 📚 端到端示例

> "我的 WPS 老是自动升级，还弹窗，怎么彻底关掉？"

技能会按 `software-uninstall.md` 的 WPS 专项执行：
1. **配置层（治本）**：注册表 `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo\UpdateMode` 从 `auto` → `manual`
2. **任务层**：禁用 `WpsUpdateTask_*` / `WpsUpdateLogonTask_*` / `WpsWakeWnsLogonTask`
3. **服务层**：禁用 `wpscloudsvr`
4. 验证三个任务保持 `Disabled`，给用户回退 .reg

### 🤝 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。提交 PR 时请同步：在 `pitfalls.md` 追加踩坑编号 +1、在 `scan-scripts.md` 追加模板编号 +1、跑 `python scripts/selftest.py`。

### 📄 许可 / License

[MIT](LICENSE) © 2026 MiniMax

---

## English

### 📖 What is this?

A Windows cleanup & optimization **Agent Skill** for AI assistants (Claude Code / Codex / Cursor). Built around a **zero-harm guarantee**: every cleanup goes through the Recycle Bin (reversible), every optimization is risk-tiered (LOW/MEDIUM/HIGH/CRITICAL) with a full rollback command. Targets the most common China-market Windows issues: full C:\ drive, WPS auto-update loops, slow boot, bloatware residue (360/2345/DingTalk…), and bloaty AI-client caches.

### ✨ Core Features

| Feature | Description |
|---------|-------------|
| 🧹 **Disk Cleanup** | Temp, electron-updater residue, npm/uv caches, AppData leftovers — all via Recycle Bin |
| ⚡ **Services/Tasks** | 50+ Windows services risk-tiered (telemetry/Xbox/3rd-party updaters), admin-elevation flow |
| 🔧 **Residue Detection** | WPS/QQ/2345/DingTalk/360 uninstall leftovers; **multi-path detection** handles non-standard install paths |
| 📁 **mklink Migration** | Move big C:\ dirs (Trae/VS Code) to D:\ via `mklink /J`, logical path unchanged |
| 🐕 **WPS Update Killer** | Config(UpdateMode)+task+service 3-layer defense against `ksolaunch` re-registering tasks |
| 🔍 **Shell Audit** | Right-click menu tamper detection + bloatware whitelist matching (new 2026-08) |

### 🚀 Quick Start

1. Install the skill into your agent's skills directory (table below)
2. Say: **"My C: drive is full, clean it up"** or **"WPS keeps self-updating, how do I stop it"**
3. The skill will: read-only diagnose → risk-tier into 4 levels → confirm with you → execute step by step → verify & give rollback commands

### 📥 Installation

| Platform | Command |
|----------|---------|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Codex** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.codex/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |

**Download** — HTTPS: `git clone https://github.com/hyt315/windows-cleanup-optimize.git` · SSH: `git@github.com:hyt315/windows-cleanup-optimize.git` · ZIP: [download](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip) · Releases: [link](https://github.com/hyt315/windows-cleanup-optimize/releases)

### 🛡️ Core Philosophy

- All cleanup via Recycle Bin (reversible) — never `Remove-Item`
- Never touch system dirs (`C:\Windows`, `C:\Program Files`, `C:\ProgramData`) by default
- Restore points before critical ops (`Checkpoint-Computer`)
- Every optimization is risk-tiered with a full rollback command
- When unsure, ask the user — never batch-execute silently

### 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). When adding: append pitfall #+1 in `pitfalls.md`, template #+1 in `scan-scripts.md`, and run `python scripts/selftest.py`.

### 📄 License

[MIT](LICENSE) © 2026 MiniMax
