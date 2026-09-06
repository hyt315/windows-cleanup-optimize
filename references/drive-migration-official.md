# 把 C 盘内容搬到 D 盘：官方方案优先（Drive Migration, Official-First）

<!-- skill-doctor: allow-block SEC002（示例路径多为占位与官方文档引用） -->

> 用户想把"占 C 盘的东西"挪到 D 盘、或反馈"搬了不彻底/总是出问题"——先读本文。
>
> **核心结论（有官方依据）**：**微软从未官方支持"用 mklink/junction 搬 AppData"。** 微软受支持的机制是文件夹重定向（Folder Redirection），且官方清单**明确不含 AppData\Local**。绝大多数"搬不干净"的案例，都是**跳过官方方案直接上 mklink**造成的。正确顺序：

**【官方优先决策树】：**
1. **该软件/组件有没有官方"迁移/改存储位置"能力？** 有 → 用官方 UI 或官方命令（本文第三节）。**这一步覆盖绝大多数场景。**
2. **没有官方迁移能力，但它是"用户文件夹 / OneDrive 已知文件夹"？** 是 → 用系统级官方重定向（本文第二节）。
3. **都没有，但"可以卸载重装到 D 盘 / 换官方便携版"？** 是 → 重装或便携版。
4. **以上都不行，且路径被硬编码在 C 盘** → 才轮到 `mklink /J` 兜底（见 `mklink-migration.md`）。

---

## 目录

- [一、总原则与决策树](#一总原则与决策树)
- [二、系统级（Windows 官方能力）](#二系统级windows-官方能力)
- [三、软件级官方迁移能力](#三软件级官方迁移能力)
- [四、什么时候才用 mklink 兜底](#四什么时候才用-mklink-兜底)

---

## 一、总原则与决策树

| 场景 | 正确做法 | 依据 |
|------|---------|------|
| 微信 / QQ | 应用内"文件管理 → 更改保存位置" | `chat-apps-migration.md` |
| 游戏（Steam/Epic/Xbox） | 平台自带"库文件夹/移动游戏" | 本文 §3.1 |
| 浏览器 | `--user-data-dir` / 官方策略 / about:profiles | 本文 §3.4 |
| 开发工具（npm/pnpm/IDE/Docker/WSL） | 官方配置项 / 官方命令 | 本文 §3.3、§3.5 |
| 用户文件夹（文档/下载/桌面…） | 属性→位置 / OneDrive 已知文件夹移动 | 本文 §2.1-2.2 |
| 以上都不行，路径又硬编码 | 才 mklink（且先做兼容性预检） | `mklink-migration.md` |

---

## 二、系统级（Windows 官方能力）

### 2.1 用户文件夹重定向（文档/下载/桌面/图片/视频/音乐）

**方式 A——单个库文件夹**：文件资源管理器"此电脑"→ 右键"文档"（或桌面/下载/图片…）→ **属性 → 位置 → 移动** → 选 D 盘新建目录 → 系统自动迁移并更新注册表（Known Folders / User Shell Folders）。

**方式 B——新内容默认保存位置**：设置 → 系统 → 存储 → 高级存储设置 → **「新内容的保存位置」** → 把新应用/新文档/新图片/新视频都改为 D 盘。

> **官方依据**（微软官方文章，均可访问）：
> - 「Windows 中的存储设置」含 "Where new content is saved" 章节（新内容默认保存位置）：[英文](https://support.microsoft.com/en-US/windows/experience/storage-filemanagement/storage-settings-in-windows) / [简体中文](https://support.microsoft.com/zh-cn/windows/experience/storage-filemanagement/storage-settings-in-windows)
> - 「释放 Windows 中的驱动器空间」含 "Save new personal files to another drive" 章节：[Free up drive space in Windows](https://support.microsoft.com/en-us/windows/experience/storage-filemanagement/free-up-drive-space-in-windows)
> - OneDrive 托管用户文件夹：[Back up your folders with OneDrive](https://support.microsoft.com/en-us/onedrive/back-up-your-folders-with-onedrive)（中文版 `/zh-cn/` 亦可访问）
>
> 微软**没有**专门写"移动用户文件夹"的独立文章——移动现有文件夹以系统 UI（文件夹属性→位置）为准，官方文字指引就在上面两篇里。**不要手动改 `User Shell Folders` 注册表**——官方 UI 迁移时会自动维护该键，手改无校验易出错。

### 2.2 OneDrive 已知文件夹移动（KFM）

- **官方文档**：https://learn.microsoft.com/en-us/onedrive/redirect-known-folders （实测可访问）
- **入口**：OneDrive 云朵图标 → 设置 → 备份/管理备份 → 勾选"文档/桌面/图片"。
- **与本地重定向的关系（官方明确：二选一，不叠加）**：已把"文档"本地移到 D 盘再开 KFM，OneDrive 会要求先还原到 C 盘原位。**决策**：想跨设备同步 → KFM；只想腾 C 盘留在本机 → 用 §2.1 更简单。
- ⚠️ 官方警告：**不要用 mklink/junction 把 OneDrive 的已知文件夹指向外部盘**会导致数据目录混乱/重复同步（详见 `mklink-migration.md` 失败案例）。

### 2.3 应用商店 / UWP 应用移盘

- 设置 → 应用 → 已安装的应用 → 选中应用 → **移动** → 选 D 盘。仅商店可移动应用支持；传统桌面程序多为灰色不可移动。
- Xbox Game Pass 游戏移盘同机制，官方帮助：https://support.xbox.com/en-US/help/games-apps/troubleshooting/move-xbox-app-games-to-another-drive
- **官方依据**：移动 UWP 应用是系统 UI 内置操作，微软**无独立文章**；新应用安装位置的官方文字指引在「[Windows 中的存储设置](https://support.microsoft.com/zh-cn/windows/experience/storage-filemanagement/storage-settings-in-windows)」里。

### 2.4 页面文件 pagefile.sys 移到 D 盘

1. `Win+R` → `sysdm.cpl` → 高级 → 性能:设置 → 高级 → 虚拟内存:更改。
2. 取消勾选"自动管理所有驱动器分页文件大小"；
3. C 盘设为"无分页文件"（或保留"系统管理"小文件防止崩溃）；
4. D 盘"自定义大小"，初始/最大 = 物理内存 1~1.5 倍 → 确定 → **重启生效**（重启后 `C:\pagefile.sys` 消失）。

> **官方依据**（微软 Learn，均可访问）：
> - [Introduction to page files](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/introduction-to-the-page-file)（页面文件用途=崩溃转储 + 扩展提交上限；默认建议保持"系统管理"）
> - [How to determine the appropriate page file size for 64-bit versions of Windows](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/how-to-determine-the-appropriate-page-file-size-for-64-bit-versions-of-windows)（官方大小判定规则）
>
> 除了省空间，还能显著降低 C 盘磁盘压力。**页面文件不要设为 0**（`pitfalls.md` 34：崩溃转储需要）。

### 2.5 休眠文件 hiberfil.sys

- **官方命令文档**：https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options
- 需管理员：

```powershell
powercfg /h off              # 删除 C:\hiberfil.sys，禁用休眠与快速启动
powercfg /h /type reduced    # 想保留“快速启动”但缩小文件
powercfg /h on               # 恢复
```

> 关闭快速启动的副作用：开机速度不再"秒开"（普通睡眠不受影响）。笔记本用户慎关（影响混合关机/快速开机体验）。

### 2.6 Windows Update 缓存 / 组件存储清理

- **官方命令**：cleanmgr → https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cleanmgr ；DISM → https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism-operating-system-package-servicing-command-line-options

```powershell
cleanmgr /sageset:1    # 弹窗勾选“Windows 更新清理”等
cleanmgr /sagerun:1    # 执行
DISM /Online /Cleanup-Image /StartComponentCleanup   # 清理组件存储（需管理员）
```

> ⚠️ **不要**把 `C:\Windows\SoftwareDistribution` 整个 mklink 到 D 盘（系统更新机制不兼容，见 `mklink-migration.md` 失败案例）。官方推荐用内置清理工具，而非手动删目录。

---

## 三、软件级官方迁移能力

### 3.1 游戏平台

| 平台 | 官方功能 | 操作 | 官方来源 |
|------|---------|------|---------|
| **Steam** | 库文件夹（多盘库）+ 移动安装文件夹 | 设置→下载→内容库→添加库文件夹（D 盘）；库→右键游戏→已安装文件→移动安装文件夹 | [Steam 官方帮助](https://help.steampowered.com/en/faqs/view/4BD4-4528-6B2E-8327)（标题：Moving a Steam Installation and Games） |
| **Epic** | 客户端内”移动”已安装游戏 | 库→游戏”…→移动”→选 D 盘目录 | [官方帮助页:How to move an installed game](https://www.epicgames.com/help/c-32735058/c-36403860/a12469649)（站点反爬 403，URL 与标题已核验；入口见[官方帮助中心](https://www.epicgames.com/help/)） |
| **Xbox / 微软商店游戏** | 设置→应用→移动（同 §2.3） | 选中游戏→移动→选 D 盘 | [Xbox 官方帮助](https://support.xbox.com/en-US/help/games-apps/troubleshooting/move-xbox-app-games-to-another-drive) |

### 3.2 聊天 / 通讯

- **微信 / QQ**：应用内"文件管理 → 更改保存位置"（官方迁移通道）。完整步骤、目录结构、排坑 → `chat-apps-migration.md`。**不要对微信/QQ 用 mklink**（硬编码路径会损坏数据，`pitfalls.md` 58）。
- **Discord**：安装器自带目录选择页，装到 D 盘即可；缓存（`%AppData%\Discord\Cache`）**官方无改路径功能**（社区共识），不折腾。
- **Telegram Desktop**：官方就有 **Windows 便携版**，解压到 D 盘后数据随所在目录走。官方直达：https://telegram.org/dl/desktop/win64_portable （重定向到官方 CDN，实测可访问）。

### 3.3 开发工具链与本地 AI 框架

| 工具 / 框架 | 官方配置 / 机制 | 命令 / 操作 | 官方来源 |
|---|---|---|---|
| **Ollama 本地大模型** | `OLLAMA_MODELS` 环境变量 | 设用户环境变量 `OLLAMA_MODELS=D:\OllamaModels`，重启 Ollama 服务即可将数十 GB 的模型目录整体重定向到 D 盘 | [Ollama 官方 FAQ](https://github.com/ollama/ollama/blob/main/docs/faq.md) |
| **Hugging Face Hub** | `HF_HOME` 环境变量 | 设用户环境变量 `HF_HOME=D:\HF_Cache`，自动将预训练权重和 datasets 从 `%USERPROFILE%\.cache\huggingface` 移至 D 盘 | [Hugging Face Hub 环境变量](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables) |
| **ModelScope 魔搭社区** | `MODELSCOPE_CACHE` 环境变量 | 设用户环境变量 `MODELSCOPE_CACHE=D:\ModelScopeCache`，将默认 `~/.cache/modelscope/hub` 迁移至 D 盘 | [ModelScope 官方文档](https://modelscope.cn/docs) |
| **PyTorch** | `TORCH_HOME` 环境变量 | 设用户环境变量 `TORCH_HOME=D:\TorchCache`，将模型权重从默认 `~/.cache/torch` 迁移至 D 盘 | [PyTorch Hub 官方文档](https://pytorch.org/docs/stable/hub.html) |
| **Python uv 包管理器** | `UV_CACHE_DIR` / CLI 命令 | 设环境变量 `UV_CACHE_DIR=D:\uv-cache`；或运行 `uv cache prune` 安全修剪，`uv cache clean` 清空全局缓存 | [Astral uv 官方文档](https://docs.astral.sh/uv/reference/cli/#uv-cache) |
| **Android AVD 模拟器** | `ANDROID_AVD_HOME` 环境变量 | 设用户环境变量 `ANDROID_AVD_HOME=D:\AndroidAVD`，将数十 GB 的安卓虚拟设备镜像（默认在 `~/.android/avd`）整体移至 D 盘 | [Android 官方环境变量指南](https://developer.android.com/tools/variables#emulator) |
| **npm** | `prefix` / `cache` | `npm config set prefix "D:\nodejs-global"`；`npm config set cache "D:\nodejs-cache"`；把 `D:\nodejs-global` 加入 PATH | [npm Folders](https://docs.npmjs.com/cli/v11/configuring-npm/folders)、[npm Config](https://docs.npmjs.com/cli/v11/using-npm/config) |
| **pnpm** | `store-dir` / `global-bin-dir` | `pnpm config set store-dir "D:\pnpm-store"` | [pnpm Settings](https://pnpm.io/settings) |
| **pip** | `cache-dir` | `pip config set global.cache-dir "D:\pip-cache"`；验证 `python -m pip cache dir` | [pip 配置](https://pip.pypa.io/en/stable/topics/configuration/) |
| **Gradle / Android SDK** | `GRADLE_USER_HOME` / `ANDROID_HOME` | 设用户环境变量 `GRADLE_USER_HOME=D:\gradle-cache`，`ANDROID_HOME=D:\AndroidSDK` | [Gradle 官方配置](https://docs.gradle.org/current/userguide/directory_layout.html) |
| **Git for Windows** | `HOME` 环境变量 | 设用户环境变量 `HOME=D:\git-home` | [git-config 官方](https://git-scm.com/docs/git-config) |
| **JetBrains IDE** | `idea.properties` 重定位 | 复制 `<IDE>\bin\idea.properties`，改 `idea.config.path` / `idea.system.path` / `idea.plugins.path` 到 D 盘 | [Tuning the IDE](https://www.jetbrains.com/help/idea/tuning-the-ide.html) |

### 3.4 浏览器

| 浏览器 | 官方方式 | 操作 | 官方来源 |
|--------|---------|------|---------|
| **Chrome / Chromium** | `--user-data-dir` 或企业策略 `UserDataDir` | 快捷方式目标加 `chrome.exe --user-data-dir="D:\ChromeData"`；或注册表 `HKLM\SOFTWARE\Policies\Google\Chrome\UserDataDir = "D:\ChromeData"` | Chromium [user_data_dir 文档](https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md)、[Chrome 企业策略](https://chromeenterprise.google/policies/) |
| **Microsoft Edge** | 企业策略 `UserDataDir`（同源） | 注册表 `HKLM\SOFTWARE\Policies\Microsoft\Edge\UserDataDir = "D:\EdgeData"`；验证 `edge://policy` | [Edge 企业策略](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies) |
| **Firefox** | 官方 **不提供** 创建时选位置；策略 `ProfileDefaultLocation` | 个人资料默认在 `%APPDATA%\Mozilla\Firefox\Profiles`；`about:profiles` 可查看/新建/切换；手动搬 profile 改 profiles.ini = 社区共识 | [Firefox 官方 KB](https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data)、[Mozilla 策略模板](https://github.com/mozilla/policy-templates) |

> 浏览器缓存建议按 `pitfalls.md` 7：**用浏览器内置"清除缓存"**，不要直接删文件夹。

### 3.5 容器 / 虚拟化

| 工具 | 官方方式 | 操作 | 官方来源 |
|------|---------|------|---------|
| **Docker Desktop** | 设置里改 Disk image location | 设置→Resources→Advanced→**Disk image location** 改 D 盘（**仅 Hyper-V 后端**）；WSL2 后端用下方 WSL2 迁移；CLI 原生清理 `docker system prune -a --volumes` | [Docker 设置文档](https://docs.docker.com/desktop/settings-and-maintenance/settings/)、[Docker + WSL](https://docs.docker.com/desktop/wsl/) |
| **WSL2（稀疏压缩 / 搬盘）** | 官方原生稀疏压缩（Win11 WSL 2.0+）或 export/import | **原生稀疏缩容**：`wsl --shutdown` → `wsl --manage <发行版> --set-sparse true`（自动缩容）；<br>**搬盘重定向**：`wsl --shutdown` → `wsl --export <发行版> D:\backup\my.tar` → `wsl --unregister <发行版>` → `wsl --import <发行版> D:\wsl\<发行版> D:\backup\my.tar --version 2`；<br>**离线 compact 压缩**：`wsl --shutdown` → `diskpart` → `select vdisk file="<ext4.vhdx路径>"` → `compact vdisk` | [WSL 基础命令与管理](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)、[WSL 自定义发行版](https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro) |
| **VirtualBox** | 默认机器文件夹 | 文件→全局设置→General→**Default Machine Folder** 改 D 盘；已有 VM 用菜单"复制/移动"迁移 | [VirtualBox Manual](https://www.virtualbox.org/manual/ch03.html) |
| **VMware Workstation** | 默认虚拟机位置 | 编辑→首选项→工作区→默认虚拟机位置改 D 盘；旧 VM 直接搬目录后"打开" | [官方文档:Configuring the Default Locations for Virtual Machine Files](https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/workstation-pro/17-0/using-vmware-workstation-pro/changing-workstation-pro-preference-settings/configuring-workspace-preference-settings/configuring-the-default-locations-for-virtual-machine-files-and-screenshots.html)（VMware 文档已并入 Broadcom techdocs） |

---

## 四、什么时候才用 mklink 兜底

**适用场景（必须全部满足）**：数据量大；官方**没有任何**改存储位置设置；路径被硬编码在 C 盘；且不是系统受保护组件。此时才考虑 `mklink /J`（参见 `mklink-migration.md`）。

**禁止对以下对象用 mklink**（官方/实测不支持）：
- 系统级：`C:\Windows\SoftwareDistribution`、`C:\Program Files\WindowsApps`、pagefile、hiberfil、`C:\Users` 整体、`C:\Windows\Installer`
- 软件级：OneDrive、微信/QQ/钉钉（硬编码）、MSIX/UWP 应用、新版 Chrome 程序目录（App-Bound 加密绑定路径）
- 目标盘为可移动介质（SD 卡/U 盘）时 WSL 会报 I/O 错误

> 完整失败案例与兼容性预检 → `mklink-migration.md`。

## 五、迁移后统一验证清单（任何迁移方式都适用）

按官方方案迁完，**必须跑完以下验证才算完成**（对照 `pitfalls.md` 78）：

1. **UI 确认**：官方设置界面显示的位置/路径已是 D 盘（微信"文件管理"、Steam"库文件夹"、浏览器 `chrome://version` 的"个人资料路径"等）。
2. **重启回归**：重启后（不手动操作）软件能正常启动，登录态与历史数据可读、可写（新建文件/改设置能保存）。
3. **C 盘占用复查**：一周后对比 C 盘该目录大小是否回升（`Get-ChildItem <路径> -Recurse | Measure-Object Length -Sum`）。回升 = 有组件绕过迁移、就地重建目录（见 `pitfalls.md` 78 的 ProcMon 检测法）。
4. **D 盘体积吻合**：D 盘目标目录体积与迁移前 C 盘源目录量级一致（±10%，含稀疏文件等特殊场景参考 `mklink-migration.md` 复制工具坑）。
5. **更新器复测**：触发一次软件"检查更新"，确认更新功能仍正常（官方迁移路径对更新器通常无影响；junction 兜底的更新器才高危）。

> 迁移后不要立即删除 C 盘的旧备份/旧目录——先按上表验证 1-3 项，确认新路径在稳定工作（建议至少一周），再处理旧数据。

---

## 相关文档

- mklink 兜底方案与失败案例 → `mklink-migration.md`
- 微信/QQ/钉钉 专项 → `chat-apps-migration.md`
- mklink 迁移实战案例（TRAE/VS Code） → `case-study.md`
- 迁移踩坑库 → `pitfalls.md`
