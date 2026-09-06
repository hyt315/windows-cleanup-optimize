# 🧹 Windows 清理与优化助手 / Windows Cleanup & Optimization Assistant

<div align="center">

**零伤害 Windows 深度清理与系统优化：15 本参考手册、流氓软件彻底根治、大模型原生换盘、每项操作可回退。**

**Zero-harm Windows deep cleanup & performance tuning with 15 reference manuals, bloatware eradication, native AI weight migration, and full rollback protection.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](CHANGELOG.md)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 这是什么？

C 盘爆红报警、开机变慢、流氓弹窗屡禁不止、后台进程卡顿——**Windows 清理与优化助手** 是一个专为 AI Agent 与系统管理员打造的专业级 Windows 深度治理技能。

它摒弃了市面上清理软件“一键暴力误删、破坏注册表、暗带全家桶”的顽疾，遵循 **「用户画像先行、所有清理走回收站可恢复、官方原生换盘优先、每项优化标明四级风险与回退命令」** 的零伤害铁律，彻底治理 Windows 10 / 11 / 24H2 系统环境。

---

## ✨ 核心特性

| 核心模块 | 覆盖功能 | 带来价值 |
|---|---|---|
| **🛡️ 零伤害安全保障** | 清理默认走回收站（`SendToRecycleBin`），关键操作前自动建还原点，优化带回退命令 | 100% 杜绝误删系统文件造成系统崩溃 |
| **🤖 本地 AI 与模型原生换盘** | Ollama（`OLLAMA_MODELS`）、Hugging Face（`HF_HOME`）等大模型权重官方环境变量一键换盘 | 原生释放几十到上百 GB C 盘空间 |
| **🔍 两种扫描入口** | 🅰️ 全量扫描（一键跑完 18 个模板） + 🅱️ 画像扫描（家庭/游戏玩家/开发者/笔记本四类） | 用户自选，非技术用户不被画像阻塞；专业用户拿到定制化建议 |
| **🧹 流氓软件与弹窗根治** | 360 / 2345 / 百度守护 / 迅雷 P2P / 搜狗弹窗 / WPS 四层复活链彻底封杀 | 治标更治本，彻底阻断自启与服务拉起 |
| **⚡ 深度优化与 24H2 适配** | 24H2 更新误报避坑、BitLocker 前置预检、50+ 服务精简、内存调优、SSD TRIM | 毫秒级提升系统响应与开机速度 |
| **🔄 官方原生数据迁移** | 应用内迁移 / 系统重定向优先，微信 4.x / QQ NT / 钉钉专项迁移，`mklink` 仅做兜底 | 稳定合规，绝不破坏软件升级机制 |
| **📋 15 本全景参考手册** | 涵盖磁盘清理、软件卸载、服务精简、自启动机制、微信/QQ 迁移、避坑库等全矩阵 | 深度知识沉淀，AI 调阅判断零失误 |

---

## 📊 六阶段全流程架构

```
[输入: 用户报告 C 盘爆满 / 开机慢 / 系统卡顿 / 弹窗]
                          │
       [Stage 1: 智能用户画像判定]
       家庭用户 / 开发者 / 游戏玩家 / 笔记本设备
                          │
       [Stage 2: 磁盘深度安全清理]
       大文件扫描 / 系统缓存 / AI 权重迁移 / 回收站兜底
                          │
       [Stage 3: 自启动项彻底治理]
       20+ 自启动点 / Edge 策略级锁定 / AutoRuns 推荐
                          │
       [Stage 4: 软件卸载与深层残留清除]
       流氓软件四层链封杀 / 注册表与服务残留清理
                          │
       [Stage 5: 系统服务安全精简]
       基于画像精简 50+ 服务 / 附带完整回退命令
                          │
       [Stage 6: 性能深度调优与验收]
       电源计划 / 内存工作集 / SSD TRIM / 还原点与复盘
```

---

## 🚀 快速开始

这是一个标准的 AI Agent Skill —— 安装到你的 AI 助手后即可直接使用。

### 方式 A：把一句话发给任意 Agent（最推荐、最通用）

把下面这句话直接复制发送给你的 AI 助手，它会自动识别环境并克隆到正确的技能目录：

> 请安装 windows-cleanup-optimize 技能：克隆 `https://github.com/hyt315/windows-cleanup-optimize` 到你的 skills 目录（如 `~/.claude/skills/windows-cleanup-optimize` 或 `~/.agents/skills/windows-cleanup-optimize`），并确认安装成功。以后我报告「C 盘满了 / 开机慢 / 有弹窗 / 系统卡」时，按 SKILL.md 的流程用六阶段工作流诊断 + 零伤害可回退操作。

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

### 方式 D：本地运行回归自测

```powershell
python scripts/selftest.py
```

---

## 🔒 零伤害与安全原则

1. **可恢复性铁律**：所有文件清理优先调用 `SendToRecycleBin` 送入回收站，严禁硬删除未确认文件；
2. **官方原生优先**：大目录迁移必须优先采用应用内自带路径修改或环境变量（如 `HF_HOME`），`mklink /J` 仅作为最后手段；
3. **前置系统保护**：执行注册表或驱动级清理前，自动创建 Windows 系统还原点（System Restore Point）；
4. **回退命令随附**：针对所有服务禁用与注册表调优，必须在方案中同步附带对应的恢复 PowerShell 命令。

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

## 📖 15 本全景参考手册导读

| 参考手册 | 核心内容 | 推荐阅读时机 | 预估耗时 |
|---|---|---|---|
| 📑 [**扫描脚本库 (`scan-scripts.md`)**](references/scan-scripts.md) | 15 个 PowerShell 扫描/清理/优化标准执行脚本 | 执行具体检测与清理时 | 4 分钟 |
| 🛡️ [**避坑指南 (`pitfalls.md`)**](references/pitfalls.md) | 30+ 条 Windows 清理与优化真实避坑库与误报防范 | 制定清理方案前必查 | 4 分钟 |
| 🚀 [**自启动审计 (`startup-audit.md`)**](references/startup-audit.md) | 自启动项全面审计与 Edge/Chrome 策略级彻底关闭 | 治理开机慢与后台自启时 | 3 分钟 |
| 🧩 [**自启动机制 (`startup-mechanisms.md`)**](references/startup-mechanisms.md) | Windows 20+ 自启动点机制解密与 AutoRuns 官方指南 | 深度排查顽固启动项时 | 3 分钟 |
| 🧹 [**流氓软件识别库 (`bloatware-catalog.md`)**](references/bloatware-catalog.md) | 360 / 2345 / 搜狗 / 百度全家桶识别进程特征库 | 查杀弹窗广告与流氓守护时 | 3 分钟 |
| 🗑️ [**软件安全卸载 (`software-uninstall.md`)**](references/software-uninstall.md) | 软件安全卸载与深层残留清理（WPS/360/钉钉） | 卸载软件与清除注册表时 | 3 分钟 |
| 💾 [**系统深度清理 (`system-cleanup.md`)**](references/system-cleanup.md) | Windows 系统级深度清理（更新残留/驱动库/休眠文件） | 深度腾出 C 盘空间时 | 4 分钟 |
| ⚙️ [**服务精简指南 (`services-optimization.md`)**](references/services-optimization.md) | 50+ Windows 服务精简与四大用户画像推荐策略 | 优化后台内存与 CPU 时 | 4 分钟 |
| 🧠 [**内存优化 (`memory-optimization.md`)**](references/memory-optimization.md) | 内存优化、真实泄漏识别与内存压缩工作集分析 | 系统内存占用偏高排查时 | 3 分钟 |
| ⚡ [**性能调优 (`performance-tuning.md`)**](references/performance-tuning.md) | 系统性能调优（电源计划/视觉效果/SSD TRIM/中断） | 提升游戏与响应帧率时 | 3 分钟 |
| 🤖 [**AI IDE 清理 (`trae-guide.md`)**](references/trae-guide.md) | TRAE / VS Code 等 AI IDE 深度清理与稀疏文件迁移 | 开发者 IDE 占用过大时 | 3 分钟 |
| 📂 [**官方大目录迁移 (`drive-migration-official.md`)**](references/drive-migration-official.md) | C 盘大目录迁移全集（官方方案优先决策树与 AI 权重） | 转移大型开发与模型目录时 | 4 分钟 |
| 💬 [**通讯软件迁移 (`chat-apps-migration.md`)**](references/chat-apps-migration.md) | 微信 4.x / QQ NT / 钉钉官方迁移与缓存安全清理 | 清理微信 QQ 几十 G 记录时 | 3 分钟 |
| 🔗 [**目录联接兜底 (`mklink-migration.md`)**](references/mklink-migration.md) | `mklink /J` 目录联接兜底迁移（官方限制与安全预检） | 必须使用硬链接兜底时 | 3 分钟 |
| 📚 [**真实实战案例 (`case-study.md`)**](references/case-study.md) | 多个真实环境从爆红到解救的端到端案例复盘 | 学习整体治理思路时 | 3 分钟 |

---

## 📁 文件结构

```
windows-cleanup-optimize/
├── SKILL.md                          # 核心技能定义与六阶段工作流
├── README.md                         # 中文说明文档
├── README.en.md                      # 英文说明文档
├── CHANGELOG.md                      # 版本发布记录
├── LICENSE                           # MIT 开源许可证
├── .gitignore                        # Git 忽略规则
├── CONTRIBUTING.md                   # 社区贡献指南
├── CODE_OF_CONDUCT.md                # 行为准则
├── SECURITY.md                       # 安全策略
├── SUPPORT.md                        # 支持渠道
├── manifest.json                     # 技能元数据清单
├── agents/                           # 多 Agent 平台元数据
├── scripts/
│   ├── validate_repo.py              # 结构与隐私安全验证器
│   └── selftest.py                   # 自动化回归自测脚本
└── references/                       # 15 本全景参考手册
```

---

## ❓ 常见问题 (FAQ)

- **Q: 清理会不会误删我的重要文件导致系统崩溃？**  
  A: 绝不会。所有文件清理默认送入回收站（可随时撤销），关键操作前自动建还原点，避坑库深度覆盖 30+ 常见误删场景。
- **Q: 微信 4.x / QQ NT 的聊天记录怎么安全迁移？**  
  A: 采用官方应用内自带的存储路径迁移或原生配置项迁移，安全可靠，绝不破坏数据库完整性。
- **Q: 为什么优先使用官方环境变量迁移本地大模型（Ollama/HuggingFace）？**  
  A: 官方环境变量（`OLLAMA_MODELS`、`HF_HOME`）受模型程序原生支持，升级维护更稳定，避免 `mklink` 偶发的权限锁死问题。

---

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。如果这个技能对你有帮助，欢迎在 GitHub 上点个 [Star ⭐](https://github.com/hyt315/windows-cleanup-optimize/stargazers)！

---

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE) 开源。

---

> 🌏 **English: [README.en.md](./README.en.md)**
