# 贡献指南

欢迎为本技能贡献内容。所有贡献都将以 MIT 协议发布。

## 🐛 报告问题

在 GitHub Issues 提出：
- 实际复现命令（如 `Get-Process | Where-Object...`）
- 系统环境（Windows 10/11、PowerShell 版本）
- 期望行为 vs 实际行为

## 📝 提交流程

1. Fork 本仓库
2. 创建分支（`git checkout -b feature/xxx` 或 `fix/xxx`）
3. 同步改动：
   - 新踩坑 → 在 `references/pitfalls.md` 末尾按编号续 +1
   - 新模板 → 在 `references/scan-scripts.md` 末尾按编号续 +1
   - 新软件专项 → 在 `references/bloatware-catalog.md` 或 `references/software-uninstall.md` 对应章节追加
4. 跑 `python scripts/selftest.py`，确保通过
5. 用 Conventional Commits 格式写提交信息（如 `feat: add WPS update killer for v2`）
6. 推送到你的 Fork，发起 PR

## 📋 提交信息格式

参考 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>

<body>

<footer>
```

常用 type：`feat`、`fix`、`docs`、`refactor`、`test`、`chore`

## ✅ PR 检查清单

- [ ] 新增内容有同步编号（pitfalls/scan-scripts）
- [ ] `python scripts/selftest.py` 通过
- [ ] 改动不破坏"零伤害"原则
- [ ] 新增命令标注了需要的权限（HKCU/HKLM/管理员）
- [ ] 文档示例中的路径用占位符（`<用户名>` 或 `<自定义安装根>`）

## 📜 行为准则

详见 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。
