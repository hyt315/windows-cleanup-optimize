# 更新日志

本项目的所有显著变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

## [2.1.2] - 2026-11-12

小版本：修残留判定、体积统计和扫描报告里四处与安全底线不符的地方。不新增模板，不改写操作。

### 修复
- **残留不再划进第一档**：full_scan 的 T3（Roaming）和 T4（安装目录）旧版用双向子串匹配判定残留，却标 🟢 第一档，与「疑似残留先呈报、不批量处理」冲突；`Go` 会因 `Google Chrome` 被算成在用，`QQ` 会因 `QQMusic` 被算成在用。现在 T3、T4 模板和 full_scan 共用公共模块的 `Get-WcoInstalledIndex` + `Get-WcoResidualStatus`：先看已安装程序的安装目录和运行中进程，再按规范化名称比对，≤4 个字符的名称只认完全相等；对不上的一律标 🟡「疑似残留」，需人工核对或卸载后用 `Find-WcoLeftover` 打分。
- **体积统计不再钻进 junction**：t01、t02、t03、t05、t17 仍用 `Get-ChildItem -Recurse` 统计体积，Windows PowerShell 5.1 会顺着 junction 走进去，迁到 D 盘的数据被重复算进 C 盘。统一改用 `Measure-WcoDirectory`。
- **`Test-WcoPathUnder` 加根目录保护**：父路径是盘符根（`C:\`、`C:`）或网络共享根时返回 false。此前某个程序的 `InstallLocation` 写成 `C:\`，`Find-WcoLeftover` 就会把任意服务、目录都当成「位于其安装目录下」。该函数现已导出。
- **失败的段不再显示成「未检测到」**：full_scan 全局 `SilentlyContinue` 会吞掉出错的段。现在每段记录新增错误数和耗时，报告新增 `[CHK] 分段执行情况`：无权限、路径不存在只计数；其他异常标 ⚠️「结果可能不全」并给出首条错误。
- `full_scan.ps1` 头注释版本号从 v2.0.1 改为与 manifest 一致。

### 测试与 CI
- 新增 `tests/Wco.Residual.Tests.ps1`：路径包含与根目录保护、残留判定（短名、安装目录、运行中进程、名称规范化、名称比对从不给 🟢）、模板不再用 `-Recurse` 统计体积、full_scan 每段都登记状态。
- Windows CI 的报告标记检查补上 `[EXT]` 和 `[CHK]`。

## [2.1.1] - 2026-11-11

小版本：只修文档与注释里和 v2.1.0 改动对不上的地方，脚本行为不变。

### 修复
- `full_scan.ps1` 头注释仍引用旧编号「踩坑 64」，`pitfalls.md` 重排后应为第 22 条。
- `CONTRIBUTING.md` 仍要求把新踩坑写在「深水区」一节之前，但该节在 v2.1.0 已取消；改为放进对应主题章节并保持编号连续。
- `CONTRIBUTING.md` 与 PR 模板仍按旧做法登记新软件（ProcessName/AppData/InstallPath）；改为以 `data/bloatware-catalog.json` 为准，要求填置信度和来源。

### CI
- 只读检查失败时打印具体变化项（如哪个服务的启动类型变了），便于区分脚本问题和 Runner 自身变动（已随 v2.1.0 标签提交上线，此处补记）。

## [2.1.0] - 2026-11-11

这一版补齐「流氓软件识别、真正卸干净、自启动不漏项」三块，并按微软官方页面（访问于 2026-11-11）修正一批事实错误。无法找到官方依据的内容不改，只标「存疑」。

### 新增
- **流氓软件特征库** `data/bloatware-catalog.json`（schema 1，61 个家族）：按发布者、签名、进程、服务、计划任务、驱动、商店应用、目录线索匹配；每个家族标风险类型、置信度和来源。缺少可核对来源的标 `low`，命中只算「疑似，需实机确认」。不收录 Windows 组件、WebView2 和运行库；OEM 工具默认保留。
- **T23 浏览器劫持审计**（只读）：浏览器策略（主页、启动页、搜索、强制安装扩展）、Firefox 策略、Native Messaging、快捷方式参数、WinINet / WinHTTP 代理与 PAC、hosts、DNS、近 180 天新增的根证书（只提示人工确认，不下结论）。
- **T24 扩展自启动审计**（只读）：对照 Autoruns 类别补齐 RunOnceEx、策略 Run、Winlogon Shell/Userinit、IFEO Debugger 与 SilentProcessExit、AppInit_DLLs、文件关联劫持、Active Setup、BootExecute、LSA 包、打印监视器、Winsock、隐藏计划任务、WMI 订阅、非微软驱动、Win11「重启后恢复应用」、Edge 启动加速、商店应用 StartupTask。
- **T25 程序盘点**（只读）：已装程序与商店应用对照特征库，按「签名/发布者 → 进程/服务/任务 → 仅名称」分高、中、低三档给证据和下一步命令；≤4 个字符的名称不做模糊匹配。
- **公共模块新增写操作**（默认只演练，`-Apply` 才执行，全部留痕并写入 `undo.ps1`）：`Set-WcoStartupApproved`、`Disable-WcoScheduledTask`、`Remove-WcoScheduledTask`（先导出 XML）、`Remove-WcoService`（先导出注册表）、`Remove-WcoRegistryKey`（先 `reg export`，拒绝系统键和多产品共用的厂商根键）、`Invoke-WcoUninstall`（厂商卸载程序 / `msiexec /x`，只报告「已启动卸载程序」，之后复扫）、`Remove-WcoAppxPackage`（拒绝框架包和必需组件）、`Find-WcoLeftover`（参照 BCU 思路的残留打分，只有 Good 及以上才建议勾选）。另有只读的 `Get-WcoInstalledProgram`、`Get-WcoStartupItem`、`Get-WcoShellExtension`、`Get-WcoWmiSubscription`、`Get-WcoFileSigner` 等。
- 新增 Pester 测试 `tests/Wco.Common.V21.Tests.ps1`（StartupApproved 编码、注册表保护清单、短名匹配、商店应用保护、特征库读取）。

### 修复
- **StartupApproved 启用/禁用字节写反**：首字节 02/06 为启用，03/07 为禁用。T10 和 full_scan 现在显示每项的启用状态，已在任务管理器里禁用的不再算作活跃自启。
- `Get-ScheduledTask -Path` 改为 `-TaskPath`；「最近运行」按 LastRunTime 倒序；`autorunsc` 用 `-v` 而非 `-vt`。
- WMI 查询失败时报告「查询失败（需管理员）」，不再显示为干净；T19 现在查齐四类 WMI 对象。
- T04、T18、T19、T20 定义了函数却从不调用，现在会真正运行。
- T11 改为读特征库，同时匹配进程、服务和计划任务，并输出证据。
- T14 运行即切换电源计划并加 Defender 排除 → 改为纯只读，只打印可选命令，推荐「平衡」。
- T15 内存泄漏判断恒为真 → 改为与上一次基线逐进程对比。
- T16 壳扩展扫描查错注册表位置 → 改为查 `Classes\CLSID\{guid}\InprocServer32`（HKCU 与 HKLM 两个视图），按微软签名区分。
- T21、T22 的写操作只在 `-Enable/-Disable/-Cleanup` 加 `-Apply` 且为管理员时执行；不提供 `/ResetBase`。
- full_scan：目录测量不再跟随 junction（PS 5.1 下会重复计算），含 `[ ]` 的路径改用 `-LiteralPath`，AppData 只遍历一次；控制台编码在结束时恢复；新增 `[EXT]` 段调用 T23–T25。
- 回收站预检：读不到回收站策略时一律拒绝；超长路径报告为 `LongPath`，不再误报为 `Locked`。
- 台账只有一条记录时也写成数组。

### 文档（事实修正，依据见各手册内的链接）
- 传递优化：`Delete-DeliveryOptimizationCache -Force`（不是 `Clear-…`）；策略是「Modify Cache Drive」/`DOModifyCacheDrive`（不存在 `DoCachePath`）。
- 服务名：`diagnosticshub.standardcollector.service`、DPS 与 diagsvc 分开、CertPropSvc 为证书传播；AppXSvc、WpnService 不再推荐禁用；「永不禁用」清单去掉进程名和已停用的服务。
- `DisableWindowsSpotlightFeatures` 只对企业版/教育版生效；`powercfg /h /type reduced` 约小 30%（不是 50%）。
- robocopy 默认保留稀疏文件，`/XJ` 与稀疏无关；Defender 排除支持文件夹通配符。
- WSL：`--set-sparse` 已被放到 `--allow-unsafe` 之后，改用 `wsl --manage <发行版> --compact` 或 diskpart `compact vdisk`。
- 微信 4.x 迁移会用硬链接导入旧记录，删除旧 `WeChat Files` 实际释放的空间少于显示；删掉与官方迁移矛盾的「mklink 搬微信」做法。
- 时效更新：Win10 消费者 ESU 至 2027-10-12；Win11 24H2 家庭版/专业版 2026-10-13 结束服务；KB5089573 后存储页只在打开「临时文件」时弹 UAC；8.63 GB 问题已由 KB5044384 缓解；存储感知默认关闭。
- 页面文件统一推荐「系统管理」，删除「1–1.5 倍内存」旧经验；无来源的说法标「存疑」。
- IFEO Debugger 弹窗静音会被 Defender 识别为 `Behavior:Win32/ifeoDebugger.DB`，文档已加警告。
- `pitfalls.md` 按主题重排为 76 条，并清理相关手册中的旧编号引用。
- `chat-apps-migration.md` 中未加保护的 `rd /s /q` 已移除。

### 测试与 CI
- selftest：模板数改为 25；新增特征库结构检查；踩坑条目改为按编号统计；去掉锁死旧措辞的断言（`Clear-DeliveryOptimizationCache`、`set-sparse`、「86.」）。
- 删除 `tests/test_skill.py`（与 selftest 重复）。
- CI：`actions/checkout`、`actions/setup-python` 固定到提交 SHA；Pester 固定 5.9.1（原写法会装到 Pester 6）；PSScriptAnalyzer 固定 1.25.0。

### 未验证 / 存疑
- 新模板与改动的模板只在 Linux 上做过语法、静态检查和冒烟运行，Windows 实机行为以 CI 的 Windows 作业为准。
- 微信 / QQ / 钉钉 / 企业微信的部分路径、`Weixin.exe` 进程名、剪映与 Adobe 菜单路径、页面文件 1024 MB 下限等仍标「存疑」。

## [2.0.1] - 2026-11-08

小版本：不加新功能，只修细节、理顺体验。

### 修复
- **报告里的提示被截断**：`full_scan.ps1` 有两句提示用了中文弯引号（“”）。PowerShell 把弯引号当成字符串结束符，导致提示在"右键"处被截断。所有脚本里的弯引号已统一换成「」。
- **模板 9 会无条件弹 UAC**：旧版不论是否已是管理员，都会去提权运行一个占位路径的脚本，而且续行写法在 PowerShell 5.1 下不可靠。现在只核对剩余空间；普通权限下只打印提权命令，不自动执行。默认核对所有本地盘，`-Drive` 可指定。
- **画像反推漏判开发者**：旧版只看"残留"列表，装着 VS Code 的人反而识别不出来。现在直接检查常见开发工具目录。
- **脚本头注释与实际输出不符**：注释说有"三段式报告"，实际没有输出。现在结尾按档位汇总发现项（每档的项数、合计体积、前 5 项），并显示扫描耗时。
- 提权文档前后矛盾：一处要求"不要用 `$env:TEMP`"，另一处又统一写 `%TEMP%\wco`。现改为显式传 `-OutDir`，并说明只有换管理员账号提权时 TEMP 才会变。

### 体验
- **运行前检查**：扫描开头一次查完权限、PowerShell 版本、是否有待完成的更新重启、系统还原是否开启、C 盘是否不足 5 GB。缺什么就直接给一句修法，不阻断扫描，也不会跑到一半才报错。
- SKILL.md 阶段 1 新增第 0 步：开始前先用一句话告诉用户扫描只读、大概多久、为什么要管理员窗口；真正执行前再提醒保存工作、关掉要清理的软件。

### 代码质量
- 8 个模板函数改用 PowerShell 认可的动词，例如 `Scan-Directory` 改为 `Measure-Directory`，`Query-CompactOS` 改为 `Get-CompactOSState`。文档和 selftest 已同步。
- 新增 `PSScriptAnalyzerSettings.psd1`，CI 加跑 PSScriptAnalyzer，目前 0 条告警。
- 空 `catch {}` 改为写 Verbose；Windows CI 额外检查报告里有"运行前检查"（[PRE]）和"发现汇总"（[SUM]）两段。

## [2.0.0] - 2026-11-08

这一版不加花哨功能，主要把"可回退、不误删"从文档承诺落到代码上，并修掉几处会伤到用户的 bug。

### 修复（会伤到用户的）
- **脚本编码**：`full_scan.ps1` 含 800 多个汉字却没有 UTF-8 BOM，Windows PowerShell 5.1 会按系统 ANSI（中文系统为 GBK）读取，可能乱码或解析失败。现在所有 `.ps1` / `.psm1` 都带 BOM，selftest 会检查。
- **"移入回收站"可能变成永久删除**：以下三种情况会被拒绝执行，并报给用户：
  - 卷没有回收站（U 盘、网络盘）；
  - 回收站设为"直接删除"；
  - 体积超过回收站上限。
- **服务批量恢复其实不生效**：旧备份记的是 `Get-Service` 的 `Automatic/Manual`，`sc.exe` 不认这种写法。现在模板 12 多导出一列 `ScStart`，恢复时用它；单项回退恢复原来的启动类型，不再一律改成 `auto`。
- **模板 5 是伪代码**：原来大括号里只有注释，跑不起来。已改为可运行的只读脚本。
- **原则自相矛盾**：原则写"所有写操作须授权"，风险表第一档却写"默认自动执行"。统一为"第一档列清单、确认一次后批量执行"。
- **selftest 在没装 PowerShell 的机器上必然失败**：现在缺 pwsh 时跳过语法检查，并标 SKIP。
- **其他文件写到用户根目录**：报告、注册表备份、服务和内存基线原来写在用户根目录，和踩坑 64 冲突。现在统一写到 `%TEMP%\wco`。
- **永久删除残留**：百度网盘、迅雷残留原来直接 `Remove-Item -Recurse -Force`，现在改走回收站；删注册表键之前先 `reg export`。
- **安全降级**：
  - Defender 排除列表原来写"安全不受影响"，这是错的。现降为 🟠 HIGH，并撤回"排除 Code.exe 等 IDE 进程"的建议；改为优先推荐 Dev Drive（Defender 在其上自动用性能模式）。
  - 第三方强卸 360 脚本降为 🔴 CRITICAL 最后手段。
  - 删掉"按 F8 进安全模式"，Win10/11 默认已不支持这个按键。

### 新增
- `scripts/lib/Wco.Common.psm1`：
  - 函数：`Invoke-WcoRecycle`、`Set-WcoServiceStartType`、`Set-WcoRegistryValue`、`Add-WcoChange`、`Export-WcoUndo`、`Test-WcoAdmin`。
  - 写操作默认只演练，加 `-Apply` 才执行。
  - 执行后写 `changes.json`，并按逆序生成 `undo.ps1`。
- `full_scan.ps1`：
  - 管理员检测：普通权限运行时，报告里写明哪些数据不全。
  - `[T0]` 开机耗时实测：读事件 100，取最近 5 次的平均值。
  - Windows 10 停止支持提示。
  - 自动识别所有盘。
  - `-Quick` 真正生效。
  - 修复 `$profile` 覆盖 PowerShell 自动变量的问题。
- 内容补充：
  - 官方入口优先：设置里的清理建议、存储感知。2026 年起"Windows 更新清理"只剩 cleanmgr 里有；打开存储设置可能弹 UAC。
  - Windows.old（🟠 HIGH）。
  - Dev Drive 放包缓存（npm / pip / NuGet / Cargo / Gradle / vcpkg）。
  - winget 盘点与卸载。
  - Copilot / Recall 等 AI 组件开关。
- `data/volatile-paths.json`：微信、QQ、钉钉、TRAE 等易变路径，每条带核实日期；超过 90 天由 selftest 提醒复核。
- `evals/`：
  - 22 条触发评测，其中 7 条是不应触发的反例；
  - 10 个行为场景，每个都有 must / must_not 判定条件。
- `tests/Wco.Common.Tests.ps1`：12 个 Pester 单元测试。
- CI 加 Windows job：
  - 用 5.1 解析全部脚本；
  - 跑 Pester；
  - 真跑 `full_scan.ps1 -Quick`，并对比运行前后的服务、Run 键、电源计划，证明扫描是只读的。

### 精简
- `SKILL.md` 改成"安全底线 7 条 + 六阶段流程 + 按用户问题找手册的路由表"。去掉开场的 A/B 二选一，改为直接只读扫描、自动反推画像；新增三档预设（只清缓存 / 标准 / 深度）。
- 22 个模板从 `scan-scripts.md` 移到 `scripts/templates/tNN-*.ps1`，手册从 769 行降到 200 行左右，读手册时不用把代码装进上下文。
- 手册从 16 份合并为 14 份：
  - `windows-cleanup-optimize-pitfalls.md` 并入 `pitfalls.md`；
  - `case-study.md` 和 `trae-guide.md` 合并为 `migration-cases.md`。
- description 改为中英双语，写进用户的原话，并写明不适用的场景。
- selftest 自动核对文档里写的模板数量，防止数字和实际不一致。
- README（中英）保留原有章节结构，内容按 v2.0 全部更新：手册数、模板数、六阶段流程、安全原则、文件结构、FAQ，并加 CI 徽章；横幅去掉"100% 可回退""ZERO-HARM GUARANTEED"；PR 模板与 SECURITY.md 同步新规则。
- README 删掉不存在的文件（`validate_repo.py`、`agents/`、`SUPPORT.md`）和"绝不会误删"这类绝对化承诺。

### 已知未做
- 服务、流氓软件清单还没有改成 JSON 数据驱动，仍在 markdown 表里。
- `evals/` 只提供了用例，还没有跑出基线结果。
- 新内容涉及的设置页路径以 2026-11 的微软文档为准，未在真机逐项点验。

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
- **核心扫描器与脚本库硬防御升级（`scripts/full_scan.ps1` + `references/scan-scripts.md`）**：
  - **ReparsePoint 重解析点硬过滤**：在 `Get-DirSize`、`Scan-Directory` 与 `Scan-NonSystemDrive` 中加入 `ReparsePoint` 属性硬过滤，彻底杜绝扫描过程中因读取 OneDrive/iCloud 随选占位符或目录 Junction 引发的水合雪崩与软链接死循环；
  - **模板 21（CompactOS 压缩状态查询与安全管理）**：新增 `Query-CompactOS`、`Enable-CompactOS` 与 `Disable-CompactOS` 原生 PowerShell 模板；
  - **模板 22（WinSxS 组件库安全分析与标准清理）**：新增 `Analyze-WinSxS` 与 `Start-SafeComponentCleanup` 原生 PowerShell 模板，代码级物理隔绝 `/ResetBase` 参数；
  - **全量扫描探针集成**：`scripts/full_scan.ps1` 增加 `[T21]` CompactOS 压缩状态只读探针。
- **回归测试套件强化（`scripts/selftest.py`）**：
  - 扩展 `REQUIRED_REFS` 必检清单，新增 `ResetBase`、`ReparsePoint`、`Installer` 缓存等底层避坑要点的深度内容级断言校验；
  - 补充对 `full_scan.ps1` ReparsePoint 属性过滤、CompactOS 与 WinSxS 模板的回归断言。

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
