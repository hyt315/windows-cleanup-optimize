# 扫描与清理脚本模板库（索引）

<!-- skill-doctor: allow-block SEC002（命令示例路径用 <用户名> / %USERPROFILE% 占位，无真实用户路径） -->

v2.0 起，模板代码不再写在本文件里，而是放在 `scripts/templates/tNN-*.ps1`，共 22 个（模板 0 是 `scripts/full_scan.ps1`）。本文件只说明每个模板做什么、什么时候用。这样读本文件不必把几百行代码装进上下文，代码也能单独测试。

**规则**

1. 只读模板（扫描、审计、检测）可以直接运行。
2. 写操作统一走 `scripts/lib/Wco.Common.psm1`：
   - **默认只演练**，输出"将会做什么、能释放多少"；
   - 加 `-Apply` 才执行；
   - 每次执行都写入 `%TEMP%\wco\session_*\changes.json`，并生成 `undo.ps1`。
3. 脚本一律以 **UTF-8 BOM** 保存。Windows PowerShell 5.1 读无 BOM 的文件会按系统 ANSI（中文系统为 GBK）解码，中文会乱码，甚至报解析错误。
4. 运行方式：`powershell -NoProfile -ExecutionPolicy Bypass -File <模板路径> [参数]`；写操作需要管理员时，脚本会自己说明。

## 目录

- 〇、全量扫描主脚本
- 一、通用扫描模板（1–2）
- 二、残留检测模板（3–5）
- 三、安全清理模板（6–8）
- 四、验证汇报模板（9）
- 五、清理加优化双线（10–15）
- 六、Shell 扩展审计（16）
- 七、高价值扫描模板（17–22）

## 〇、全量扫描主脚本

直接运行 `scripts/full_scan.ps1`，一次跑完全部只读模板。它是阶段 1 的唯一入口，不再让用户选 A/B。

- 报告写到 `%TEMP%\wco\full_scan_<时间>.txt`。不写到用户目录，原因见踩坑 64。
- 开头写明权限：以普通用户运行时，系统目录、服务、WMI、开机耗时这几项数据可能不全。
- 新增 [T0] 开机耗时实测：读取 Diagnostics-Performance 事件 100 的 BootTime，取最近 5 次平均。用户说"开机慢"时，用这个数做优化前后的对比。
- 末尾自动反推用户画像（家庭 / 开发者 / AI 创作者 / 游戏玩家 / 办公 / 笔记本）。
- 耗时约 2–6 分钟。

## 一、通用扫描模板

### 1. 用户目录分层扫描

> 代码：[`scripts/templates/t01-scan-user-profile.ps1`](../scripts/templates/t01-scan-user-profile.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

扫描顺序（从粗到细）：第一层 `$env:USERPROFILE` 一级目录（含隐藏）→ 第二层 `AppData\Local` → 第三层 `AppData\Roaming` → 第四层 `AppData\Local\Programs` → 第五层用户目录隐藏目录（.cache、.rustup、.hermes-web-ui 等）。对每一层调用 `Scan-Directory` 汇总。

> **模板作用域警告（2026-08 实战踩坑）：** 若要把扫描结果追加到脚本级变量（`$report += ...`），**必须写成 `$script:report += ...`**。PowerShell 函数内普通赋值会创建函数局部变量、不会写回外部变量——表现是扫描报告大片空白、白扫一轮。推荐做法：让函数直接返回对象数组（如上），由调用方 `$rows = Scan-Directory ...` 捕获输出。

> **进度反馈：** 全盘扫描耗时 2-6 分钟且无输出，用户会以为卡死。建议每完成一层输出一行 `Write-Host "[1/5] 用户目录扫描完成 ..."`；Bash 调用设 `timeout 300000ms` 以上。

### 2. 非系统盘根目录扫描

> 代码：[`scripts/templates/t02-scan-nonsystem-drive.ps1`](../scripts/templates/t02-scan-nonsystem-drive.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

非系统盘不做 AppData 式逐层扫描，只做根目录一级展开；对可疑大目录再深入一层。**不要对非系统盘全盘 `-Recurse`**（几十到上百 GB 会非常慢）。

## 二、残留检测模板

### 3. Roaming 残留软件检测

> 代码：[`scripts/templates/t03-detect-roaming-leftovers.ps1`](../scripts/templates/t03-detect-roaming-leftovers.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

匹配结果不一定 100% 准确（目录名和应用名可能不完全对应），需要人工审视后呈现给用户确认。对于标记为 `RESIDUAL` 的目录，按大小排序呈现，让用户确认后批量清理。

### 4. 安装目录残留检测

**Roaming 检测只覆盖配置残留，最大的卸载残留往往在安装目录里**（2026-08 实战：`C:\Program Files\JetBrains` 2.4 GB + D 盘 IDEA/PyCharm 4.4 GB，均一年多未用；`C:\Program Files (x86)\ByteDance` 295 MB 搬家备份；`AlibabaProtect` 396 MB 钉钉卸载残留——这些全部在安装目录而非 Roaming）。必须在 Roaming 检测之外**单独做安装目录比对**：

> 代码：[`scripts/templates/t04-detect-install-dir-leftovers.ps1`](../scripts/templates/t04-detect-install-dir-leftovers.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

判定要点（务必执行，防止误删在用软件）：
- **交叉比对只是筛选，不是结论**。对每个"疑似残留"必须核对：目录内部 LastWriteTime 是否超过 6 个月、进程列表是否有对应进程、注册表是否有其他条目（软件改名/公司名目录常见误判，如 `Tencent`、`Microsoft` 这类目录名会被目录匹配词覆盖，需人工核对内部装了谁）。
- 目录名是公司名（`AlibabaProtect`、`ByteDance`、`Netease` 等）时，用"公司名 + 已卸载"搜索注册表安装列表，确认该公司的软件是否都已卸载。
- **空壳目录**（0-5 MB 且内部无有效文件）可直接判定为残留，但要识别 `ModifiableWindowsApps`、`WindowsPowerShell` 等系统目录（加入 `$knownSys`）。

> **2026-08 新增**：本模板假设软件装在标准路径，但**非标准路径的检测见 pitfalls 59**——务必用 Uninstall 注册表反查实际路径作为兜底。

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
- **不是 junction** → 正常走 `SafeRecycle`

实战案例：`D:\zcode\TRAE SOLO CN`（0 MB）疑似 junction 空壳，必须先确认属性再决定删除方式。

### 7. 安全移入回收站（v2.0：Invoke-WcoRecycle）

所有删除操作都走这个函数。v2.0 新增三道预检，任何一道不过都返回 `Blocked`，不执行，由 AI 报给用户决定：

1. 所在卷**没有回收站**（U 盘、移动硬盘、网络路径）。
2. 回收站设为**"不移入回收站，直接删除"**。
3. 体积**超过该卷回收站上限**。

以上三种情况下，"移入回收站"实际都会变成永久删除。

另外：

- junction / 符号链接一律拒绝，先按模板 6 处理。
- 回收站上限读不到时，超过 1 GB 的项也拒绝。

> 代码：[`scripts/templates/t07-safe-recycle.ps1`](../scripts/templates/t07-safe-recycle.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 8. Temp 被锁文件处理

> 代码：[`scripts/templates/t08-clean-temp-locked.ps1`](../scripts/templates/t08-clean-temp-locked.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

被锁文件是正常的，告诉用户"重启电脑后再清即可"。

## 四、验证汇报模板

> 代码：[`scripts/templates/t09-verify-report.ps1`](../scripts/templates/t09-verify-report.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

管理员权限判定与提权：代码在 `t09-verify-report.ps1` 末尾；公共模块里也有 `Test-WcoAdmin`。

提权脚本要点：
- **日志必须写绝对路径**（`Out-File 'C:\Users\<用户名>\AppData\Local\Temp\report.txt'`），不要用 `$env:TEMP`——提权进程的 TEMP 可能指向不同位置，导致报告"丢失"。
- 提权后移入回收站通常就能成功。仍失败（被锁）时，**不要退回 `Remove-Item -Recurse -Force`**，那是永久删除（v2.0 改）。正确做法是记下来、让用户重启后再试；确实是 0 项的空壳，用 `rmdir`。
- 空壳目录（0 项内容）回收失败的另类原因：目录内有 0 字节/隐藏文件未被统计——先 `Get-ChildItem -Recurse -Force` 核对项数，再决定 `rmdir`（只删空目录，非空自动失败，安全）。
- 一次 UAC 弹窗处理尽量合并所有需提权的目录，减少打扰。

---

## 五、新增模板（清理+优化双线）

### 10. 自启动项审计（对应 `startup-audit.md`）

完整脚本见 `references/startup-audit.md` 的"完整审计脚本"节。核心逻辑：

> 代码：[`scripts/templates/t10-audit-startup.ps1`](../scripts/templates/t10-audit-startup.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 11. Bloatware 进程批量识别（对应 `bloatware-catalog.md`）

> 代码：[`scripts/templates/t11-detect-bloatware-process.ps1`](../scripts/templates/t11-detect-bloatware-process.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 12. 服务快照（优化前备份，对应 `services-optimization.md`）

> 代码：[`scripts/templates/t12-snapshot-services.ps1`](../scripts/templates/t12-snapshot-services.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 13. 内存基线（优化前后对比，对应 `memory-optimization.md`）

> 代码：[`scripts/templates/t13-baseline-memory.ps1`](../scripts/templates/t13-baseline-memory.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 14. 电源计划与视觉效果（对应 `performance-tuning.md`）

> 代码：[`scripts/templates/t14-show-power-visual.ps1`](../scripts/templates/t14-show-power-visual.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 15. 内存泄漏检测（两次采样对比，对应 `memory-optimization.md`）

> 代码：[`scripts/templates/t15-detect-memory-leak.ps1`](../scripts/templates/t15-detect-memory-leak.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

---

## 六、Shell 扩展审计（2026-08 实战新增）

### 16. 右键菜单 / Shell 扩展审计

审计用户问"我的右键菜单有没有被篡改 / 流氓软件 / 缺失项"时使用。完整对照 `bloatware-catalog.md` 的进程名单判断是否为可疑项。

**前置陷阱**：**永远不要用 `Registry::HKEY_CLASSES_ROOT\*\...` 通配符枚举**——HKCR 树几十万节点，10 分钟都跑不完（参见 pitfalls 60）。

**只读审计脚本**：

> 代码：[`scripts/templates/t16-audit-shell-extensions.ps1`](../scripts/templates/t16-audit-shell-extensions.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

**判读逻辑**：
- **良性**：Name/CLSID 含系统或预期装过的软件关键词（Microsoft / OneDrive / 加密 / WPS / DeskGo）
- **bloatware**：实现路径（InprocServer32）含 360 / 2345 / HaoZip / KuaiZip / SoGou / QQPCMgr / AlibabaProtect / BaiduNetdisk / Meitu 等关键词
- **未知**：都不是。**给用户看**，让用户确认是否认识/需要（不是自动禁用）

---

## 七、新增高价值扫描模板

### 17. 本地 AI 框架与大模型缓存探测（Ollama / HuggingFace / ModelScope / PyTorch / uv / AVD / Gradle）

> 代码：[`scripts/templates/t17-detect-ai-model-caches.ps1`](../scripts/templates/t17-detect-ai-model-caches.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 18. 顽固后台常驻服务与守护进程深度审计（百度网盘/迅雷/搜狗/WPS）

> 代码：[`scripts/templates/t18-audit-resident-daemons.ps1`](../scripts/templates/t18-audit-resident-daemons.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 19. WMI 隐蔽自启动与快捷方式网址劫持审计（WMI / LNK Arguments）

> 代码：[`scripts/templates/t19-audit-wmi-lnk-hijack.ps1`](../scripts/templates/t19-audit-wmi-lnk-hijack.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 20. 3 秒抓弹窗现行工具（原生 Win32 API 弹窗定位器）

> 代码：[`scripts/templates/t20-locate-popup-window.ps1`](../scripts/templates/t20-locate-popup-window.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 21. CompactOS 压缩状态查询与安全管理

> 代码：[`scripts/templates/t21-query-compactos.ps1`](../scripts/templates/t21-query-compactos.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

### 22. WinSxS 组件存储库安全分析与清理（严禁 /ResetBase）

> 代码：[`scripts/templates/t22-analyze-winsxs.ps1`](../scripts/templates/t22-analyze-winsxs.ps1)（只读模板可直接运行；写操作模板默认演练，加 `-Apply` 才执行）

**所有审计 .ps1 一律写到 `$env:TEMP` 或 `C:\Windows\Temp`**，不要放用户目录（参见 pitfalls 64）。
