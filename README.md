# Windows 清理与优化助手 Skill

> Windows 调优技能，覆盖磁盘清理、服务/任务优化、软件残留检测、符号链接迁移和 shell 扩展审计。**零伤害原则**——所有操作走回收站可恢复，所有改动可回退，按风险分四档管理。

## ✨ 特性

- 🧹 **磁盘清理**：Temp、更新器残留、electron-updater 缓存、AppData 卸载残留
- ⚡ **服务/任务优化**：三类服务按风险分级、含管理员提权方案、20+ 中国软件专项处理
- 🔧 **软件残留检测**：覆盖 Office、QQ、2345、钉钉、360 等的卸载脏数据
- 📁 **符号链接迁移**：Trae/VS Code/通用模式/C 盘大目录迁 D 盘
- 🔍 **右键菜单审计**：跨用户/系统的 shell 扩展篡改检测（2026-08 新增）
- 🐕 **WPS 自动升级根治**：配置+任务+服务三层防护，永久防止 ksolaunch 重写任务

## 📥 安装

各 AI Agent 平台的 Skills 目录约定不同，下面是常见路径：

```bash
# Claude Code / Codex / 其他主流平台
git clone <repo-url> ~/.claude/skills/windows-cleanup-optimize

# Cursor (项目级)
git clone <repo-url> .cursor/skills/windows-cleanup-optimize

# GitHub CLI
gh repo clone <owner>/windows-cleanup-optimize

# 直接下载 ZIP
# https://github.com/<owner>/windows-cleanup-optimize/archive/main.zip
```

## 🛠️ 使用示例

在 AI Agent 中加载本技能后，让它处理：

- "C 盘红了，帮我清理" → 触发磁盘清理 + 服务优化
- "WPS 自动升级关不掉，怎么办" → 触发 WPS 专项根治
- "我的右键菜单是不是被装了什么流氓软件" → 触发 shell 审计
- "把 .workbuddy 这个大目录从 C 盘挪到 D 盘" → 触发 mklink 迁移

技能会自动：
1. 只读诊断 → 给出方案
2. 风险分档 → 你确认
3. 分步执行 → 全部走回收站/可回退
4. 验证汇报

## 📚 文档结构

| 文件 | 用途 |
|------|------|
| `SKILL.md` | 入口文件：六阶段工作流、安全原则、四档风险分级 |
| `references/scan-scripts.md` | 16 个 PowerShell 模板（按需取用） |
| `references/pitfalls.md` | 60+ 条实战踩坑（执行前必查） |
| `references/bloatware-catalog.md` | 中国流氓软件识别清单 + 多路径检测方法学 |
| `references/software-uninstall.md` | 软件卸载专项流程（含 WPS/钉钉/360） |
| `references/services-optimization.md` | 50+ Windows 服务优化指南 |
| `references/system-cleanup.md` | 系统级清理（更新残留、DriverStore） |
| `references/memory-optimization.md` | 内存优化（含真假泄漏判定） |
| `references/performance-tuning.md` | 性能调优（含电源/视觉/网络） |
| `references/startup-audit.md` | 自启项审计流程 |
| `references/mklink-migration.md` | 符号链接迁移通用指南 |
| `references/case-study.md` | 迁移实战案例（Trae/VS Code/通用） |
| `references/trae-guide.md` | Trae 专项（含稀疏文件处理） |
| `scripts/selftest.py` | 技能自带回归测试 |

## 🛡️ 核心理念：零伤害

- **所有清理走回收站**（可恢复）
- **不动 C:\Windows、C:\Program Files、C:\ProgramData**（除非用户明确授权）
- **关键操作前可建还原点**
- **不确定就问用户**

## 🤝 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。提交 PR 时请同步：

- 在 `references/pitfalls.md` 追加新的踩坑条目（编号续 +1）
- 在 `references/scan-scripts.md` 加新模板（编号续 +1）
- 跑 `python scripts/selftest.py` 通过

## 🔒 安全

发现问题请私下报告，详见 [SECURITY.md](SECURITY.md)。

## 📄 协议

[MIT](LICENSE) © 2026 MiniMax
