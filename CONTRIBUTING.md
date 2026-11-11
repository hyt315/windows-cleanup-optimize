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
   - 新踩坑 → 放进 `references/pitfalls.md` 对应主题的章节，全文编号保持连续；插在中间时顺延后面的编号，并同步改其他文档里引用的编号
   - 新模板 → 代码放 `scripts/templates/tNN-<名字>.ps1`（**UTF-8 BOM**），在 `references/scan-scripts.md` 加一节说明，并把 selftest 里的 `EXPECTED_TEMPLATE_COUNT` 加 1
   - 写操作 → 必须走 `scripts/lib/Wco.Common.psm1`（默认演练、`-Apply` 执行、自动留痕）
   - 改了软件路径 → 同步 `data/volatile-paths.json` 的 `verified_at`
   - 新流氓软件特征 → 改 `data/bloatware-catalog.json`（权威来源，填 `confidence` 和 `sources`，没有官方来源就标 `low`），再同步 `references/bloatware-catalog.md` 的摘要表
   - 新卸载流程 → 在 `references/software-uninstall.md` 对应章节追加
4. 跑 `python scripts/selftest.py` 和 `Invoke-Pester ./tests`，确保通过；改了 SKILL.md 再按 `evals/README.md` 跑一遍评测
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
