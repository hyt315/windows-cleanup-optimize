# 更新日志

本项目的所有显著变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

## [1.9.0] - 2026-09-06

### 新增
- **微软官方底层规范与深度清理避坑库（`references/windows-cleanup-optimize-pitfalls.md`）**：
  - **WinSxS 组件存储库与 DISM `/ResetBase` 风险防控**：规范组件存储安全分析与清理流程，严格禁令默认带 `/ResetBase` 参数，防止当前累积更新（LCU）被永久固化、丧失故障回滚能力；
  - **OneDrive / iCloud "文件随选 (Files On-Demand)" 水合雪崩防御**：在递归扫描与大文件排查中加入 `ReparsePoint` 与 `SparseFile` 属性拦截，严禁读取云端占位文件内容，杜绝触发后台强制下载撑爆 C 盘空间；
  - **Windows Installer (`C:\Windows\Installer`) 误删灾难拦截**：明确禁止手动批量删除 `.msi` / `.msp` 注册缓存，防止 Office、Visual Studio、SQL Server 等大型软件陷入无法更新、修复或卸载的永久损坏状态；
  - **卷影副本 (VSS) 与系统还原点防误清**：规范 `vssadmin delete shadows` 调用边界，避免静默清空用户关键系统还原点与“以前的版本”；
  - **CompactOS 原生系统文件无损压缩规范**：规范基于 WOF 驱动的 `compact /compactos:always` 压缩指令，安全稳定释放 2.0GB ~ 4.5GB C 盘空间；
  - **休眠文件 `hiberfil.sys` 瘦身权衡**：推荐使用 `powercfg /h /type reduced` 保留快速启动并缩减 50% 空间，避免盲目关闭导致开机耗时倍增。
- **工作流指令就近内联动作重构与弱引用治理（`SKILL.md`）**：
  - 全面消除流程中“详见/可参考”弱引用措辞，升级为规范的 `👉 动作：先读 [文件]` 就近内联动作指令，确保 Agent 调度时不漏步、不跳步；
  - 将深度清理避坑库无缝挂载至核心安全原则与分模块执行流程中。
- **回归测试套件强化（`scripts/selftest.py`）**：
  - 扩展 `REQUIRED_REFS` 必检清单，新增 `ResetBase`、`ReparsePoint`、`Installer` 缓存等底层避坑要点的深度内容级断言校验。

## [1.8.0] - 2026-09-06

### 新增
- **标准交付成果：Windows 分层体检事实卡 (Fact Card)**：
  - 在 `SKILL.md` 中规范了标准交付成果模版，涵盖 L1 磁盘与缓存、L2 自启动与驻留、L3 流氓软件与弹窗、L4 服务与内存效能四层指标，明确测量实值、正常基线与状态判定，用客观事实说话。
- **只读优先与显式授权安全纪律（Zero-Mutation）**：
  - 在核心原则中明确确立阶段 1 排查完全只读（Zero-Mutation），绝不擅自修改系统配置或移动文件；破坏性治理对策必须经用户明确授权同意后方可手动执行，且提供完整回滚命令。
- **代码级 AST 语法树回归门禁与 Pytest 支持**：
  - `scripts/selftest.py` 引入 `System.Management.Automation.Language.Parser` 对核心扫描器 `scripts/full_scan.ps1` 进行 PowerShell AST 静态语法解析，并引入 Python `ast.parse` 校验；
  - 补充 `tests/test_skill.py` 提供 Pytest 自动化发现与执行入口；
  - 补充针对坏语法与坏破坏样本的负向对抗校验断言。
- **高清矢量横幅与开源元数据补齐**：
  - 新增 `assets/banner.svg` 高清暗色系矢量封面，集成磁盘护盾、性能表盘与零伤害核心特性徽章；
  - 补齐标准 `manifest.json` 技能工程元数据。

## [1.7.0] - 2026-09-06

### 新增
- **刚需软件免卸载“弹窗彻底静音”与 IFEO 阻断技术（`references/bloatware-catalog.md`）**：
  - 针对用户无法卸载但频繁弹窗的国产刚需软件（WPS、搜狗输入法、FlashCenter、好压等），提供基于 Windows 映像劫持（Image File Execution Options, IFEO）的底层拦截方案。
  - 将弹窗专用进程（`wpscenter.exe`、`ksobulletin.exe`、`SGDownload.exe`、`SogouNews.exe`、`FFNewTask.exe`、`HaoZipPopup.exe` 等）通过 Debugger 键值重定向至系统内置静默退出程序 `systray.exe`，彻底切断弹窗拉起，同时保证主程序文字排版、输入打字、解压缩等核心功能完全正常。
  - 配套提供一键静音与一键恢复 PowerShell 脚本。
- **活动弹窗进程秒级定位器（`references/software-uninstall.md` + 模板 20）**：
  - 新增基于 Win32 原生 API（`GetForegroundWindow` / `GetWindowThreadProcessId`）的 3 秒瞬时弹窗归属溯源脚本，用户只需在弹窗弹出时点击窗口，脚本即可精准提取对应进程 ID、进程名、可执行文件完整路径及所属命令行，让伪装无标题弹窗无所遁形。
- **WMI 事件订阅持久化常驻与桌面/开始菜单快捷方式劫持审计（`references/startup-mechanisms.md` + `references/startup-audit.md` + 模板 19）**：
  - 完善自启动机制第 18 类：深度解析流氓软件利用 WMI `CommandLineEventConsumer`、`__EventFilter` 和 `__FilterToConsumerBinding` 在操作系统底层实现无进程、无服务隐蔽常驻的原理，并提供一键检测与协同清理命令。
  - 新增桌面、公共桌面、开始菜单 `.lnk` 快捷方式目标路径与附加参数审计，检测并清洗静默追加的恶意网址、渠道推广号或静默唤醒参数。
- **Windows 11 现代后台与网络传输性能调优（`references/services-optimization.md` + `references/performance-tuning.md`）**：
  - **Win11 小组件与后台 WebView 资源释放**：通过策略配置 `AllowNewsAndInterests = 0` 彻底封冻 `Widgets.exe` 与后台持续驻留的 `msedgewebview2.exe`，释放多余内存与 CPU 占用。
  - **Windows 聚焦后台静音**：抑制聚焦锁屏与后台热点推送在空闲时频繁唤醒网络与磁盘。
  - **TCP 协议栈现代化优化**：补充 Win10/Win11 原生 TCP 自动调谐级别校验（`autotuninglevel=normal`）、CUBIC 拥塞控制算法确认及网卡节能以太网（EEE）延迟规避指南。
- **踩坑记录权威扩充至 86 条（`references/pitfalls.md`）**：
  - 新增第 85 条：TCP Nagle 算法（`TcpAckFrequency`/`TCPNoDelay`）必须写入活动网卡特定的 `Interfaces\{GUID}` 路径，写在全局根路径下为无效空跑。
  - 新增第 86 条：IFEO 映像劫持拦截弹窗时，Debugger 必须指向合法静默宿主（如 `systray.exe`），不可随意填空或不存在的路径，防止系统报错中断或子进程异常循环。

### 修复
- **TCP Nagle 注册表路径缺陷修复（`references/performance-tuning.md`）**：
  - 修正此前将 `TcpAckFrequency` 与 `TCPNoDelay` 写入 `Tcpip\Parameters` 根目录的错误逻辑，改为动态获取当前具备有效 IPv4 默认网关的活动物理网卡 GUID，精准写入 `Tcpip\Parameters\Interfaces\{GUID}`，确保网络协议栈调优真实生效。
- **服务拼写错误修复（`references/services-optimization.md`）**：
  - 修正 `GammingServices` 为官方正确服务名称 `GamingServices`。
- **PyTorch 模型权重缓存路径修正（`references/scan-scripts.md` + `scripts/full_scan.ps1`）**：
  - 修正此前 `$env:LOCALAPPDATA\torch` 探测路径，规范为 PyTorch 官方统一的 `$env:USERPROFILE\.cache\torch`，并同步加入全量扫描模板 17。

### 变更
- **全量扫描脚本升级（`scripts/full_scan.ps1`）**：
  - 模板总数由 18 项扩充至 20 项，集成 `[T19]` WMI 持久化常驻与桌面/开始菜单快捷方式劫持自动审计。
  - 版本号与说明同步升至 `v1.7.0`。
- **自测试套件全面强化（`scripts/selftest.py`）**：
  - 扩展深度内容断言，覆盖网卡 GUID TCP 注册表路径、GamingServices 拼写、Win11 Widgets 优化、IFEO 映像劫持 SOP、Win32 弹窗定位器与 WMI 消费者检查，确保技能知识库的工程严谨度与可验证性。

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
