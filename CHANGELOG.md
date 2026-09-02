# 更新日志

本项目的所有显著变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

## [1.3.0] - 2026-09-02

### 新增
- **微信 4.x / QQ NT / 钉钉深度治理**（`chat-apps-migration.md`）：
  - 微信 4.x `%APPDATA%\Tencent\xwechat` 目录结构与清理口径（`config` 保护、`xplugin` 保留、`log`/`crashinfo` 安全清理）
  - 微信 4.x `xwechat_files` 与 OneDrive 文件夹重定向 Fallback 机制解析与探测脚本
  - QQ NT 版（v9.9+）确切设置路径（「设置 → 存储管理」聊天记录迁移与「设置 → 文件管理」接收文件保存位置）
  - 钉钉 PC 缓存支持与范围（文件存储换盘、应用内缓存清理，禁止整体搬移 `%LOCALAPPDATA%\DingTalk_91`，提供 `AlibabaProtect` 残留服务提权清理命令）
- **自启动审计与 AutoRuns 升级**（`startup-mechanisms.md` + `startup-audit.md`）：
  - 补充 AutoRuns `-accepteula` 与 `-vt` VirusTotal 首次交互同意实操提示
  - 补充 Edge 中文策略名（「启用启动增强」）与 UI 界面名称（「启动提升」）映射表
- **selftest.py 深度内容断言增强**（`scripts/selftest.py`）：
  - 新增深度内容级断言（自动验证自启策略关键词、微信 4.x 目录、官方迁移限制与决策树存在性）

### 改进
- **SKILL.md 精简重构**：将冗长脚本抽离至 `scan-scripts.md`，主入口行数从 525 行优化至 150 余行，提升 Agent 读取效率并消除规范告警
- **双语 README 架构完善**（`README.md` / `README.en.md`）：补齐 15 个参考手册的完整架构清单与中英文说明

## [1.2.0] - 2026-09-01

### 新增
- **自启动机制全清单**（`startup-mechanisms.md`）：Windows 20+ 启动点（Run/Winlogon/Active Setup/AppInit/策略 Run/StartupApproved/WMI 等），含微软官方与 MITRE 依据、检出命令、风险分级、**官方工具 AutoRuns 一键审计指南**
- **浏览器「彻底关闭」专项**（`startup-audit.md`）：Edge（启动提升 + 后台模式 + AutoLaunch + 新策略 LaunchEdgeOnWindowsStartupEnabled）与 Chrome（后台模式 + AutoLaunch）的"先切开关层再删 Run 键"完整清单，官方策略/支持页依据，根治"关了还会自启"；**纠偏：Chrome 没有「启动提升」，那是 Edge 的功能**
- **C 盘搬家官方方案优先**（`drive-migration-official.md`）：官方优先决策树 + 系统级（用户文件夹重定向/OneDrive KFM/应用移盘/页面文件/休眠/更新缓存）+ 软件级官方迁移（Steam/Epic/Xbox/浏览器/npm/pnpm/pip/JetBrains/Docker/WSL2/VirtualBox 等），全部带官方来源
- **微信/QQ/钉钉迁移专项**（`chat-apps-migration.md`）：微信 4.x/旧版目录结构对比、官方"更改保存位置"步骤、`%APPDATA%\Tencent\xwechat` 遗留坑、缓存清理、迁移验证
- **mklink 官方限制与失败案例**（`mklink-migration.md`）：微软"从未官方支持 junction 搬 AppData/Folder Redirection 不含 AppData\Local"官方依据、12 类真实失败案例（Chrome App-Bound 闪退/OneDrive 不同步/MSIX/整体搬 AppData/WSL 可移动介质等，均带来源）、兼容性预检清单
- **陷阱 68-78**（`pitfalls.md`）：浏览器复发根因、Chrome 无启动提升、StartupApproved 标记、隐藏启动点、微信 4.x xwechat 残留、OneDrive junction 失效、Chrome App-Bound、迁移后验证三动作

### 改进
- 自启动审计脚本升级：计划任务带触发器标记（Logon/Boot/Event）、新增 StartupApproved 检查节
- 迁移章节改为"官方优先，mklink 兜底"四步决策树（SKILL.md + mklink-migration.md 双重门禁）
- README 核心特性表同步"官方优先迁移"定位

### 修复
- 修正"Chrome 有启动提升"的广为流传的误传
- 修正迁移文档口径：微信/QQ 由"不兼容 mklink"升级为"官方迁移正路 + 遗留清理"

## [1.1.0] - 2026-08-21

### 新增
- **多路径检测方法学**（`bloatware-catalog.md`）：从硬编码路径改为注册表反查 → 多候选根 → 进程路径三步法
- **WPS 反复复活三层防护**（`software-uninstall.md` + `pitfalls.md`）：配置层（UpdateMode=manual）+ 任务层（3 个任务禁用）+ 服务层（wpscloudsvr 禁用）
- **非标准安装路径陷阱**（`pitfalls.md` 59）：记录 2026-08 实战案例 + 解决方案
- **HKCR 通配符陷阱**（`pitfalls.md` 60）：永久记录"不要对 HKCR\* 通配枚举"的教训
- **根目录计划任务权限陷阱**（`pitfalls.md` 62）：某些计划任务修改需要管理员
- **schtasks 隐藏错误陷阱**（`pitfalls.md` 63）：如何捕捉 Access is denied 真实错误
- **诊断脚本污染陷阱**（`pitfalls.md` 64）：脚本应放 $env:TEMP，不要放用户根目录
- **electron-updater 残留扫描模板**（`pitfalls.md` 65）
- **服务/计划任务权限分级处理**（`pitfalls.md` 66）
- **模板 16：右键菜单 / Shell 扩展审计**（`scan-scripts.md`）

### 改进
- WPS 卸载流程加入"注册表反查"和"UpdateMode 治本"步骤
- 增加 2026-08 实战沉淀的"已知良性/未知/待定"三级判定逻辑

### 修复
- 修复 WPS 自动升级被反复复活的根本问题
- 修正 bloatware 目录在非标准路径下被漏检的问题

## [1.0.0] - 早期版本

### 新增
- 六阶段工作流：诊断 → 风险分级 → 用户确认 → 分模块执行 → 验证 → 维护建议
- 13 个 reference 文档，覆盖 disk cleanup / service / task / uninstall / shell audit 等领域
- 16 个 PowerShell 扫描/清理模板
- 60+ 条实战踩坑记录
- 中国流氓软件识别清单
- WPS / 钉钉 / 360 专项卸载流程
