<div align="center">

# 🧹 Windows 清理与优化助手 / Windows Cleanup & Optimization Assistant

**零伤害：所有清理走回收站可恢复，每项优化带四级风险标记与回退命令。**

**简体中文 · [English](./README.en.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/windows-cleanup-optimize)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](https://github.com/hyt315/windows-cleanup-optimize/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/windows-cleanup-optimize/actions)
[![Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

</div>

---

## 📖 这是什么？

C 盘红了、开机慢、弹窗广告、后台卡顿——**Windows 清理与优化助手** 是一个 AI Agent Skill，用 **六阶段工作流**（用户画像 → 磁盘清理 → 自启动 → 软件卸载 → 服务优化 → 性能调优）逐层诊断和操作，**所有清理走回收站可恢复，每项优化标四级风险并提供回退命令**，不对电脑造成不可逆伤害。

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🛡️ **零伤害保障** | 清理走回收站（`SendToRecycleBin`），不动系统目录，关键操作前建还原点，每项优化带回退命令 |
| 🔍 **智能用户画像** | 家庭用户 / 开发者 / 游戏玩家 / 笔记本四类，一次画像不重复询问，后续推荐自动适配 |
| 🧹 **流氓软件识别** | 自动识别 360 / 2345 / 弹窗广告类捆绑软件，提供安全卸载方案 |
| ⚡ **深度优化** | 服务精简（遥测、Xbox 等）、内存调优、电源计划、SSD TRIM，全部可回退 |
| 🔄 **数据迁移** | 官方方案优先（应用内迁移/系统重定向/官方配置项），mklink 仅兜底；微信/QQ/浏览器/开发工具专项 |
| 🧩 **自启动彻底化** | 覆盖 Windows 20+ 启动点，Edge/Chrome「先切开关层再删 Run 键」根治"关了还会自启"，推荐官方工具 AutoRuns |
| 📋 **15 个参考手册** | 磁盘清理、软件卸载、服务优化、自启动机制、官方迁移、微信/QQ/钉钉迁移、避坑库等全覆盖 |

---

## 🚀 快速开始

> ✨ **一句话装进 AI Agent**：把下面这段话直接发给你的 AI 助手，它会自动完成安装——
>
> ```text
> 请安装 windows-cleanup-optimize Skill：把 https://github.com/hyt315/windows-cleanup-optimize 克隆到你的 skills 目录（Claude Code：~/.claude/skills/windows-cleanup-optimize/；Cursor：~/.cursor/skills/；Codex/ChatGPT：项目内 .agent/skills/），并确认 SKILL.md、references/、scripts/ 都在。以后我报告「C 盘满了 / 开机慢 / 有弹窗 / 系统卡」时，按 SKILL.md 的流程用六阶段工作流诊断 + 可回退操作。
> ```

然后按平台选择安装方式：

| 平台 | 安装命令 |
|------|----------|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |
| **Codex / ChatGPT** | 项目内 `.agent/skills/windows-cleanup-optimize/`（配合 `agents/openai.yaml`） |
| **通用** | 任意 Agent 的 skills 目录 |

---

## 📥 下载 / 安装

```bash
# HTTPS
git clone https://github.com/hyt315/windows-cleanup-optimize.git

# SSH
git clone git@github.com:hyt315/windows-cleanup-optimize.git

# GitHub CLI
gh repo clone hyt315/windows-cleanup-optimize

# ZIP
# https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip

# 单文件（仅 SKILL.md）
curl -O https://raw.githubusercontent.com/hyt315/windows-cleanup-optimize/main/SKILL.md
```

---

## 📁 文件结构与 15 个参考手册

```
windows-cleanup-optimize/
├── SKILL.md                     # 技能入口（六阶段工作流 + 零伤害安全原则）
├── references/                  # 15 个参考手册（按需加载）
│   ├── scan-scripts.md          # 15 个 PowerShell 扫描/清理/优化标准模板
│   ├── pitfalls.md              # 30+ 条 Windows 清理与优化避坑库
│   ├── startup-audit.md         # 自启动项全面审计与 Edge/Chrome 彻底关闭
│   ├── startup-mechanisms.md    # Windows 20+ 自启动点机制与 AutoRuns 指南
│   ├── bloatware-catalog.md     # 流氓软件/弹窗广告全家桶识别进程库
│   ├── software-uninstall.md    # 软件安全卸载与深层残留清理（WPS/360/钉钉）
│   ├── system-cleanup.md        # Windows 系统级深度清理（更新残留/驱动库等）
│   ├── services-optimization.md # 50+ Windows 服务精简与用户画像推荐
│   ├── memory-optimization.md   # 内存优化、真实泄漏识别与工具辨析
│   ├── performance-tuning.md    # 系统性能调优（电源计划/视觉效果/TRIM）
│   ├── trae-guide.md            # TRAE AI IDE 深度清理与稀疏文件迁移
│   ├── drive-migration-official.md # C 盘大目录迁移全集（官方方案优先决策树）
│   ├── chat-apps-migration.md   # 微信 4.x/QQ NT/钉钉官方迁移与缓存清理
│   ├── mklink-migration.md      # mklink /J 目录联接兜底（官方限制与预检）
│   └── case-study.md            # 真实迁移实战案例库
├── scripts/
│   └── selftest.py              # 深度内容与结构回归测试
├── LICENSE
├── README.md  /  README.en.md  # 双语说明（本文件为中文）
├── CHANGELOG.md
├── .github/                     # Issue/PR 模板 + CI
└── CONTRIBUTING.md / CODE_OF_CONDUCT.md / SECURITY.md
```

---

## ▶️ 快速使用

本技能采用 **六阶段工作流**，首次执行时确认用户画像（家庭/开发者/游戏/笔记本），之后按需进入各阶段：

1. **阶段 0 — 用户画像**：一次画像不重复询问，后续推荐自动适配
2. **阶段 1 — 磁盘清理**：C 盘空间扫描、AppData 缓存清理（走回收站）、大目录分析
3. **阶段 2 — 自启动优化**：开机关机项审计、按需禁用自启动项
4. **阶段 3 — 软件管理**：流氓软件识别、旧软件残留清理
5. **阶段 4 — 服务优化**：可安全禁用的 Windows 服务清单（分四级风险）
6. **阶段 5 — 性能调优**：电源计划、内存、SSD TRIM、视觉效果

> 所有操作前插入 `Checkpoint-Computer` 建还原点；优化项同时给出回退命令；任何模糊判断呈现给用户确认，不擅自处理。

---

## 💬 触发方式

对 AI 说以下任意一类话，即会触发本技能：

- 「C 盘满了」「磁盘空间不足」「帮我清理电脑」
- 「开机慢」「启动项太多」
- 「有弹窗广告」「疑似流氓软件/捆绑软件」
- 「后台有可疑进程」「电脑卡顿」
- 「做个系统调优 / PC tune-up」

## ⚙️ 前置条件

- **Windows 10 / 11**（PowerShell 5.1+ 系统自带，无需额外安装）
- 部分操作（服务优化、驱动相关、建还原点）需要**管理员权限**（UAC 弹窗确认）
- 零第三方依赖：清理走系统回收站 API，不装任何清理类软件

## 📦 输出示例

一次完整流程会产出：

```text
📋 空间扫描报告   —— C 盘 Top 大目录 / 各类缓存可释放量（只读扫描）
🧹 清理执行清单   —— 每一项标注"回收站可恢复"，执行前后空间对比
🚫 流氓软件清单   —— 识别结果 + 安全卸载步骤 + 残留注册表/计划任务清理
⚡ 服务优化表     —— 每项标 ✅LOW / ⚠️MEDIUM / 🔴HIGH / ❌CRITICAL + 对应回退命令
🔄 还原点         —— 关键操作前自动 Checkpoint-Computer，随时系统还原
```

---

## 🤝 贡献 / 反馈

- 报 Bug / 提建议：用仓库的 Issue 模板
- 贡献：见 [CONTRIBUTING.md](CONTRIBUTING.md)，改动前跑 `python scripts/selftest.py`
- 漏洞报告：见 [SECURITY.md](SECURITY.md)（私有漏洞报告，勿走公开 Issue）

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **English version: [README.en.md](./README.en.md)**