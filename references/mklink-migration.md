# 符号链接迁移（mklink 通用指南）

<!-- skill-doctor: allow-block SEC002（命令示例路径用 <user> / %用户名% 占位，无真实用户路径） -->

> 本指南覆盖 Windows 上**任意目录**通过 `mklink /J`（junction）从 C 盘迁移到其他盘位的通用方法。TRAE、VS Code、JetBrains、Kimi、Claude 等都适用，**但不是所有软件都兼容**——开始前必读"兼容性矩阵"和"测试与回退"。
>
> ⚠️ **重要前提**：mklink 是**最后手段**。动手前先读 `drive-migration-official.md` 的官方方案优先决策树——微信/QQ/Steam/浏览器/开发工具/云盘大多有官方迁移能力，用了就完全不碰 mklink 风险。只有官方无方案且路径硬编码时，才走本指南。

---

## 目录

- [概念与原理](#概念与原理)
- [兼容性矩阵（通用）](#兼容性矩阵通用)
- [何时不该用 mklink](#何时不该用-mklink)
- [通用六步操作流程](#通用六步操作流程)
- [复制工具的通用坑](#复制工具的通用坑)
- [特殊场景：含稀疏文件 / 大型虚拟磁盘](#特殊场景含稀疏文件--大型虚拟磁盘)
- [典型软件迁移路径速查](#典型软件迁移路径速查)
- [兼容性测试与回退](#兼容性测试与回退)
- [Symlink vs Junction 选择](#symlink-vs-junction-选择)
- [权限与多用户注意](#权限与多用户注意)

---

## 概念与原理

`mklink /J` 是 Windows 内置的目录链接（junction）命令，创建的是**文件系统层面的透明重定向**：

- 应用程序通过 `C:\Users\<user>\AppData\Roaming\MyApp` 访问时，OS 自动解析到 `D:\Data\MyApp`
- 大多数应用感知不到差异（特别是 Electron / .NET / Win32 标准 API）
- 链接存放在 NTFS 父目录的元数据里，不需要额外服务

**核心价值**：C 盘占用大的软件目录，物理搬到 D 盘，逻辑路径不变，应用正常使用，C 盘腾出空间。

---

## 兼容性矩阵（通用）

> 数据来源：实际调研综合（Microsoft Learn、Stack Overflow、GitHub Issues、各软件官方文档、社区论坛）。"未验证"指调研时找不到公开用户案例，但基于架构分析预期可用。

### ✅ 完全兼容（推荐用 mklink）

| 类别 | 软件 |
|------|------|
| AI 桌面客户端 | TRAE / TRAE Solo / TRAE Work、CherryStudio、Cursor、WorkBuddy、通义千问 Qwen Desktop、豆包 Doubao |
| IDE / 编辑器 | VS Code、Sublime Text、Vim / Neovim（推荐用 XDG 环境变量）、Eclipse |
| API 客户端 | Postman、Insomnia |
| 浏览器 | Chrome / Edge（缓存可用 junction，配置文件更推荐用 Profile 迁移）、Firefox |
| 聊天 | Discord、Slack、Telegram Desktop |
| 邮件 | Thunderbird（推荐用 about:profiles） |
| 笔记 | Obsidian（纯文件，推荐用 Vault 位置）、Notion Desktop |
| 游戏平台 | Steam、Epic Games、Battle.net |
| 媒体 | Spotify、VLC、mpv |

### ⚠️ 部分兼容（可用 mklink，但有功能损失或更优替代）

| 软件 | 问题 | 推荐替代方案 |
|------|------|--------------|
| **JetBrains IDEs** (IntelliJ / PyCharm / WebStorm 等) | 文件监视器在 junction 边界不可靠 | 用 `idea.properties` 自定义路径（`idea.config.path` / `idea.system.path` / `idea.cache.path` / `idea.log.path`） |
| **Android Studio** | SDK 路径验证失败 | 用 `ANDROID_HOME` + `idea.properties` |
| **Git for Windows** | 大仓库的 pack 文件内存映射 I/O 受影响 | 用 `HOME` 环境变量 |
| **Node.js / npm / pnpm / yarn** | 全局包内含符号链接，junction 边界混乱 | `npm config set prefix` / `pnpm store` / `yarn config set cacheFolder` |
| **Unity / Unreal Engine** | 项目 Library/Temp 内部用了 junction | 用 `mklink /D`（symlink）或 IDE 配置 |

### ❌ 不兼容（强烈不建议用 mklink）

| 软件 | 原因 | 正确做法 |
|------|------|---------|
| **Docker Desktop** | WSL2 ext4 文件系统不识别 junction；Hyper-V 用 VHD。**用安装器参数**：`--wsl-default-data-root`、`--hyper-v-default-data-root` | `drive-migration-official.md` §3.5 |
| **Microsoft Outlook** | 微软官方警告禁止移动 PST/OST；MAPI profile 路径硬编码 | 用内置"邮箱数据文件位置" |
| **OneNote** | 与 OneDrive 深度集成，硬编码路径 | OneDrive 已知文件夹移动（`drive-migration-official.md` §2.2） |
| **OneDrive** | OneDrive 自身用 reparse point（占位符），junction 与之冲突会损坏同步 | OneDrive 官方"更改文件夹位置"（`drive-migration-official.md` §2.2） |
| **微信 PC (WeChat)** | 中文路径、硬编码路径，已知会导致文件损坏 | **应用内"文件管理→更改保存位置"**（`chat-apps-migration.md`） |
| **QQ** | 硬编码注册表路径，会话数据可能丢失 | **应用内"文件管理→更改默认存储路径"**（`chat-apps-migration.md`） |
| **钉钉 (DingTalk)** | 企业功能依赖硬编码安装路径 | `chat-apps-migration.md`（且缓存不支持改盘符） |

> ⚠️ **不兼容列表不是绝对的**：部分软件可能在新版本修复，但调研时无证据支持安全。出现这种情况，**先优先找官方迁移能力**（见 `drive-migration-official.md` 决策树），官方没有再考虑"测试 junction 试一次"。

---

## 何时不该用 mklink

**mklink 不是万能解药**，遇到以下场景请优先考虑其他方案：

| 场景 | 替代方案 |
|------|----------|
| 软件有**官方配置项**可改路径 | 直接用配置（更稳，零风险） |
| 软件**已停止维护**且数据格式陈旧 | 先清理/导出再重装，不冒迁移风险 |
| 软件**频繁更新**且更新器校验路径 | 先观望，等更新器支持自定义路径 |
| 目标盘**与系统盘不同文件系统** | 不适用（NTFS→ReFS/网络盘要用 symlink 不一样） |
| **不确定是否兼容** | 见下方"测试与回退"先试一次 |

---

## 官方限制与真实失败案例（迁移前必读）

> 本节所有结论都来自可核验来源（微软官方文档 / Stack Overflow / GitHub issue / 社区复盘），**不是社区玄学**。一句话结论：**微软从未官方支持"用 junction 搬 AppData"；官方通道是文件夹重定向（Folder Redirection），且官方清单明确不含 AppData\Local。**

### 官方限制（微软文档可直接引用）

| 限制 | 官方依据 | 实操含义 |
|------|---------|---------|
| junction（reparse point）是其上目录**必须为空**时创建 | [Reparse Points](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points) | 先移走数据再建链接，顺序不可反 |
| **单路径最多 63 个 reparse point**（完整限定路径时 31） | 同左 | 嵌套多层 junction（AppData 内再加）会撞上限 | <!-- skill-doctor: allow CK001（跨对象数字误报：63=NTFS 单路径 reparse point 上限，与 pitfalls.md/scan-scripts.md 的"6 个月"残留判定阈值无关） -->
| reparse point 使文件系统行为偏离多数开发者预期；**备份/杀软/索引必须特判 reparse point** | [Reparse Points and File Operations](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points-and-file-operations) | 这是"为什么部分备份/杀软/同步在 junction 下异常"的官方根源 |
| VSS 备份**不得穿越 junction 遍历内容**，否则重复备份/循环 | [VSS: Junction Points](https://learn.microsoft.com/en-us/windows/win32/vss/junction-points) | 系统还原/备份对 junction 目标覆盖可能不完整 |
| **文件夹重定向官方清单**：AppData/Roaming、Desktop、Documents、Downloads、Favorites、Links、Music、Pictures、Saved Games、Searches、Start Menu、Videos —— **不含 AppData\Local** | [Folder Redirection（GPO）](https://learn.microsoft.com/en-us/windows-server/storage/folder-redirection/folder-redirection-using-group-policy) | 想用"官方受支持"的方式搬数据，用文件夹重定向（`drive-migration-official.md` §2.1），别用 junction 硬搬 Local |
| Windows Store 应用 exe 本身就是 AppExecLink reparse point | [Reparse Point Tags](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-tags) | 整盘 junction 迁移 WindowsApps/Packages 易损坏 |

### 真实失败案例（按类别，均带来源）

| 软件/场景 | 症状 | 原因（证据级别） | 来源 |
|-----------|------|-----------------|------|
| Windows 整体搬 `C:\Users\<user>\AppData` | 开始菜单、通知、任务栏失灵 | 社区现象，shell 基础设施对 AppData 路径敏感（推测） | [SuperUser](https://superuser.com/questions/1657262/i-moved-the-appdata-folder-now-the-start-menu-and-notifications-menu-isnt-work) |
| 系统升级时 Users 挂了 junction | 升级成功与否不一；`C:\Windows\Installer` 的 junction 被移除致卸载/更新故障 | 社区报告，无官方定论 | [SuperUser](https://superuser.com/questions/922478/windows-10-upgrade-and-junctions) |
| 把 `C:\Windows\SoftwareDistribution` 做 junction | `net start wuauserv` 报"找不到路径" | 社区案例（官方采纳答案判定根因是 mklink 语法错误，但结论仍是：该目录操作极易出错） | [SuperUser](https://superuser.com/questions/896926/update-junction-in-windows-8-1) |
| 迁移 `C:\Windows\Installer` 省空间 | 软件修复/卸载/更新失效 | 社区记录 + CSDN 复盘 | [SuperUser](https://superuser.com/questions/922478/windows-10-upgrade-and-junctions) 答案 2、[CSDN](https://blog.csdn.net/weixin_29274337/article/details/158326683) |
| **Chrome 程序目录** `Program Files\Google` 做 junction | **Chrome 直接闪退**，默认浏览器注册失效 | 新版 `App-Bound Encryption` 绑定安装路径，检测物理路径(`D:\`)与注册表路径(`C:\`)不一致（社区分析，含报错日志） | [CSDN 复盘](https://blog.csdn.net/weixin_63093824/article/details/161697353) |
| Chrome **User Data** 目录 junction 到第二块硬盘 | 长期稳定后每天多次 APPCRASH | 社区观察（原帖已关闭） | [TenForums 转载帖](https://www.windowsphoneinfo.com/threads/chrome-appcrash-when-using-symbolic-link-or-junction-for-user-data.344326/) |
| **OneDrive** 内 junction 目录 | 双向同步失效、一直"processing changes" | 多起独立报告；微软 Q&A 采纳回答：OneDrive 原生不支持同步 junction，同步的是被指向目录 | [SuperUser](https://superuser.com/questions/1308909/2-way-sync-doesnt-work-in-onedrive-when-using-symbolic-links-or-junctions)、[Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/1327239/onedrive-shortcuts-symlinks-and-junctions) |
| **MSIX 应用**（如 Claude Desktop）的 `%APPDATA%\Claude` 含 junction | 会话卡片无法保存（伪 EEXIST） | MSIX 写虚拟化排除项未覆盖 junction 路径 | [GitHub issue](https://github.com/anthropics/claude-code/issues/83584) |
| **Codex Desktop** `%LOCALAPPDATA%\OpenAI\Codex` junction 目标被删 | 应用反复退出/重置，无法初始化 | junction 目标失效 = 功能全灭 | [GitHub issue](https://github.com/openai/codex/issues/39475) |
| **WSL2** 目标盘为 SD 卡/可移动介质 | WSL 内访问报 I/O error | 微软工程师参与回复，junction 目标盘必须为固定 NTFS 卷 | [microsoft/WSL issue](https://github.com/microsoft/WSL/issues/4943) |
| Firefox 等便携软件 `AppData\Roaming\Mozilla` junction 被**随机删除** | 链接消失 | 应用关闭时用 `rmdir` 清残留目录，`rmdir` 对 junction 直接删链接为主因之一 | [SuperUser](https://superuser.com/questions/958452/directory-junction-keeps-being-deleted) |
| 备份/增量同步对 junction 目录 | 不递归备份 / 漏备份 | 运维场景（robocopy `/XJ` 显式处理） | [Spiceworks](https://community.spiceworks.com/t/having-issues-with-using-mklink-to-create-junctions-to-appdata-folders/835305) |

### 兼容性预检清单（判定一个软件能不能 junction）

**第一步：能走官方通道的一律不走 junction**（`drive-migration-official.md` 决策树）。官方通道覆盖：OneDrive / 文档类、Steam、微信/QQ、WSL、Chrome、以及 npm/pnpm/IDE 等（均有官方迁移能力）。

**第二步：红灯项（命中任一即否决或降级为只迁纯缓存）**：

| 检查项 | 判定问题 |
|--------|---------|
| 有自更新器/安装器/增量升级 | 更新器常按"原路径删除-重建"或校验路径（Chrome、Codex、Installer 均栽于此）|
| 是 MSIX / UWP / Store 应用 | WindowsApps exe 是官方 AppExecLink reparse point；MSIX 有写虚拟化排除问题 |
| 涉及云同步/网盘（OneDrive 等） | 已证实不支持 junction 目录同步 |
| 有文件监视/索引/实时备份组件 | 官方明确 reparse point 对备份/扫描/USN 读取特殊 |
| 应用有"关闭时清残留目录"行为（便携类） | 分隔链接会被应用当残留删掉 |
| 目标盘是 SD 卡/U 盘/移动硬盘 | 盘符切换全盘失效（WSL I/O error 实证）|
| 有安全组件绑定安装路径（如新版 Chrome App-Bound）| 路径不匹配即拒绝解密/闪退 |
| 多组件共享路径（浏览器/Office C2R）| 只迁一部分会造成"分裂大脑" |
| 属于系统级目录（Users、Windows\Installer、SoftwareDistribution、WindowsApps、Program Files）| 升级/更新/服务可能移除或失败 |
| 路径含空格/非 ASCII，或嵌套层数深 | 引号语法高频翻车；63 个 reparse 上限、260 上限 |

**第三步：绿区建议**：单个、无更新器、无路径校验的**静态数据/纯缓存目录**相对稳妥（仍建议优先用应用内设置）。

---

## 通用六步操作流程

无论迁移哪个软件的目录，通用流程如下。**关键原则：复制验证通过后再删原目录，任何操作都能回退**。

### 第一步：完全退出目标应用

- 关闭应用主窗口
- 任务管理器确认无残留进程（同名 / 关联子进程）
- 部分后台服务（Windows 服务、计划任务）也需要停——参考软件官方说明

### 第二步：选择目标位置并创建目标目录

```cmd
mkdir "D:\AppData\MyApp"
```

**目标目录命名建议**：
- 避免使用 `- AppData` 后缀（本技能残留检测会把这种目录误判为"软件搬家旧备份"）
- 推荐格式：`D:\AppData\Roaming\MyApp` 或 `D:\AppData\Local\MyApp`

### 第三步：复制源目录到目标位置

**混合策略最稳**（原因见下方"复制工具的通用坑"）：

```cmd
:: Step A: xcopy 复制主体（速度快，不展开稀疏文件，不跟 junction）
xcopy /E /I /H /Y /Q "C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>" "D:\AppData\<Roaming|Local>\<AppFolder>"
```

```powershell
# Step B: 对含稀疏文件 / 长路径 / 大虚拟磁盘镜像的子目录，用 robocopy /XJ 补充
# 必须写成 .ps1 脚本用 powershell -File 执行，bash/cmd 下 /E /XJ 会被当路径解析
$robocopyArgs = @('"C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>\<SubFolder>"',
                   '"D:\AppData\<Roaming|Local>\<AppFolder>\<SubFolder>"',
                   '/E', '/XJ', '/R:1', '/W:1')
Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
```

### 第四步：验证复制完整性

```powershell
$src = Get-ChildItem "C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>" -Recurse -Force -File -EA SilentlyContinue
$dst = Get-ChildItem "D:\AppData\<Roaming|Local>\<AppFolder>" -Recurse -Force -File -EA SilentlyContinue
$srcSum = ($src | Measure-Object Length -Sum).Sum
$dstSum = ($dst | Measure-Object Length -Sum).Sum
Write-Host "源: $($src.Count) 文件 / $([math]::Round($srcSum/1MB,2)) MB"
Write-Host "目标: $($dst.Count) 文件 / $([math]::Round($dstSum/1MB,2)) MB"
# 文件数应一致（±几十属正常），大小差异应 < 10 MB（除非含稀疏文件）
```

**如果差异巨大**，用目录级 breakdown 定位是哪个子目录出问题。

### 第五步：删除源目录 + 创建 junction

**删除源目录**（用 SendToRecycleBin，可恢复）：
```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
    'C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>',
    'OnlyErrorDialogs', 'SendToRecycleBin')
```

**创建 junction**（优先用 `/J`，不需要管理员权限）：
```cmd
mklink /J "C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>" "D:\AppData\<Roaming|Local>\<AppFolder>"
```

### 第六步：验证应用功能

1. 启动应用
2. 验证配置 / 数据完整性
3. 验证文件监听是否正常（新建/修改文件，应用是否感知）
4. 验证更新器（如果有）

```powershell
# 验证 junction 是否生效
$item = Get-Item "C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>" -Force
($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0  # 应为 True
```

---

## 复制工具的通用坑

| 工具 | 优点 | 坑 | 适用场景 |
|------|------|----|----------|
| **xcopy** `/E /I /H /Y /Q` | 快速，不跟 junction，不展开稀疏文件 | 260 字符路径长度限制；深层 `node_modules` 会跳过 | **通用首选**，覆盖 80% 场景 |
| **robocopy** `/E /XJ` | 支持长路径，多线程 `/MT:8` | 默认跟 junction → 文件重复；默认展开稀疏文件 → 体积膨胀 2-3 倍 | 含稀疏文件子目录时用 `/XJ` |
| **Copy-Item** `-Recurse` | PowerShell 原生，保持稀疏属性 | 大目录极慢；错误处理不如 robocopy | 小目录、稀疏文件保留 |
| **robocopy `/MIR`** | 双向镜像 | 不适合初次复制（会清空目标新增内容） | **仅用于清理坏副本**（见下方） |

### 通用注意事项

1. **bash/cmd 下不能直接传 robocopy 参数**：`/E`、`/MIR` 会被 shell 当路径解析。**必须写成 .ps1 脚本用 `powershell -File` 执行**。

2. **稀疏文件（sparse file）**：逻辑大小远小于分配大小（如 VMCache 虚拟磁盘镜像）。**robocopy 会展开成完整大小，导致目标膨胀 2-3 倍**。验证步骤发现目标明显大于源时，说明稀疏文件被展开了——改用 `Copy-Item -Recurse` 复制该子目录，或单独用 xcopy。

3. **260 字符路径限制**：xcopy 对深层路径（特别是 `node_modules`）会跳过。robocopy 支持长路径但有上述稀疏文件问题。**最稳方案：xcopy 复制主体 + robocopy `/XJ /E` 补充长路径子目录**。

---

## 特殊场景：含稀疏文件 / 大型虚拟磁盘

某些软件（TRAE VMCache、WSL2 vhdx、Docker VHD 等）使用**稀疏文件**模拟大容量虚拟磁盘，逻辑大小可能几百 MB 但分配了几十 GB。直接用 robocopy 复制会让目标体积膨胀数倍。

**识别方法**：
```powershell
# 查看文件是否稀疏
fsutil sparse queryflag "目标文件路径"
# 或查看"实际占用 vs 逻辑大小"
(Get-Item "路径").Length  # 逻辑大小
fsutil file layout "路径"  # 详细分配信息
```

**处理策略**：
- xcopy 不展开稀疏属性（保留）——**推荐**
- robocopy 默认展开——必须加 `/XJ` 且验证目标大小
- Copy-Item 保留稀疏属性——适合单个大文件

**典型案例**：TRAE SOLO CN 的 `VMCache` 子目录包含虚拟磁盘镜像，迁移时**单独用 xcopy** 而不是整体 robocopy。

---

## 典型软件迁移路径速查

下表汇总常见软件的 AppData 路径与迁移建议：

| 软件 | 主要数据路径（默认） | 迁移建议 |
|------|----------------------|----------|
| **TRAE / TRAE Solo** | `%APPDATA%\TRAE SOLO CN` + `%USERPROFILE%\.trae-cn` | 整体可迁移；VMCache 用 xcopy |
| **VS Code** | `%APPDATA%\Code` + `%USERPROFILE%\.vscode\extensions` | 可 junction；或用 Portable Mode |
| **Cursor** | `%LOCALAPPDATA%\Cursor` + `%APPDATA%\Cursor` | 可 junction |
| **JetBrains IDEs** | `%APPDATA%\JetBrains\<IDE>` + `%LOCALAPPDATA%\JetBrains\` | **优先用 idea.properties** 而非 junction |
| **Kimi Desktop** | `%APPDATA%\Kimi` 或 `%LOCALAPPDATA%\Kimi` | 可 junction（确认实际路径后） |
| **Claude Desktop** | `%LOCALAPPDATA%\Claude` | 可 junction |
| **CherryStudio** | `%APPDATA%\CherryStudio` | 可 junction |
| **WorkBuddy** | `%APPDATA%\WorkBuddy` + `%LOCALAPPDATA%\WorkBuddy` + `%LOCALAPPDATA%\WorkBuddyExtension` | 三个目录都要处理 |
| **通义千问 Qwen** | `%APPDATA%\Qwen` + updater 单独 | 主数据可 junction；updater 谨慎 |
| **Postman** | `%APPDATA%\Postman` | 可 junction |
| **Chrome 用户数据** | `%LOCALAPPDATA%\Google\Chrome\User Data` | 可 junction 整个 User Data |
| **Steam 游戏库** | 自定义 | Steam 自身支持多 libraryfolder，无需 mklink |

> ⚠️ 表中路径是基于已知架构推断，**实际使用前请在 `%APPDATA%` / `%LOCALAPPDATA%` 确认目录名**。

---

## 兼容性测试与回退

### 测试流程（任何不确定兼容性的软件，都建议先测试）

1. **创建目标目录**（不复制任何内容）
2. **复制少量数据**到目标（不是全量）
3. **创建 junction** 指向这个只包含部分数据的目录
4. **启动应用**，观察：
   - 是否能正常打开
   - 是否能创建新数据
   - 是否能读写现有数据
5. **关闭应用**，删除 junction，把数据移回原位
6. 如果测试通过，再做正式全量迁移

### 回退操作

**junction 本身出问题**（应用无法启动 / 数据丢失）：
```cmd
:: 删除 junction（不会删除 D 盘目标数据）
rmdir "C:\Users\<user>\AppData\<Roaming|Local>\<AppFolder>"

:: 如需彻底回滚，把 D 盘数据移回 C 盘原位（重复通用流程反向操作）
```

**迁移中产生了坏副本**（如 robocopy 膨胀后目标）：

1. **Rename-Item 改名**（瞬间完成，比 Remove-Item 快得多）：
   ```powershell
   Rename-Item "D:\坏副本路径" "D:\坏副本路径.bad"
   ```
2. **robocopy 空目录镜像法快速清空**（永久删除，不走回收站——仅在确认是坏副本时使用）：
   ```cmd
   mkdir %TEMP%\_empty
   robocopy "%TEMP%\_empty" "D:\坏副本路径.bad" /MIR /R:0 /W:0 /NFL /NDL /NJH /NJS
   rmdir "D:\坏副本路径.bad"
   rmdir "%TEMP%\_empty"
   ```
3. 然后重新走通用流程

### 调试工具

- **Process Monitor**（Sysinternals）：监控应用的 `ACCESS_DENIED` / `PATH_NOT_FOUND` 错误
- **Event Viewer**：查看应用错误日志
- **fsutil reparsepoint query**：检查 junction 状态

---

## Symlink vs Junction 选择

| 场景 | 推荐 | 原因 |
|------|------|------|
| 同机本地目录迁移 | **`mklink /J`**（junction） | 不需要管理员权限；功能对本地迁移完全够用 |
| 跨网络共享（UNC 路径） | `mklink /D`（symlink） | junction 不支持 UNC 路径 |
| 链接文件而非目录 | `mklink D`（symlink） | junction 只能链接目录 |
| 需要链接被备份软件识别 | `mklink /D`（symlink） | 部分备份软件不识别 junction |

**本技能场景下 99% 用 junction 即可**——优先 `/J`，简单够用。

---

## 权限与多用户注意

### 权限

- **junction**：继承父目录权限，**不需要管理员权限**
- **symlink**：需要 `SeCreateSymbolicLinkPrivilege`（默认仅管理员）；Win10 1703+ 可在开发者模式下用户级创建

### 多用户场景

- `%APPDATA%` 下的 junction 是用户私有的，每个用户需要单独设置
- `%PROGRAMDATA%` 下的 junction 影响所有用户，需要谨慎处理权限
- 终端服务器 / Citrix 环境：junction 可能不跨会话保留——考虑用组策略的文件夹重定向

---

## 完整实战案例

- TRAE AppData（含稀疏文件陷阱）→ 见 `case-study.md` Case A
- VS Code 用户数据（最常见 IDE 场景）→ 见 `case-study.md` Case B
- 任意软件通用迁移模式 → 见 `case-study.md` Case C

---

## 相关陷阱

详见 `pitfalls.md`：
- 陷阱 11：装到 D 盘不等于 AppData 搬走
- 陷阱 15：mklink 复制工具的坑
- 陷阱 16：非系统盘扫描策略与 C 盘不同
- 陷阱 58：微信/QQ 用 mklink 会损坏数据
- 新增：Edge/Chrome 浏览器"关不彻底"与 OneDrive junction 失效等（`pitfalls.md` 68+）

## 先读官方方案

- 官方优先迁移决策树 + 系统级/软件级全部官方能力 → `drive-migration-official.md`
- 微信/QQ/钉钉专项 → `chat-apps-migration.md`
- mklink 实战案例（TRAE/VS Code/通用） → `case-study.md`
