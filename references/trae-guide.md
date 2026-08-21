# TRAE 专项说明

TRAE（原名 TRAE Solo，2026-06-09 改名为 TRAE Work）是字节跳动出品的 AI IDE。改名后 AppData 目录名仍为 `TRAE SOLO CN`，安装包文件名也仍叫 TRAE Solo，属于改名未完成的状态。

## 目录结构（实测数据）

`%APPDATA%\TRAE SOLO CN` 典型占用 ~10 GB（2026-07-30 实测 9,968 MB），内部结构如下：

| 子目录 | 实测大小 | 内容 | 风险档位 |
|--------|---------|------|---------|
| `VMCache` | ~6,037 MB | 沙盒虚拟机镜像文件（随版本更新持续膨胀） | 第二档（可重建，下次启动沙盒时自动重新下载） |
| `ModularData` | ~3,911 MB | AI Agent 工作区数据、沙盒配置、项目上下文 | 第三档（活跃数据，清理后 Agent 历史丢失） |
| `logs` | ~798 MB | 应用运行日志 | 第一档（纯日志，零风险清理） |
| `CachedData` | ~89 MB | V8 编译缓存（同 Electron CachedData） | 第一档（纯缓存，零风险清理） |

此外，用户目录下还有：

| 路径 | 说明 | 风险档位 |
|------|------|---------|
| `$env:USERPROFILE\.trae-cn\snapshots` | 项目快照，社区反馈可达 10-20 GB | 第三档（从 TRAE 设置里清理旧快照） |
| `$env:USERPROFILE\.trae-cn\extensions` | 插件/扩展目录 | 第三档（在 TRAE 内卸载不用的扩展） |

## 清理建议

**立即可清（第一档）：** `logs` 和 `CachedData` 合计约 900 MB，零风险。应用关闭后直接走 `SafeRecycle`，下次启动自动重建。

**可选清理（第二档）：** `VMCache` 约 6 GB（2026-07 实测，随版本更新持续膨胀）。删除后下次使用沙盒功能时会重新下载 VM 镜像，等待时间略长但不影响功能。

**需谨慎（第三档）：** `ModularData` 约 3.9 GB，包含 AI Agent 的工作区数据和项目上下文。清理后 Agent 对话历史、工作区状态会丢失，但 TRAE 本身能正常运行。建议让用户确认后再清。

**快照膨胀：** `.trae-cn\snapshots` 是社区高频吐槽的点，可达 10-20 GB。建议用户从 TRAE 设置界面清理旧快照，或手动删除不再需要的项目快照目录。

**`.trae-cn` 目录（2026-07-30 实测 423 MB）：** 除 snapshots 外还包含 work（261 MB，项目工作区）、builtin（71 MB，内置运行时）、plugins（45 MB）、skills（19 MB）、attachments（18 MB）等。卸载 TRAE 后整个 `.trae-cn` 目录均为残留，可安全清理。

## 迁移到其他盘位（可选）

TRAE 的独立沙盒是进程级隔离（不依赖物理路径），可以通过目录 junction 将 `TRAE SOLO CN` 整体迁移到 D 盘，沙盒行为不受影响。

TRAE 是 mklink 迁移**适用但有特殊陷阱**的典型案例——`VMCache` 子目录包含稀疏文件（虚拟磁盘镜像），必须用混合复制策略（xcopy 主体 + robocopy `/XJ` 补充），否则目标体积会膨胀 2-3 倍。

**完整迁移流程与踩坑记录**见通用指南 `references/mklink-migration.md` 和实战案例 `references/case-study.md`（Case A：TRAE 案例）。
