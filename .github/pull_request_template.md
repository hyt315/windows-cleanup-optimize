# 提交说明

## 改动类型

请勾选适用的类型：

- [ ] 修复 Bug（修复 issue #___）
- [ ] 新增功能
- [ ] 重大变更（破坏现有功能的修改）
- [ ] 文档更新
- [ ] 重构（无新功能）
- [ ] 性能改进
- [ ] 测试相关
- [ ] 模板新增（`scripts/templates/tNN-*.ps1` + `scan-scripts.md` 说明，`EXPECTED_TEMPLATE_COUNT` +1）
- [ ] 踩坑新增（`pitfalls.md` 编号 +1）

## 改动说明

简要描述这次 PR 的内容。

## 复现 / 测试方法

如何验证改动有效。

## 检查清单

- [ ] 新模板继续了编号；新踩坑放进对应章节，编号保持连续，引用旧编号的地方已同步
- [ ] 新增或修改的 `.ps1` / `.psm1` 以 **UTF-8 BOM** 保存
- [ ] 写操作走 `scripts/lib/Wco.Common.psm1`（默认演练、`-Apply` 执行、自动留痕可回退）
- [ ] 删除只进回收站；没有新增 `Remove-Item` 删用户文件
- [ ] 改了软件路径，已更新 `data/volatile-paths.json` 的 `verified_at`
- [ ] 文档示例中的路径用占位符（`<用户名>` / `<自定义安装根>`）
- [ ] 我跑了 `python scripts/selftest.py` 和 `Invoke-Pester ./tests`，结果通过（改了 SKILL.md 还按 `evals/README.md` 跑了评测）
- [ ] 如果是新流氓软件特征，已改 `data/bloatware-catalog.json`（含 `confidence`、`sources`、`verified_at`），并同步 `references/bloatware-catalog.md`
- [ ] 如果是踩坑条目，已注明"检查方法"或具体避坑代码

## 相关 Issue

链接到相关 Issue。
