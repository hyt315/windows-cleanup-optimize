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
- [ ] 模板新增（`scan-scripts.md` 编号 +1）
- [ ] 踩坑新增（`pitfalls.md` 编号 +1）

## 改动说明

简要描述这次 PR 的内容。

## 复现 / 测试方法

如何验证改动有效。

## 检查清单

- [ ] 我在 `references/pitfalls.md` / `references/scan-scripts.md` 追加了新内容并继续了编号
- [ ] 我没有改动 `references/scan-scripts.md` 已有的 1-15 个模板
- [ ] 我没有改动 `references/pitfalls.md` 已有的 1-58 个条目
- [ ] 我的改动遵守"零伤害"原则
- [ ] 文档示例中的路径用占位符（`<用户名>` / `<自定义安装根>`）
- [ ] 我跑了 `python scripts/selftest.py`，结果通过
- [ ] 如果是新软件专项（卸载流程），已添加 ProcessName/AppData/InstallPath 三项
- [ ] 如果是踩坑条目，已注明"检查方法"或具体避坑代码

## 相关 Issue

链接到相关 Issue。
