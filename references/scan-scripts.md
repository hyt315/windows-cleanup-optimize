# 扫描与清理脚本模板库（索引）

<!-- skill-doctor: allow-block SEC002（命令示例路径用 <用户名> / %USERPROFILE% 占位，无真实用户路径） -->

v2.0 起，模板代码不再写在本文件里，而是放在 `scripts/templates/tNN-*.ps1`。v2.1 起共 25 个模板（t01–t25，与文件一一对应）；全量扫描入口 `scripts/full_scan.ps1` 不编号（报告里的 `[T0]` 等是入口内部的段落标签，不是模板编号）。本文件只说明每个模板做什么、什么时候用。这样读本文件不必把几百行代码装进上下文，代码也能单独测试。

**规则**

1. 只读模板（扫描、审计、检测）可以直接运行。
2. 写操作统一走 `scripts/lib/Wco.Common.psm1`：
   - **默认只演练**，输出"将会做什么、能释放多少"；
   - 加 `-Apply` 才执行；
   - 每次执行都写入 `%TEMP%\wco\session_*\changes.json`，并生成 `undo.ps1`。
3. 脚本一律以 **UTF-8 BOM** 保存。Windows PowerShell 5.1 读无 BOM 的文件会按系统 ANSI（中文系统为 GBK）解码，中文会乱码，甚至报解析错误。
4. 运行方式：`powershell -NoProfile -ExecutionPolicy Bypass -File <模板路径> [参数]`；写操作需要管理员时，脚本会自己说明（HKLM / 服务 / 驱动 / 计划任务类操作在非管理员下直接拒绝并给出提示）。
5. 路径一律按字面处理（`-LiteralPath`）：`[Steam]`、`[备份]` 这类带方括号的目录不会被当成通配符。
6. 统计大小时**不进入 junction / 符号链接**（Windows PowerShell 5.1 的 `-Recurse` 会跟随 junction，已迁到 D 盘的数据会被算成 C 盘占用），并且**硬链接会被重复计算**（WinSxS、微信 4.x 旧/新目录常见）——报告里的"可释放"是上限估计，不是保证值。

## 目录

- 〇、全量扫描主脚本
- 一、通用扫描模板（1–2）
- 二、残留检测模板（3–5）
- 三、安全清理模板（6–8）
- 四、验证汇报模板（9）
- 五、清理加优化双线（10–15）
- 六、Shell 扩展审计（16）
- 七、高价值扫描模板（17–22）
- 八、劫持、扩展自启与程序清单（23–25，v2.1）
- 九、公共模块函数一览（Wco.Common.psm1）

## 〇、全量扫描主脚本

直接运行 `scripts/full_scan.ps1`，一次跑完全部只读模板。它是阶段 1 的唯一入口，不再让用户选 A/B。

- 报告写到 `%TEMP%\wco\full_scan_<时间>.txt`。不写到用户目录，避免污染用户目录、被同步盘上传。
- 开头写明权限：以普通用户运行时，系统目录、服务、WMI、开机耗时这几项数据可能不全；WMI 查询失败会写"查询失败（需管理员）"，和"没有发现"区分开。
- 开机耗时实测段：读取 Diagnostics-Performance 事件 100 的 BootTime，取最近 5 次平均。用户说"开机慢"时，用这个数做优化前后的对比。
- v2.1：报告末尾附 t23（浏览器劫持）、t24（扩展自启）、t25（程序清单）的摘要；计划任务"最近运行"按时间倒序。
- 末尾自动反推用户画像（家庭 / 开发者 / AI 创作者 / 游戏玩家 / 笔记本）。
- 耗时通常几分钟；用户目录很大（大量 node_modules、聊天记录）时可能更久。

## 一、通用扫描模板

### 1. 用户目录分层扫描

> 代码：[`scripts/templates/t01-scan-user-profile.ps1`](../scripts/templates/t01-scan-user-profile.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

扫描顺序（从粗到细）：第一层 `$env:USERPROFILE` 一级目录（含隐藏）→ 第二层 `AppData\Local` → 第三层 `AppData\Roaming` → 第四层 `AppData\Local\Programs` → 第五层用户目录隐藏目录（.cache、.rustup、.hermes-web-ui 等）。对每一层调用 `Measure-Directory` 汇总。

> **模板作用域警告（2026-08 实战踩坑）：** 若要把扫描结果追加到脚本级变量（`$report += ...`），**必须写成 `$script:report += ...`**。PowerShell 函数内普通赋值会创建函数局部变量、不会写回外部变量——表现是扫描报告大片空白、白扫一轮。推荐做法：让函数直接返回对象数组（如上），由调用方 `$rows = Measure-Directory ...` 捕获输出。

> **进度反馈：** 全盘扫描耗时 2-6 分钟且无输出，用户会以为卡死。建议每完成一层输出一行 `Write-Host "[1/5] 用户目录扫描完成 ..."`；Bash 调用设 `timeout 300000ms` 以上。

### 2. 非系统盘根目录扫描

> 代码：[`scripts/templates/t02-scan-nonsystem-drive.ps1`](../scripts/templates/t02-scan-nonsystem-drive.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

非系统盘不做 AppData 式逐层扫描，只做根目录一级展开；对可疑大目录再深入一层。**不要对非系统盘全盘 `-Recurse`**（几十到上百 GB 会非常慢）。

## 二、残留检测模板

### 3. Roaming 残留软件检测

> 代码：[`scripts/templates/t03-detect-roaming-leftovers.ps1`](../scripts/templates/t03-detect-roaming-leftovers.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

匹配结果只是**疑似残留**（目录名和应用名可能不完全对应，软件改名、公司名目录、商店应用都会误判），需要人工审视后呈现给用户确认。卸载后的残留优先用 `Find-WcoLeftover` 打分（见第九节），只把 Good 及以上的项作为候选，逐项确认后再移入回收站。

### 4. 安装目录残留检测

**Roaming 检测只覆盖配置残留，最大的卸载残留往往在安装目录里**（2026-08 实战：`C:\Program Files\JetBrains` 2.4 GB + D 盘 IDEA/PyCharm 4.4 GB，均一年多未用；`C:\Program Files (x86)\ByteDance` 295 MB 搬家备份；`AlibabaProtect` 396 MB 钉钉卸载残留——这些全部在安装目录而非 Roaming）。必须在 Roaming 检测之外**单独做安装目录比对**：

> 代码：[`scripts/templates/t04-detect-install-dir-leftovers.ps1`](../scripts/templates/t04-detect-install-dir-leftovers.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

判定要点（务必执行，防止误删在用软件）：
- **交叉比对只是筛选，不是结论**。对每个"疑似残留"必须核对：目录内部 LastWriteTime 是否超过 6 个月、进程列表是否有对应进程、注册表是否有其他条目（软件改名/公司名目录常见误判，如 `Tencent`、`Microsoft` 这类目录名会被目录匹配词覆盖，需人工核对内部装了谁）。
- 目录名是公司名（`AlibabaProtect`、`ByteDance`、`Netease` 等）时，用"公司名 + 已卸载"搜索注册表安装列表，确认该公司的软件是否都已卸载。
- **空壳目录**（0-5 MB 且内部无有效文件）可直接判定为残留，但要识别 `ModifiableWindowsApps`、`WindowsPowerShell` 等系统目录（加入 `$knownSys`）。

> **2026-08 新增**：本模板假设软件装在标准路径，但**非标准路径的检测见 pitfalls 28**——务必用 Uninstall 注册表反查实际路径作为兜底。

### 5. 更新包残留检测

**用户场景"更新了很多软件，更新包没清理"对应的完整检测流程**（2026-08 实战：一次扫出 5 个 electron-updater 残留共 2.2 GB）。分四个专项扫描：

> 代码：[`scripts/templates/t05-detect-updater-leftovers.ps1`](../scripts/templates/t05-detect-updater-leftovers.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

**"已装完残留" vs "等待安装包" 的判断（关键技巧）：** electron-updater 的 `pending\installer.exe` 可能是"更新完没清理"也可能是"等下次启动安装"。判断方法——**对比安装包版本号与已安装版本号**：


清理口径：更新包残留全部归**第一档**（移入回收站可恢复 + 可重新下载，双保险）。

## 三、安全清理模板

### 6. ReparsePoint 预检（必须在删除前执行）

对每个待清理目录，先检查是否为 junction/symlink（ReparsePoint）。如果是，**不能直接 SendToRecycleBin**——需要判断指向的目标是否仍在使用：

> 代码：[`scripts/templates/t06-test-reparsepoint.ps1`](../scripts/templates/t06-test-reparsepoint.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

处理规则：
- **是 junction 且目标在 C 盘活跃路径** → 只删 junction 本身（用 `cmd /c rmdir "$Path"`，不带 `/s`），不删目标
- **是 junction 且目标已不存在** → 直接 `cmd /c rmdir "$Path"` 删除空壳
- **不是 junction** → 正常走模板 7（`Invoke-WcoRecycle`）

实战案例：`D:\zcode\TRAE SOLO CN`（0 MB）疑似 junction 空壳，必须先确认属性再决定删除方式。

### 7. 安全移入回收站（v2.0：Invoke-WcoRecycle）

所有删除操作都走这个函数。v2.0 新增三道预检，任何一道不过都返回 `Blocked`，不执行，由 AI 报给用户决定：

1. 所在卷**没有回收站**（U 盘、移动硬盘、网络路径）。
2. 回收站设为**"不移入回收站，直接删除"**。
3. 体积**超过该卷回收站上限**。

以上三种情况下，"移入回收站"实际都会变成永久删除。

另外：

- junction / 符号链接一律拒绝，先按模板 6 处理。
- v2.1：**回收站策略读不到（未知）时一律拒绝**，不再按"小于 1 GB 就放行"处理。
- v2.1：路径超长（>260）报告为 `LongPath`，不再误报成 `Locked`，也绝不退回永久删除。

> 代码：[`scripts/templates/t07-safe-recycle.ps1`](../scripts/templates/t07-safe-recycle.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 8. Temp 被锁文件处理

> 代码：[`scripts/templates/t08-clean-temp-locked.ps1`](../scripts/templates/t08-clean-temp-locked.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

被锁文件是正常的，告诉用户"重启电脑后再清即可"。

## 四、验证汇报模板

> 代码：[`scripts/templates/t09-verify-report.ps1`](../scripts/templates/t09-verify-report.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

默认核对所有本地盘，也可用 `-Drive C,D` 指定。普通权限时只打印提权命令，不自动弹 UAC；公共模块里也有 `Test-WcoAdmin`。

提权脚本要点：
- **报告路径显式传进去**（`-OutDir <绝对路径>`）。用另一个管理员账号提权时，提权进程的 `$env:TEMP` 指向那个账号，报告会"丢失"。
- 提权后移入回收站通常就能成功。仍失败（被锁）时，**不要退回 `Remove-Item -Recurse -Force`**，那是永久删除（v2.0 改）。正确做法是记下来、让用户重启后再试；确实是 0 项的空壳，用 `rmdir`。
- 空壳目录（0 项内容）回收失败的另类原因：目录内有 0 字节/隐藏文件未被统计——先 `Get-ChildItem -Recurse -Force` 核对项数，再决定 `rmdir`（只删空目录，非空自动失败，安全）。
- 一次 UAC 弹窗处理尽量合并所有需提权的目录，减少打扰。

---

## 五、新增模板（清理+优化双线）

### 10. 自启动项审计（对应 `startup-audit.md`）

完整说明见 `references/startup-audit.md`。v2.1：读取 `StartupApproved` 状态（在任务管理器里已禁用的项会标为"已禁用"，不再当成活跃自启），覆盖 RunOnce 和"启动"文件夹；计划任务按最近运行时间倒序。

> 代码：[`scripts/templates/t10-audit-startup.ps1`](../scripts/templates/t10-audit-startup.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

- 计划任务默认只列 `\Microsoft\` 以外的任务，加 `-IncludeMicrosoftTasks` 显示全部。

**关闭自启的规则**：Run 键 / "启动"文件夹里的项优先用 `Set-WcoStartupApproved -Enabled $false`（与任务管理器、设置里的开关效果相同，原值保留、可撤销）；计划任务用 `Disable-WcoScheduledTask`。**删除 Run 值或计划任务只在用户明确要求时做**（`Remove-WcoScheduledTask` 会先导出 XML）。

### 11. Bloatware 进程批量识别（对应 `bloatware-catalog.md`）

v2.1：按 `data/bloatware-catalog.json` 的进程 / 服务 / 计划任务标识匹配，不再只看进程名。完整的程序清单与置信度见模板 25。

> 代码：[`scripts/templates/t11-detect-bloatware-process.ps1`](../scripts/templates/t11-detect-bloatware-process.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 12. 服务快照（优化前备份，对应 `services-optimization.md`）

> 代码：[`scripts/templates/t12-snapshot-services.ps1`](../scripts/templates/t12-snapshot-services.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 13. 内存基线（优化前后对比，对应 `memory-optimization.md`）

> 代码：[`scripts/templates/t13-baseline-memory.ps1`](../scripts/templates/t13-baseline-memory.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 14. 电源计划与视觉效果（对应 `performance-tuning.md`）

v2.1：**只读报告**——显示当前电源计划、视觉效果等设置，不再自动切换电源计划或添加 Defender 排除。

> 代码：[`scripts/templates/t14-show-power-visual.ps1`](../scripts/templates/t14-show-power-visual.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 15. 内存泄漏检测（两次采样对比，对应 `memory-optimization.md`）

v2.1：第一次运行只记录基线；过一段时间（如 30 分钟）再运行时，和**上一次**的基线按进程 Id + 名称逐个对比。旧版在同一次运行里写基线又立刻对比，而且匹配条件恒为真，结果不可信。

> 代码：[`scripts/templates/t15-detect-memory-leak.ps1`](../scripts/templates/t15-detect-memory-leak.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

---

## 六、Shell 扩展审计（2026-08 实战新增）

### 16. 右键菜单 / Shell 扩展审计

审计用户问"我的右键菜单有没有被篡改 / 流氓软件 / 缺失项"时使用。完整对照 `bloatware-catalog.md` 的进程名单判断是否为可疑项。

**前置陷阱**：**永远不要用 `Registry::HKEY_CLASSES_ROOT\*\...` 通配符枚举**——HKCR 树几十万节点，10 分钟都跑不完（参见 pitfalls 23）。

**只读审计脚本**：

> 代码：[`scripts/templates/t16-audit-shell-extensions.ps1`](../scripts/templates/t16-audit-shell-extensions.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

v2.1：命名的处理器键（如 `7-Zip`、`WinRAR`）会读取默认值里的 CLSID，再到 `Classes\CLSID\{GUID}` 下查实现路径；"已知良性"按微软签名判断，不再按名字里有没有 Microsoft/Windows 判断。

**判读逻辑**：
- **良性**：实现 DLL 有有效的微软签名，或属于用户确认装过的软件
- **bloatware**：实现路径（InprocServer32）含 360 / 2345 / HaoZip / KuaiZip / SoGou / QQPCMgr / AlibabaProtect / BaiduNetdisk / Meitu 等关键词
- **未知**：都不是。**给用户看**，让用户确认是否认识/需要（不是自动禁用）

---

## 七、新增高价值扫描模板

### 17. 本地 AI 框架与大模型缓存探测（Ollama / HuggingFace / ModelScope / PyTorch / uv / AVD / Gradle）

> 代码：[`scripts/templates/t17-detect-ai-model-caches.ps1`](../scripts/templates/t17-detect-ai-model-caches.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 18. 顽固后台常驻服务与守护进程深度审计（百度网盘/迅雷/搜狗/WPS）

v2.1：直接运行即输出结果（旧版只定义函数不调用）。模板 19 同。

> 代码：[`scripts/templates/t18-audit-resident-daemons.ps1`](../scripts/templates/t18-audit-resident-daemons.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 19. WMI 隐蔽自启动与快捷方式网址劫持审计（WMI / LNK Arguments）

> 代码：[`scripts/templates/t19-audit-wmi-lnk-hijack.ps1`](../scripts/templates/t19-audit-wmi-lnk-hijack.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 20. 3 秒抓弹窗现行工具（原生 Win32 API 弹窗定位器）

> 代码：[`scripts/templates/t20-locate-popup-window.ps1`](../scripts/templates/t20-locate-popup-window.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 21. CompactOS 压缩状态查询与安全管理

> 代码：[`scripts/templates/t21-query-compactos.ps1`](../scripts/templates/t21-query-compactos.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

- 用法：不带参数只查询；`-Enable` / `-Disable` 只演练，加 `-Apply`（管理员）才真正执行。
- `compact.exe /compactos:query` 只读查询；开启是 `/compactos:always`，撤销是 `/compactos:never`。
- 能省多少因机器而异：微软在 Windows 10 1607 测试镜像上测得约 2.75–3.7 GB，不是保证值。
- 对性能**通常影响很小**，但在低速 CPU 或机械硬盘上可能略慢（微软没有"不影响性能/启动速度"的说法）。
- 不是默认动作：只在 C 盘确实紧张、用户同意后做（🟡 MEDIUM）。

依据：https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os （访问于 2026-11-11）

### 22. WinSxS 组件存储库安全分析与清理（严禁 /ResetBase）

> 代码：[`scripts/templates/t22-analyze-winsxs.ps1`](../scripts/templates/t22-analyze-winsxs.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

- 用法：不带参数只分析（`Dism /Online /Cleanup-Image /AnalyzeComponentStore`）；`-Cleanup` 只演练，加 `-Apply`（管理员）才执行标准的 `/StartComponentCleanup`。模板不提供 `/ResetBase`。

---

## 八、劫持、扩展自启与程序清单（v2.1）

三个模板都是**只读**：只列出发现，不改任何东西；处置走第九节的写函数，逐项确认。

### 23. 浏览器劫持审计（对应 `startup-audit.md`、`bloatware-catalog.md`）

> 代码：[`scripts/templates/t23-audit-browser-hijack.ps1`](../scripts/templates/t23-audit-browser-hijack.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

检查：Chrome / Edge / Firefox 在 HKLM 和 HKCU 下的策略（主页、启动页、新标签页、默认搜索引擎、强制安装扩展 `ExtensionInstallForcelist` / `ExtensionSettings`）、Native Messaging 宿主、快捷方式（.lnk）目标后附加的网址参数、WinINet 代理与自动配置脚本（`AutoConfigURL`）、hosts 文件里的非注释行、各网卡的 DNS 服务器、本机/当前用户受信任根证书（按颁发者和生效时间倒序列出，**近 180 天新增的标出来**）。`Secure Preferences` 不解析，只提示"如果改回又被改，用浏览器自带的'重置设置'"。

判读：策略项用户在浏览器里删不掉，是劫持的强信号；但公司电脑的策略可能是 IT 下发的，先问用户。主页改了又被改回，可能是驱动级锁首页，提示用户用安全软件处理，不要反复改注册表。

### 24. 扩展自启位置审计（对应 `startup-mechanisms.md`）

> 代码：[`scripts/templates/t24-audit-autostart-extended.ps1`](../scripts/templates/t24-audit-autostart-extended.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

覆盖：所有登录启动位置（Run / RunOnce / RunOnceEx / WOW6432Node / Policies\Explorer\Run / 用户和公共"启动"文件夹）及其 `StartupApproved` 状态；Winlogon 的 Shell / Userinit 与默认值对比；IFEO 的 Debugger 与 SilentProcessExit；AppInit_DLLs；exe/htm/bat/cmd 文件关联的打开命令；Active Setup；BootExecute；LSA 包；非默认打印监视器；Winsock 目录里的非微软提供程序；非微软计划任务（含"注册表里有、`Get-ScheduledTask` 看不到"的疑似隐藏任务）；WMI 事件订阅（过滤器、CommandLine / ActiveScript 消费者、绑定；查询失败与"没有"分开写）；非微软内核/筛选驱动（含签名）；Win11"重新启动应用"（RestartApps）；Edge 启动加速/后台运行策略；商店应用的 StartupTask（尽力而为）。

判读：这些位置里的项**只报告**。IFEO、Winlogon、LSA、驱动类发现属于 🔴 HIGH，交给用户和安全软件判断，本技能不自动修改。

### 25. 已安装程序清单与流氓软件匹配（对应 `software-uninstall.md`、`bloatware-catalog.md`）

> 代码：[`scripts/templates/t25-inventory-programs.ps1`](../scripts/templates/t25-inventory-programs.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

用 `Get-WcoInstalledProgram` 读三个 Uninstall 键（含 `SystemComponent=1` 等控制面板里看不到的项），加上非框架、非系统的商店应用，再对照 `data/bloatware-catalog.json` 的发行商 / 签名 / 进程 / 服务 / 计划任务标识打分：签名命中 = 高置信度；只有名字像 = 低置信度，标"疑似，需人工确认"；目录里没有的第三方软件标"未知第三方"，**不给任何处置建议**。

卸载流程（`software-uninstall.md`）：`Invoke-WcoUninstall` 运行厂商自己的卸载程序（交互式，用户要留意挽留页和捆绑勾选）→ 报告"**已启动卸载程序**"→ 用 `Get-WcoInstalledProgram` + `Find-WcoLeftover` 重新扫描，确认后才能说"已卸载"。

---

## 九、公共模块函数一览（`scripts/lib/Wco.Common.psm1`）

所有**写**函数默认只演练（打印计划），加 `-Apply` 才执行；每次执行都经 `Add-WcoChange` 记入 `changes.json`，`Export-WcoUndo` 生成 `undo.ps1`。HKLM / 服务 / 驱动 / 计划任务类操作在非管理员下直接拒绝。

| 函数 | 读/写 | 作用 | 撤销 |
|---|---|---|---|
| `Test-WcoAdmin` | 读 | 当前是否管理员（UAC 过滤后的令牌返回 False） | — |
| `Start-WcoSession` / `Add-WcoChange` / `Export-WcoUndo` | 记录 | 会话目录、变更台账、生成 undo.ps1 | — |
| `Get-WcoRecycleBinPolicy` | 读 | 读取某卷的回收站策略（是否存在、是否直接删除、上限） | — |
| `Invoke-WcoRecycle -Path [-Apply]` | 写 | 移入回收站；无回收站 / 直接删除 / 超上限 / 策略未知 / junction 一律拒绝（模板 7） | 从回收站还原 |
| `Set-WcoServiceStartType -Name -StartType [-Apply]` | 写 | 改服务启动类型，记录原值（含 delayed-auto） | 恢复原启动类型 |
| `Set-WcoRegistryValue … [-Apply]` | 写 | 改注册表值，先 `reg export` | `reg import` |
| `Set-WcoStartupApproved -Name -Scope <HKCU-Run\|HKLM-Run\|HKLM-Run32\|HKCU-StartupFolder\|HKLM-StartupFolder> -Enabled <$true\|$false> [-Apply]` | 写 | 写 12 字节 StartupApproved 值（首字节 0x02 = 启用、0x03 = 禁用；读取时 0x06/0x07 视为启用/禁用），等同任务管理器开关。**关闭 Run 键/"启动"文件夹项的首选方式** | 恢复原字节或删除新建的值 |
| `Disable-WcoScheduledTask -TaskPath -TaskName [-Apply]` | 写 | 禁用计划任务，记录原状态 | 重新启用 |
| `Remove-WcoScheduledTask -TaskPath -TaskName [-Apply]` | 写 | 先导出 XML 再删除；拒绝 `\Microsoft\` 下的任务。仅用户明确要求删除时用 | 从 XML 重新注册 |
| `Remove-WcoService -Name [-Apply]` | 写 | 要求服务已停止且已禁用；拒绝微软签名/系统服务和"不要禁用"清单；先 `reg export` 服务键 | `reg import` 后重启 |
| `Remove-WcoRegistryKey -Path [-Apply]` | 写 | 先 `reg export` 再删键；拒绝根键和共享键（`HKLM:\SOFTWARE`、`\SOFTWARE\Microsoft*`、`Classes`/`Policies`/`WOW6432Node` 根、共享厂商根、Services 根） | `reg import` |
| `Get-WcoInstalledProgram [-Name]` | 读 | 读三个 Uninstall 键：名称、发行商、版本、安装位置、卸载命令、ProductCode、SystemComponent、估算大小、主程序签名 | — |
| `Invoke-WcoUninstall -Name <完整显示名> \| -ProductCode <{GUID}> [-Apply]` | 写 | 演练时打印命令；执行时 MSI 用 `msiexec.exe /x {GUID}`（交互，默认不加 /qn），其他运行厂商 UninstallString（交互）。返回"已启动卸载程序"，之后必须重新扫描 | 不可撤销（undo.ps1 只给提示） |
| `Remove-WcoAppxPackage -Name [-AllUsers] [-Provisioned] [-Apply]` | 写 | 删除商店应用；拒绝框架包、不可移除包、系统签名包和必需组件（商店、WebView2、VCLibs、UI.Xaml、App Installer、Windows 安全中心等） | 不自动；undo.ps1 给出商店 / winget 重装提示 |
| `Find-WcoLeftover -Name [-Publisher] [-InstallLocation]` | 读 | 卸载后残留候选打分（Bad / Questionable / Good / VeryGood）；≤4 个字符的名字不做模糊匹配；仍被其他已装程序引用的目录强扣分；跳过 junction | — |
| `Get-WcoItemSizeMB` | 读 | 统计大小（不进入 junction） | — |

驱动包：没有自动删除函数。只读用 `pnputil /enum-drivers`；确需删除时（🔴 HIGH，先跑厂商卸载程序）手动 `pnputil /export-driver oemNN.inf <备份目录>` 再 `pnputil /delete-driver oemNN.inf`。

---

**所有审计 .ps1 一律写到 `$env:TEMP` 或 `C:\Windows\Temp`**，不要放用户目录。
