# 系统级安全清理

除了用户目录下的缓存和残留，Windows 系统层面也有几个安全的清理手段。这些操作不涉及用户文件，但部分需要管理员权限。

## 目录

- 〇、先走微软官方入口（v2.0）
- 〇b、Windows.old
- Windows 磁盘清理工具（cleanmgr）
- 存储感知（Storage Sense）自动清理
- DISM 组件存储清理
- 休眠文件（hiberfil.sys）
- 页面文件（pagefile.sys）（本仓库页面文件的唯一权威节）
- 驱动存储库残留清理（DriverStore / pnputil）
- Delivery Optimization 缓存清理
- 应用/开发缓存的官方清理方式（v2.1）
- 永不删除的目录（硬黑名单）
- 注册表残留检测（可选，需谨慎）
- 微软官方清理入口（优先推荐用户自助）

## 〇、先走微软官方入口（v2.0，2026-11 核对）

普通用户的第一步永远是系统自带入口，脚本只补它覆盖不到的地方（开发缓存、聊天软件、卸载残留）：

1. **设置 › 系统 › 存储 › 清理建议**：分"临时文件 / 大文件或不常用文件 / 已同步到云的文件 / 不常用的应用"四类，每类勾选后单独点"清理"。Windows 会说明为什么建议删，比脚本更安全。
2. **设置 › 系统 › 存储 › 存储感知**：**默认关闭**；如果用户从没动过它而 C 盘空间不足，Windows 可能自动打开它清理部分临时文件并通知用户。打开后默认"磁盘空间不足时运行"，也可以设成按周或按月清临时文件、回收站和"下载"里久未打开的文件。**"下载"文件夹的自动删除默认关闭，替用户打开前必须问**。
3. **"临时文件"里看不到"Windows 更新清理"时**：以管理员身份运行 `cleanmgr` → "清理系统文件"（见下一节）。「存疑」社区报告（Winaero / Windows Latest，2026-02）称 KB5074105 后非提权的"临时文件"扫描不再列出此项；微软文档未说明该项被移除。
4. **"存储"设置里的 UAC 提示**：build 26100/26200.7705（KB5074105，2026-01）起，打开"设置 › 系统 › 存储"会要求管理员确认；**26100/26200.8524（KB5089573，2026-05-26）起改为只在查看"临时文件"时才弹 UAC**。这是正常现象，不是病毒。
5. **不想跑脚本的用户**：微软在存储感知帮助页里推荐 Microsoft PC Assist 做引导式清理；「存疑」它与国内的"微软电脑管家"（Microsoft PC Manager）是否同一应用未核实，两者都是微软官方工具。

依据（访问于 2026-11-11）：Microsoft Support《Free up drive space in Windows》《Manage drive space with Storage Sense》（https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5 ，FAQ "Is Storage Sense on by default?"）；KB5089573 https://support.microsoft.com/en-us/servicing/os/windows-11/2026/05/may-26-2026-kb5089573-os-builds-26200-8524-and-26100-8524-preview 。

## 〇b、Windows.old（升级后 10 天内的回退包，🟠 HIGH）

- 位置 `C:\Windows.old`，大升级后常占 10–30 GB。设置入口：设置 › 系统 › 存储 › 临时文件 → "以前的 Windows 安装"。
- **删掉就不能回退到旧版本**。升级后不足 10 天，"清理建议"里会把"以前的 Windows 版本"列出来，但也会提示这一点。
- 规则：升级后 10 天内默认不动；用户确认新系统一切正常、明确说不回退了，才通过"清理建议"或 cleanmgr 的"以前的 Windows 安装"删除。**不要用 Remove-Item 或改权限硬删**。

## Windows 磁盘清理工具（cleanmgr）

系统自带的磁盘清理工具是最安全的系统级清理方式：

1. 按 Win+R，输入 `cleanmgr`，选择 C 盘
2. 点击"清理系统文件"（这一步很关键，不点的话只清用户临时文件）
3. 勾选：Windows 更新清理、临时文件、缩略图、回收站等
4. 确认后执行

"Windows 更新清理"通常能释放 1-5 GB（旧版本更新包累积），是手动清理很难安全处理的部分。

**高级模式（/sageset /sagerun）：** 默认界面只显示部分项目，`cleanmgr /sageset:99` 会调出隐藏的高级选择器，包含更多可清理项（Windows 错误报告和反馈诊断、Windows 升级日志、临时 Windows 安装文件、系统创建的转储文件等）。把想清理的项目勾选保存为方案 N 后，以后可 `cleanmgr /sagerun:N` 静默复用同一套方案，无需再点对话框——适合把常用清理固化成可重复执行的命令。

## 存储感知（Storage Sense）自动清理

**最推荐的长期方案：让 Windows 自动清理，而不是每次都手动。** 存储感知会在设定周期自动删临时文件、清空回收站。对"磁盘隔三差五就满"的用户，先配置好它再考虑手动清。

开启与配置（设置 → 系统 → 存储 → 存储感知）：

| 配置项 | 推荐值 | 说明 |
|------|------|------|
| 运行存储感知 | 磁盘空间不足时（打开后的默认值）或 每周 | 磁盘较小的机器可设每周 |
| 回收站文件保留 | 30 天 | 回收站不是长期备份，30 天足够反悔期 |
| 下载文件夹清理 | **默认"从不"，谨慎开启** | 开启后会自动删"超过 N 天未打开"的下载文件——安装包、合同、资料可能被误删，且按回收站规则无法找回（「存疑」是否走回收站，微软存储感知页面未说明，按"找不回来"对待）。除非用户确认下载文件夹只放临时物，否则保持"从不"，只让它清临时文件和回收站 |
| 临时文件 | 开启 | 正在使用的文件不会被处理，安全 |
| 本地可用的云内容（OneDrive） | 默认 30 天未打开转在线（Windows 11 22H2 起；只在登录云账户时显示此项） | 只释放本地占位，不删云端文件，安全 |

要点：
- 存储感知**只作用于系统盘（C 盘）**，其他盘需在"高级存储设置 → 其他驱动器上使用的存储"单独处理
- 默认关闭（见上文例外：空间不足且用户从未设置过时 Windows 可能自动打开）；可手动点"立即运行存储感知"
- 它是自动化的"第一道防线"，本技能的手动扫描是"第二道防线"——两者配合而非替代

## DISM 组件存储清理

WinSxS 目录是 Windows 组件存储，会随系统更新不断膨胀。直接删文件极其危险，只能用 DISM 命令安全清理：

```powershell
# 1. 检查健康状态（只读扫描）
Dism /Online /Cleanup-Image /ScanHealth

# 2. 清理被取代的旧组件（安全，推荐）
Dism /Online /Cleanup-Image /StartComponentCleanup

# 3. 彻底清理旧版本备份（激进：之后无法卸载已安装的更新，不可回退）
Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

第一条 `ScanHealth` 只是扫描不修改，可以放心跑。第二条 `StartComponentCleanup` 是安全操作，只删已被新版取代的旧组件；从 DISM 手动运行时会**立即**删除被取代的版本（没有计划任务那样的 30 天宽限期）。第三条带 `/ResetBase` 的比较激进——**已安装的更新包从此不能卸载**（之后安装的新更新仍可卸载），不作为默认操作，只在用户明确接受后使用。

依据：https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder （访问于 2026-11-11）

> ℹ️ **历史问题（Win11 24H2 的 8.63 GB "Windows 更新清理"）**：  
> 2024-10 微软曾把"清理后仍显示约 8.63 GB"列为已知问题，并通过 2024-10-24（KB5044384）及之后的更新缓解；该问题已不在 24H2 发布健康页上。如果用户现在仍看到类似现象，先装最新更新再看。**无论如何都不要手动删 WinSxS 目录**，否则可能导致无法开机或无法再装补丁。
>
> 🔒 **BitLocker 全盘加密前置预检**：  
> Win11 24H2 起更多设备会默认开启 BitLocker 加密。在做深度清理或还原点前，可运行 `manage-bde -status C:`。若处于加密状态，确保已在微软账户（`account.microsoft.com/devices/recoverykey`）中备份 48 位恢复密钥。

## 休眠文件（hiberfil.sys）

如果用户不使用休眠功能（大多数台式机/外接电源笔记本用户不用），可以关闭休眠来释放空间：

```cmd
:: 需要管理员权限的 CMD
powercfg -h off
```

休眠文件默认（full 类型）约为物理内存的 40%（例如 16 GB 内存约 6–7 GB；微软各文档对默认百分比说法不一，以实际文件大小为准）。关闭后文件立即删除，空间立即释放。如果将来想恢复休眠，执行 `powercfg -h on` 即可。

**注意：** 关闭休眠同时会禁用"快速启动"（Fast Startup），开机速度会略慢。对 SSD 用户影响不大。

**折中方案：只保留快速启动**：
```cmd
:: 管理员 CMD。若以前用 /size 自定义过大小，先恢复由系统管理
powercfg /h /size 0
powercfg /h /type reduced
```
reduced 类型比 full **约小 30%**，只支持快速启动（hiberboot），"休眠"选项会消失。

依据：https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options ；https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/compact-os （"Reduces the file by 30%"，访问于 2026-11-11）

## 页面文件（pagefile.sys）

> 本节是本仓库关于页面文件的**唯一权威说明**；drive-migration-official.md、memory-optimization.md 只链接到这里。

**默认建议：保持"自动管理所有驱动器的分页文件大小" / "系统管理的大小"，不要自己定数值。** 微软的说法是页面文件大小"无法一概而论"，取决于系统提交量峰值和崩溃转储设置；系统管理时上限约为 3 × 内存或 4 GB（取大者），且不超过所在卷的 1/8。"内存的 1–1.5 倍"是旧经验，不再作为推荐。

只有 C 盘确实吃紧、且有另一块**本地固定**磁盘（不是 U 盘/移动硬盘）时，才考虑迁移：

1. 右键"此电脑" → 属性 → 高级系统设置 → 性能"设置" → 高级 → 虚拟内存"更改"
2. 取消"自动管理所有驱动器的分页文件大小"
3. 选 D 盘 →"系统管理的大小"→ 设置
4. 选 C 盘：建议**保留一个较小的页面文件或改用系统管理**，而不是"无分页文件"（原因见下）
5. 重启生效

注意：
- **崩溃转储依赖页面文件**：如果系统盘既没有能承载当前转储设置的页面文件，也没有配置专用转储文件（DedicatedDumpFile），蓝屏时**不会写出转储文件**，以后无法排查。所需大小取决于"写入调试信息"的设置（小内存转储很小，"完全内存转储"约为内存 + 257 MB）。
- 不建议完全关闭页面文件：内存吃紧时程序会因提交失败而报"内存不足"或崩溃。
- 「存疑」网上流传的"页面文件最低 1024 MB""关掉会报 0x3B/0x1A 蓝屏"之类说法没有微软来源，不作为依据。

依据：https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows （Last updated 2026-02-12，访问于 2026-11-11）

## 驱动存储库残留清理（DriverStore / pnputil）

**这是最大的系统级盲区之一。** Windows 把驱动存在 `C:\Windows\System32\DriverStore\FileRepository`，安装/更新驱动时旧版本**永不自动删除**（为了支持回滚）。实测案例：11 GB、5000+ 文件、20 多个 NVIDIA 显卡驱动版本堆积（来源：woshub.com/how-to-remove-unused-drivers-from-driver-store）。

⚠️ **绝不允许手动删除 DriverStore 下的任何文件**（微软官方警告），只能通过 pnputil / DISM 管理。

检测流程：

```powershell
# 1. 看存储库总大小（>2 GB 就值得清理）
"{0:N2} GB" -f ((Get-ChildItem $env:windir\System32\DriverStore\FileRepository -Recurse -Force -ErrorAction SilentlyContinue |
    Measure-Object Length -Sum).Sum / 1Gb)

# 2. 列出第三方（非内置）驱动包，找同名多版本
pnputil /enum-drivers

# 3. 或导出全量驱动表（含版本日期，可排重）
dism /online /get-drivers /format:table
```

清理（需管理员，**先建还原点**）：

```powershell
Checkpoint-Computer -Description "BeforeDriversDelete"   # 管理员
# 注：若报错"系统保护未启用"，先在 系统属性→系统保护 里为 C 盘启用，
#     或跳过还原点直接操作（驱动清理本身风险低，但建议保留回滚手段）
pnputil /enum-drivers | Select-String "oem"               # 确认要删的包
pnputil /delete-driver oemXX.inf /uninstall               # 现代官方标准语法（先从设备安全卸载再移除驱动包）
# 若提示驱动正在使用但确认需废弃：pnputil /delete-driver oemXX.inf /uninstall /force
```

规则：同一驱动（同名 INF）保留**最新版本**，删其余旧版。实战案例删除约 40 个旧驱动释放约 8 GB（多数为 NVIDIA）。第三方图形化工具 DevManView 亦可，但 pnputil 最稳。删除后接入新设备需重新联网装驱动（属预期行为）。

## Delivery Optimization 缓存清理

Windows 更新、商店、Edge、Defender 的下载经由 Delivery Optimization（DoSvc，可 P2P）。微软只说明缓存**默认在系统盘（%SYSTEMDRIVE%）**，没有给出固定目录。实机观察到的位置（随版本变化，仅用于只读统计，不要手删）：

- `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache`
- `C:\Windows\SoftwareDistribution\DeliveryOptimization`（较旧版本）

清理方式（按优先级）：
1. **磁盘清理（微软 FAQ 给出的方式）**：`cleanmgr` → 勾选 **"传递优化文件"（Delivery Optimization Files）**。
2. **PowerShell（DeliveryOptimization 模块，管理员）**：
   ```powershell
   Delete-DeliveryOptimizationCache -Force
   ```
3. **不建议手动删除缓存目录**：用上面两种方式即可，它们会由服务自己处理正在使用的文件。

设置 → Windows 更新 → 高级选项 → 传递优化 → 高级选项：这里只用来**限制带宽**、查看活动监视器，不是清缓存的地方。

可选：把缓存放到非系统盘——组策略"**Modify Cache Drive**"（注册表 `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization`，值 `DOModifyCacheDrive`，REG_SZ，可填环境变量、盘符如 `D:` 或路径如 `D:\DOCache`）。这是改系统策略（🟡 MEDIUM），用 `Set-WcoRegistryValue` 先演练、记录撤销。

依据（访问于 2026-11-11）：https://learn.microsoft.com/en-us/powershell/module/deliveryoptimization/delete-deliveryoptimizationcache ；DO FAQ https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-faq ；DO reference https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference

## 系统崩溃转储（Crash Dump）与错误报告清理

当 Windows 蓝屏或桌面程序崩溃时，系统会在 C 盘保留转储快照，积攒过多会虚耗数 GB 空间：

- **系统核心转储**：`C:\Windows\MEMORY.DMP`（蓝屏全内存转储，常占 1GB~10GB）
- **内核小转储**：`C:\Windows\Minidump\`（每次蓝屏生成的 `.dmp` 记录）
- **应用错误报告**：`%LOCALAPPDATA%\CrashDumps`、`C:\ProgramData\Microsoft\Windows\WER`

**安全清理原则（对标 ChrisTitusTech winutil & Optimizer）**：
若当前电脑运行稳定，且用户不需要排查历史蓝屏 dump 日志，以上文件属于 🟢 LOW 级缓存，优先通过 `cleanmgr`（勾选"系统错误内存转储文件"）释放；用户目录下的 `%LOCALAPPDATA%\CrashDumps` 也可用模板 7 `t07-safe-recycle.ps1 -Path … [-Apply]`（`Invoke-WcoRecycle`）移入回收站。

## 应用/开发缓存的官方清理方式（v2.1）

原则：**能用应用自带的"清除缓存"或官方命令，就不手删目录**；手删只作兜底，并且一律走模板 7（`Invoke-WcoRecycle`，进回收站）。清理前先关掉对应程序。

| 目标 | 常见位置（只读统计用） | 推荐做法 | 风险 / 说明 |
|---|---|---|---|
| DirectX 着色器缓存 | `%LOCALAPPDATA%\D3DSCache` | 磁盘清理 `cleanmgr` 勾选 **"DirectX 着色器缓存"**（DirectX Shader Cache） | 🟢 会自动重建，首次进游戏可能略卡 |
| NVIDIA 着色器缓存 | `%LOCALAPPDATA%\NVIDIA\DXCache`、`GLCache` | 先用上面的磁盘清理项；「存疑」磁盘清理是否覆盖 NVIDIA 自己的目录未核实，不覆盖时可在 NVIDIA 控制面板调整"着色器缓存大小"，或关游戏后用模板 7 移入回收站 | 🟢 会自动重建 |
| NVIDIA 驱动下载缓存 | `C:\ProgramData\NVIDIA Corporation\Downloader` | 驱动安装器未运行时用模板 7 移入回收站（社区来源） | 🟢；`…\NVIDIA Corporation\Installer2` **只报告不删** |
| 剪映专业版缓存 | `%LOCALAPPDATA%\JianyingPro\User Data\Cache` 等 | 应用内：**全局设置 → 清除缓存**（菜单路径来自社区文章，「存疑」以当前版本界面为准） | 🟢 不影响草稿，已用素材需重新下载；**不要删草稿目录** |
| Adobe 媒体缓存 | `%APPDATA%\Adobe\Common\Media Cache Files`、`Media Cache` | 应用内（Premiere Pro / After Effects 等）：**首选项 → 媒体缓存 → 删除**，也可在此把位置改到 D 盘（「存疑」各版本菜单名略有差异） | 🟢 预览需重新生成 |
| conda 包缓存 | `<安装目录>\pkgs`、`%USERPROFILE%\.conda\pkgs` | `conda clean --all --dry-run` 先看清单，确认后去掉 `--dry-run` | 🟢 需要时重新下载 |
| Maven 本地仓库 | `%USERPROFILE%\.m2\repository` | 按项目 `mvn dependency:purge-local-repository`；整库不用了再用模板 7 移入回收站 | 🟢 需联网重下；**`settings.xml` 不要删** |
| Gradle 缓存 | `%USERPROFILE%\.gradle\caches`（或 `GRADLE_USER_HOME`） | 先 `gradle --stop`；Gradle 会自动清理长期未用的缓存，一般无需手动；确需释放再用模板 7 移入回收站 | 🟢 下次构建重新下载 |
| Defender 扫描历史 | `C:\ProgramData\Microsoft\Windows Defender\Scans\History` | **不手删**。在"Windows 安全中心 › 病毒和威胁防护 › 保护历史记录"查看；保留期由 Defender 官方参数 `ScanPurgeItemsAfterDelay` 控制（改它属于改 Defender 配置，需用户明确同意） | 该目录受 Defender 保护，手删可能失败或干扰隔离区 |

依据（访问于 2026-11-11）：conda https://docs.conda.io/projects/conda/en/latest/commands/clean.html ；Maven https://maven.apache.org/plugins/maven-dependency-plugin/purge-local-repository-mojo.html ；Gradle https://docs.gradle.org/current/userguide/directory_layout.html ；Defender https://learn.microsoft.com/en-us/defender-endpoint/configure-remediation-microsoft-defender-antivirus ；磁盘清理 https://support.microsoft.com/en-us/windows/free-up-drive-space-in-windows-85529ccb-c365-490d-b548-831022bc9b32 。剪映、Adobe、NVIDIA 下载缓存的路径与菜单来自社区文章，未找到厂商官方页面。

**统计口径：硬链接只算一次。** WinSxS、微信 4.x（旧 `WeChat Files` 迁移到 `xwechat_files` 时优先用硬链接）里有大量硬链接，同一份数据会出现在两个目录。资源管理器"属性"和递归求和都会重复计算，删掉其中一个目录**释放的空间可能远小于它显示的大小**。估算可释放空间时按文件 ID 去重（WizTree 等读 MFT 的工具默认如此），或对可疑文件用 `fsutil hardlink list <文件>` 查看。

## 永不删除的目录（硬黑名单）

下面这些目录看起来很大、名字像缓存，但**删了会导致修复、卸载、更新或系统恢复失败，且通常无法恢复**。扫描只报告大小，不给删除建议：

| 目录 | 是什么 | 正确做法 |
|---|---|---|
| `C:\Windows\WinSxS` | 组件存储（含大量硬链接） | 只用 DISM `StartComponentCleanup`（见上文） |
| `C:\Windows\Installer` | MSI 安装缓存，卸载/修复/打补丁要用 | 绝不触碰；不用的软件走正常卸载，由卸载器自己清 |
| `C:\ProgramData\Package Cache` | VS、VC++ 运行库、.NET、SQL Server 等的安装源 | 不删；卸载不用的产品，或按微软文档用 Visual Studio 安装程序的 `--nocache` 方式管理 |
| `C:\Recovery` | 可能存放 WinRE / 厂商恢复映像 | 不删；`reagentc /info` 只读查看 WinRE 位置 |
| `C:\Windows\System32\DriverStore` | 驱动存储库 | 只用 pnputil（见上文） |

依据：Package Cache https://learn.microsoft.com/en-us/visualstudio/install/disable-or-move-the-package-cache?view=visualstudio （访问于 2026-11-11）。

## 注册表残留检测（可选，需谨慎）

卸载软件后 `HKCU\Software`、`HKLM\SOFTWARE`、`HKEY_USERS\.DEFAULT\Software` 可能残留孤儿键。**只读检测 + 用户确认 + 备份后删除**，切勿批量删：

```powershell
# 只读列出：与已安装应用列表交叉比对（匹配词构建方法见主文件 1.4）
Get-ChildItem 'HKCU:\Software' -ErrorAction SilentlyContinue | ForEach-Object {
    # 对每个键判断是否与 installedLower 匹配，无匹配输出为"疑似残留"
}
# 删除：用 Remove-WcoRegistryKey -Path <键> （默认演练；-Apply 时先 reg export 备份，
#       撤销 = reg import；拒绝 HKLM:\SOFTWARE、\SOFTWARE\Microsoft*、Classes 根等共享键）
# 卸载后的残留候选优先用 Find-WcoLeftover 打分（只读），见 software-uninstall.md
```

注意：注册表键与软件名不一定对应（公司名、GUID 键常见），误删会影响其他软件。**建议只在用户明确要求"卸载不干净"场景下做，且逐项确认**。注册表清理对释放磁盘空间几乎无帮助（KB 级），主要价值是"干净"。

## 微软官方清理入口（优先推荐用户自助）

以下官方功能比手动删更安全，扫描/方案阶段应优先推荐：

| 功能 | 入口 | 说明 |
|------|------|------|
| Storage Sense | 设置 → 系统 → 存储 → 存储感知 | 自动清理临时文件/回收站，可设周期；**详细配置见上文"存储感知"节** |
| 清理建议 | 设置 → 系统 → 存储 → 清理建议 | Win11：临时文件/大文件/云同步文件/未用应用 分类列表 |
| Disk Cleanup | 运行 `cleanmgr` → "清理系统文件" | 含 Windows 更新清理（旧版更新包 1-5 GB）；**高级模式 `cleanmgr /sageset:99` + `/sagerun:99` 见上文** |
| wsreset.exe | 运行 `wsreset` | 重置 Microsoft Store 缓存 |
| 更改新内容保存位置 | 设置 → 系统 → 存储 → 高级存储设置 | 把新应用/文档/下载默认存到 D 盘，从源头缓解 C 盘 |
| OneDrive 文件按需 | OneDrive 设置 → 文件按需 | 云端文件只留占位符，本地释放空间 |

来源：support.microsoft.com 官方"Free up drive space in Windows"指南。
