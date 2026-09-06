# 更新日志

本项目的所有显著变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

## [1.6.0] - 2026-09-06

### 新增
- **现代开发工具链官方换盘与缓存修剪**（`references/drive-migration-official.md`）：
  - **Python uv**：支持 `UV_CACHE_DIR` 环境变量与 `uv cache prune` / `uv cache clean` 官方命令
  - **Android AVD 模拟器**：支持 `ANDROID_AVD_HOME` 环境变量将数十 GB 虚拟机镜像从 C 盘迁出
  - **ModelScope 魔搭社区**：支持 `MODELSCOPE_CACHE` 环境变量重定向
  - **PyTorch**：支持 `TORCH_HOME` 环境变量模型权重重定向
- **WSL 2.0+ 原生稀疏虚拟磁盘自动缩容**（`references/drive-migration-official.md`）：
  - 支持 Win11 23H2/24H2 原生 `wsl --manage <发行版> --set-sparse true` 稀疏磁盘模式（Linux 内删文件宿主机 VHDX 自动缩容）
  - 保留 `diskpart compact vdisk` 通用离线压缩与 export/import 迁移指南
- **微信 4.0 升级后旧版 3.x 孤岛残留治理**（`references/chat-apps-migration.md`）：
  - 针对升级 4.0 并迁移后旧版 `Documents\WeChat Files` 遗留 30GB~80GB 孤儿目录的痛点，提供 SafeRecycle 安全排查与处置 SOP
  - 补充企业微信（WeCom / WXWork）存储迁移与缓存安全清理指南
- **GitHub 顶级开源工具经验吸收**（`references/software-uninstall.md` + `references/system-cleanup.md`）：
  - 推荐顶级开源项目 **BCUninstaller (Bulk Crap Uninstaller)** 并引入其残余扫描“置信度分级（Confidence Levels）”原则
  - 规范现代驱动清理语法为 `pnputil /delete-driver oemXX.inf /uninstall`
  - 补充 Windows 原生传递优化 Cmdlet `Clear-DeliveryOptimizationCache -Force`
  - 补充系统崩溃转储（`MEMORY.DMP` / `Minidump`）安全清理指导
- **全量扫描脚本升级**（`scripts/full_scan.ps1`）：
  - 新增 `[T5E]` 专项：只读探测本地大模型（Ollama/HF/ModelScope/PyTorch）、uv 缓存、AVD 模拟器与 WSL/Docker VHDX 虚拟磁盘
  - 新增 `-Quick` 快速模式开关
  - 画像反推新增 `🤖 AI创作者/虚拟化用户`

## [1.5.0] - 2026-09-06

### 新增
- **🅰️ 全量扫描入口**（`SKILL.md` 阶段 0 二选一）：
  - 用户首次执行时 AI 询问"全量扫描 vs 画像扫描"，不再阻塞非技术用户
  - 完整流程与开场白模板见 `SKILL.md` 阶段 0
- **全量扫描主脚本**（`scripts/full_scan.ps1` + `references/scan-scripts.md` 模板 0）：
  - 一次性跑完 18 个模板，输出三段式报告（按档位 / 按类型 / 按来源模板）
  - 末尾自动反推用户画像（家庭 / 开发者 / 游戏玩家 / 笔记本）
  - 输出文件：`%USERPROFILE%\full_scan_<timestamp>.txt`
- **Shell 扩展审计升级**（`references/scan-scripts.md` 模板 16）：
  - `$expectedGood` 补充 Win11 新组件：Previous Versions / Portable Devices / CD Burning / ModernSharing / PinTo 等
  - 修复"Win11 系统自带扩展被误判为未知"的实战痛点

### 变更
- **SKILL.md 阶段 0** 拆分为"入口选择（🅰️/🅱️）"和"用户画像（仅🅱️ 模式）"
- **SKILL.md 阶段 1** 增加"🅰️ 全量扫描模式"分支说明
- **SKILL.md 阶段 2** 新增"画像自动反推"小节（仅🅰️ 模式）
- **README.md** 核心特性表更新为"两种扫描入口"（🅰️ + 🅱️）

## [1.4.0] - 2026-09-02

### 新增
- **软件深度治理与常驻服务彻底封杀**（`software-uninstall.md` + `bloatware-catalog.md` + `pitfalls.md` 79-81）：
  - **WPS Office 四层复活链根治**：`UpdateMode=manual` 配置层切断、计划任务连根拔、`wpscloudsvr` 系统服务禁用、防火墙出站阻断与旧插件池清理
  - **百度网盘**：系统常驻守护服务 `YunDetectService` 禁用/删除、`BaiduNetdiskUpdateTask` 计划任务禁用与 AppData 残留清理
  - **迅雷**：`XLServicePlatform` 与 `ThunderNetwork` 后台 P2P 上传守护服务彻底禁用与下载引擎缓存清理
  - **搜狗输入法**：`SogouCloud.exe` 云计算候选与 `SGDownload.exe` 弹窗下载器出站防火墙阻断及更新任务禁用
  - **夸克网盘**：开机常驻守护与临时分片目录治理
- **本地 AI 框架与模型大户迁移**（`drive-migration-official.md`）：
  - **Ollama 本地大模型**：官方原生环境变量 `OLLAMA_MODELS=D:\OllamaModels` 换盘指南（拯救数十 GB C 盘空间）
  - **Hugging Face / PyTorch**：预训练权重缓存环境变量 `HF_HOME=D:\HF_Cache` 迁移指南
  - **Cursor AI IDE**：代码库索引缓存与更新包残留治理
  - **Gradle / Android SDK**：`GRADLE_USER_HOME` 与 `ANDROID_HOME` 重定向
- **微信 4.x / QQ NT / 钉钉深度治理**（`chat-apps-migration.md`）：
  - 微信 4.x `%APPDATA%\Tencent\xwechat` 目录结构与清理口径（`config` 保护、`xplugin` 保留、`log`/`crashinfo` 安全清理）
  - 微信 4.x `xwechat_files` 与 OneDrive 文件夹重定向 Fallback 机制解析与探测脚本
  - QQ NT 版（v9.9+）确切设置路径（「设置 → 存储管理」聊天记录迁移与「设置 → 文件管理」接收文件保存位置）
  - 钉钉 PC 缓存支持与范围（文件存储换盘、应用内缓存清理，禁止整体搬移 `%LOCALAPPDATA%\DingTalk_91`，提供 `AlibabaProtect` 残留服务提权清理命令）
- **Win11 24H2 系统特性与避坑**（`system-cleanup.md` + `pitfalls.md` 82-84）：
  - Windows 11 24H2 “8.63 GB 更新清理显示残留” 官方计算显示 Bug 误报提醒（严禁强删 WinSxS）
  - BitLocker 全盘加密前置检测（`manage-bde -status C:`）与 48 位恢复密钥备份提醒
- **扫描模板库扩充至 18 个模板**（`scan-scripts.md`）：
  - 模板 17：本地 AI 框架与大模型缓存探测（Ollama/HuggingFace/Cursor/Gradle）
  - 模板 18：顽固后台常驻服务与守护进程深度审计（百度网盘/迅雷/搜狗/WPS）
- **自启动审计与 AutoRuns 升级**（`startup-mechanisms.md` + `startup-audit.md`）：
  - 补充 AutoRuns `-accepteula` 与 `-vt` VirusTotal 首次交互同意实操提示
  - 补充 Edge 中文策略名（「启用启动增强」）与 UI 界面名称（「启动提升」）映射表
- **selftest.py 深度内容断言增强**（`scripts/selftest.py`）：
  - 新增深度内容级断言（自动验证自启策略关键词、微信 4.x 目录、官方迁移限制与决策树存在性）

### 改进
- **SKILL.md 精简重构**：将冗长脚本抽离至 `scan-scripts.md`，主入口行数从 525 行优化至 158 行，提升 Agent 读取效率并消除规范告警（通过 skill-doctor 全部 37 项体检）
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
