# 迁移实战案例集（含 TRAE 专项）

> 三个代表性案例覆盖不同复杂度：
> - **Case A**：TRAE AppData（含稀疏文件陷阱，最复杂）
> - **Case B**：VS Code 用户数据（最常见的 IDE 场景）
> - **Case C**：任意软件通用模式（无特殊陷阱的快速迁移）
>
> ⚠️ 三个案例都是 **mklink 兜底**：只有 `drive-migration-official.md` 决策树里找不到官方迁移方式时才用。
>
> **v2.1 更正**：旧版把 Case A 的体积膨胀归因于"robocopy 默认展开稀疏文件"，这与微软文档不符——robocopy 默认**保留**稀疏状态（`/sparse` 默认 yes），默认**跟随 junction**（`/XJ` 才排除）。现在统一推荐 `robocopy /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1`，不再用 xcopy（xcopy 默认复制符号链接指向的内容，还有 260 字符限制）。依据：https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy 、https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/xcopy （访问于 2026-11-11）。删除源目录一律先改名、再走模板 7（`Invoke-WcoRecycle`），不直接调用 `DeleteDirectory`。

## 目录

- [Case A: TRAE AppData 迁移到 D 盘（含稀疏文件陷阱）](#case-a-trae-appdata-迁移到-d-盘2026-06-20含稀疏文件陷阱)
  - [背景](#背景)
  - [关键教训总结](#关键教训总结)
  - [迁移过程](#迁移过程)
- [Case B: VS Code 用户数据迁移到 D 盘](#case-b-vs-code-用户数据迁移到-d-盘典型-ide-场景)
  - [VS Code 的官方替代方案：Portable Mode](#vs-code-的官方替代方案portable-mode)
- [Case C: 任意软件通用模式](#case-c-任意软件通用模式无特殊陷阱的快速迁移)
- [三案例对比](#三案例对比)

---

## Case A: TRAE AppData 迁移到 D 盘（2026-06-20，含稀疏文件陷阱）

### 背景

- 源目录：`%APPDATA%\TRAE SOLO CN`（144,011 文件，5,758 MB）
- 目标路径：`D:\zcode\TRAE-Solo-CN-Data`
- 包含 `VMCache` 子目录（沙盒虚拟磁盘镜像，**含稀疏文件**）

### 关键教训总结

| 问题 | 根因 | 解决方案 |
|------|------|----------|
| 目标文件数暴增 3 倍 | robocopy 默认跟随 junction | 加 `/XJ` 排除 junction |
| 目标体积膨胀约 2.5 倍 | 当时归因为"稀疏文件被展开"；按微软文档 robocopy 默认保留稀疏状态，更可能也是**跟随 junction** 造成（「存疑」当时未用 `fsutil sparse queryflag` 核对） | 加 `/XJ`；复制后对大文件跑 `fsutil sparse queryflag` 核对 |
| xcopy 跳过部分文件 | 路径超 260 字符限制 | 直接用 robocopy（支持长路径），不用 xcopy |
| 坏副本删不掉 | Remove-Item 逐文件删除太慢 | 先 Rename-Item 改名（瞬间完成），最后集中清理 |
| 大目录清理慢 | robocopy `/MIR` 输出几十 MB 日志 | 加 `/NFL /NDL /NJH /NJS /NC /NS` 静默模式 |

### 迁移过程

#### 第一步：尝试 robocopy 全量复制 — 失败

使用 `robocopy /E /R:1 /W:1 /MT:8`，结果：

- 源 VMCache：64,079 文件 / 1,313 MB
- 目标 VMCache：209,949 文件 / 3,786 MB

**两个问题同时发生**：

1. **体积膨胀**：目标体积约为源的 2.5 倍。当时判断是 VMCache 里的稀疏文件被展开；按微软 robocopy 文档（`/sparse` 默认保留），这个判断「存疑」，更可能与下一条同源。
2. **junction 跟踪导致文件重复**：robocopy 默认跟随源目录内的 junction point，把 junction 指向的目标内容也复制了一份，导致文件数暴增约 3 倍。

总计目标变成 289,881 文件 / 8,232 MB（源只有 5,759 MB）。

#### 第二步：清理坏副本 — 卡住 → Rename-Item 抢救

`Remove-Item -Recurse -Force` 对 289K 文件的目录极慢，部分文件被锁无法删除。

**解决**：Rename-Item 改名比 Remove-Item 快得多（瞬间完成）。把坏副本改名为 `.bad`，留到最后清理。

#### 第三步：xcopy 复制主体 — 部分成功（现已不推荐 xcopy）

`xcopy /E /I /H /Y /Q` 复制了 80,343 / 144,011 文件。缺的 63,668 个文件全在 VMCache 里——沙盒虚拟磁盘内的 `node_modules` 路径深度嵌套，超过了 Windows 260 字符路径长度限制，xcopy 对这些文件报"系统找不到路径"并跳过。

#### 第四步：robocopy /XJ 补充 VMCache — 成功（加了 /XJ 后体积正常，说明问题出在 junction）

`robocopy /E /XJ /R:1 /W:1`（`/XJ` 排除 junction，`/E` 包含空子目录），57 秒完成：

- 源 VMCache：64,079 文件 / 1,312.93 MB
- 目标 VMCache：64,270 文件 / 1,313.52 MB（几乎一致，微小差异正常）

**最终验证**：源 144,011 文件 / 5,758.64 MB → 目标 144,199 文件 / 5,759.19 MB（差异 188 文件 / 0.55 MB，来自 xcopy 和 robocopy 两次操作的叠加，不影响功能）。

#### 第五步：移走源目录 + mklink /J — 成功

当时直接调用了 `DeleteDirectory(…SendToRecycleBin)`（144K 文件约 30 秒）。**现在的做法**：先把源目录改名为 `.old`，建 junction 验证通过后，再用模板 7（`t07-safe-recycle.ps1 -Path … -Apply`）移入回收站——模板 7 会先检查回收站容量，不够就拒绝，避免超限时被静默永久删除。`mklink /J` 创建 junction 即时生效。

#### 第六步：清理 + 释放空间

- `.bad` 目录：当时用 robocopy 空目录 `/MIR` 镜像法清空（🔴 CRITICAL：永久删除，不走回收站；现在优先用模板 7，只有超过回收站上限且用户明确确认后才这样做）
- 回收站：用户确认后再清空

**最终结果：C 盘从 137.43 GB → 142.54 GB，释放 5.11 GB。**

### 这个案例的关键启示

1. **robocopy 一定加 `/XJ`**——它默认跟随 junction，这是文件数和体积暴增的主因
2. **只用 robocopy 一个工具**——支持长路径、默认保留稀疏状态；复制后对大文件用 `fsutil sparse queryflag` 核对
3. **验证步骤不可省**——不验证就删源目录，可能把整个迁移废掉

---

## Case B: VS Code 用户数据迁移到 D 盘（典型 IDE 场景）

### 背景

- 源目录：`%APPDATA%\Code`（设置/扩展/状态）+ `%USERPROFILE%\.vscode\extensions`（已安装扩展）
- 目标路径：`D:\DevData\VSCode`（统一目录）
- **VS Code 是 Electron 应用 + Chromium 数据布局**，架构与 TRAE 类似但不含稀疏文件——更简单

### 迁移过程

#### 第一步：完全退出 VS Code

```cmd
taskkill /F /IM Code.exe
```

确认任务管理器无残留（含 `Code.exe`、`Code - Insiders.exe` 等）。

#### 第二步：创建目标目录

```cmd
mkdir "D:\DevData\VSCode\Roaming"
mkdir "D:\DevData\VSCode\UserProfile\.vscode"
```

#### 第三步：robocopy 复制

```powershell
# 写成 .ps1 用 powershell -File 执行；退出码 >= 8 表示失败，不要继续
robocopy "$env:APPDATA\Code" "D:\DevData\VSCode\Roaming\Code" /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1
robocopy "$env:USERPROFILE\.vscode" "D:\DevData\VSCode\UserProfile\.vscode" /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1
```

扩展目录里嵌套很深的 `node_modules` 也能复制（robocopy 支持长路径）。

#### 第四步：验证文件数与大小

```powershell
$src = Get-ChildItem "$env:APPDATA\Code" -Recurse -Force -File -EA SilentlyContinue
$dst = Get-ChildItem "D:\DevData\VSCode\Roaming\Code" -Recurse -Force -File -EA SilentlyContinue
Write-Host "源: $($src.Count) 文件"
Write-Host "目标: $($dst.Count) 文件"
```

通常文件数完全一致（VS Code 数据一般不含 junction）。

#### 第五步：删源 + 建 junction

```powershell
# 先改名（junction 需要原路径不存在），验证通过、观察几天后再把 .old 用模板 7 移入回收站
Rename-Item -LiteralPath "$env:APPDATA\Code" -NewName 'Code.old'
Rename-Item -LiteralPath "$env:USERPROFILE\.vscode" -NewName '.vscode.old'

# 用 cmd（junction 命令）
cmd /c mklink /J "%APPDATA%\Code" "D:\DevData\VSCode\Roaming\Code"
cmd /c mklink /J "%USERPROFILE%\.vscode" "D:\DevData\VSCode\UserProfile\.vscode"
```

#### 第六步：验证

1. 启动 VS Code，确认扩展列表、设置、登录状态都正常
2. 新建一个临时文件并保存，确认文件监听（保存触发自动格式化等）正常
3. 关掉再开，确认状态保持
4. 都正常后：`t07-safe-recycle.ps1 -Path "$env:APPDATA\Code.old"`（演练）→ 加 `-Apply`；`.vscode.old` 同理

### VS Code 的官方替代方案：Portable Mode

VS Code 官方支持 Portable Mode——把整个 VS Code 安装目录做成便携版，所有数据存在安装目录内的 `data/` 文件夹。**比 mklink 更稳**，但需要重装 VS Code 或复制安装目录。

适用场景：
- 想用 U 盘携带 VS Code
- 想彻底隔离环境（多个工作区独立配置）
- mklink 出问题时回退方案

启用方式：在 VS Code 安装目录创建 `data` 文件夹（与 `Code.exe` 同级），重启 VS Code 即可。

---

## Case C: 任意软件通用模式（无特殊陷阱的快速迁移）

### 适用场景

- 已确认没有官方迁移方式（`drive-migration-official.md` 决策树），且软件在 mklink-migration.md 兼容性矩阵中属于"🟡 社区报告可用"
- 不是 MSIX / 商店应用，没有自更新器校验路径
- 软件数据**不含稀疏文件、不含深 junction**（普通 Electron / .NET 应用一般满足）

### 简化流程（5 步完成）

#### 第一步：完全退出软件

```cmd
taskkill /F /IM <进程名>.exe
```

#### 第二步：创建目标目录

```cmd
mkdir "D:\AppData\<Roaming|Local>\<AppFolder>"
```

#### 第三步：robocopy 复制

```powershell
robocopy "<源路径>" "D:\AppData\<Roaming|Local>\<AppFolder>" /E /XJ /COPY:DAT /DCOPY:DAT /R:1 /W:1
# 退出码 >= 8 表示失败；再按 mklink-migration.md 第四步核对文件数和大小
```

#### 第四步：源目录改名 + 建 junction

```powershell
# 先改名（不删），验证通过、观察几天后再用模板 7（t07-safe-recycle.ps1 -Path '<源路径>.old' -Apply）移入回收站
Rename-Item -LiteralPath '<源路径>' -NewName '<AppFolder>.old'

# 建 junction（用 cmd）
cmd /c mklink /J "<源路径>" "D:\AppData\<Roaming|Local>\<AppFolder>"
```

#### 第五步：验证

1. 启动应用，确认能打开
2. 新建/修改数据，确认能保存
3. 关掉再开，确认数据持久

### 时间估计

- 1 GB 数据：复制约半分钟到一分钟 + 验证约半分钟（实测量级，视磁盘而定）
- 5 GB 数据：复制约 2 分钟 + 验证约 1 分钟

### 适用范围最广的软件

- CherryStudio
- Cursor
- Kimi Desktop（确认不是 MSIX 版）
- 通义千问
- 豆包
- Postman / Insomnia
- 绝大多数 Electron 应用

---

## 三案例对比

| 维度 | Case A (TRAE) | Case B (VS Code) | Case C (通用) |
|------|---------------|------------------|---------------|
| 数据量 | 5.7 GB | 1-3 GB | < 5 GB |
| 含稀疏文件 | ✅ 是 | ❌ 否 | ❌ 否 |
| 含深 junction | ✅ 是 | ❌ 否 | ❌ 否 |
| 复制工具 | robocopy `/XJ`（当时是 xcopy + robocopy） | robocopy `/XJ` | robocopy `/XJ` |
| 官方替代 | 无（mklink 是兜底） | ✅ Portable Mode 优先 | 先查官方设置 |
| 难度 | ⭐⭐⭐ | ⭐⭐ | ⭐ |
| 预计时间 | 30-60 分钟 | 10-15 分钟 | < 5 分钟 |

**经验法则**：

1. 先在 mklink-migration.md 兼容性矩阵查目标软件
2. 任何情况都先看有没有官方配置项（`drive-migration-official.md`）
3. 没有官方方式、属"🟡 社区报告可用"、无稀疏文件：套 Case C
4. 含稀疏文件 / 大型虚拟磁盘：套 Case A 的教训（`/XJ` + 核对稀疏状态）；WSL/Docker 虚拟磁盘不走 junction
5. IDE 类工具：考虑 Case B 的 Portable Mode 替代方案

---

## 附：TRAE 专项说明

TRAE（原名 TRAE Solo，2026-06-09 改名为 TRAE Work）是字节跳动出品的 AI IDE。改名后 AppData 目录名仍为 `TRAE SOLO CN`，安装包文件名也仍叫 TRAE Solo，属于改名未完成的状态。

### 目录结构（实测数据）

`%APPDATA%\TRAE SOLO CN` 典型占用 ~10 GB（2026-07-30 实测 9,968 MB），内部结构如下：

| 子目录 | 实测大小 | 内容 | 风险档位 |
|--------|---------|------|---------|
| `VMCache` | ~6,037 MB | 沙盒虚拟机镜像文件（随版本更新持续膨胀） | 第二档（可重建，下次启动沙盒时自动重新下载） |
| `ModularData` | ~3,911 MB | AI Agent 工作区数据、沙盒配置、项目上下文 | 第三档（活跃数据，清理后 Agent 历史丢失） |
| `logs` | ~798 MB | 应用运行日志 | 第一档（纯日志，低风险） |
| `CachedData` | ~89 MB | V8 编译缓存（同 Electron CachedData） | 第一档（纯缓存，低风险） |

此外，用户目录下还有：

| 路径 | 说明 | 风险档位 |
|------|------|---------|
| `$env:USERPROFILE\.trae-cn\snapshots` | 项目快照，社区反馈可达 10-20 GB | 第三档（从 TRAE 设置里清理旧快照） |
| `$env:USERPROFILE\.trae-cn\extensions` | 插件/扩展目录 | 第三档（在 TRAE 内卸载不用的扩展） |

### 清理建议

**立即可清（第一档）：** `logs` 和 `CachedData` 合计约 900 MB，低风险。应用关闭后用模板 7（`t07-safe-recycle.ps1 -Path … [-Apply]`）移入回收站，下次启动自动重建。

**可选清理（第二档）：** `VMCache` 约 6 GB（2026-07 实测，随版本更新持续膨胀）。删除后下次使用沙盒功能时会重新下载 VM 镜像，等待时间略长但不影响功能。

**需谨慎（第三档）：** `ModularData` 约 3.9 GB，包含 AI Agent 的工作区数据和项目上下文。清理后 Agent 对话历史、工作区状态会丢失，但 TRAE 本身能正常运行。建议让用户确认后再清。

**快照膨胀：** `.trae-cn\snapshots` 是社区高频吐槽的点，可达 10-20 GB。建议用户从 TRAE 设置界面清理旧快照，或手动删除不再需要的项目快照目录。

**`.trae-cn` 目录（2026-07-30 实测 423 MB）：** 除 snapshots 外还包含 work（261 MB，项目工作区）、builtin（71 MB，内置运行时）、plugins（45 MB）、skills（19 MB）、attachments（18 MB）等。卸载 TRAE 后整个 `.trae-cn` 目录一般是残留，用户确认后用模板 7 移入回收站。

### 迁移到其他盘位（可选）

TRAE 的独立沙盒是进程级隔离（不依赖物理路径），可以通过目录 junction 将 `TRAE SOLO CN` 整体迁移到 D 盘，沙盒行为不受影响。

TRAE 是 mklink 迁移**适用但有特殊陷阱**的典型案例：robocopy 必须加 `/XJ`（不加会跟随 junction，文件数和体积暴增），复制后对 `VMCache` 的大文件用 `fsutil sparse queryflag` 核对稀疏状态。

**完整迁移流程与踩坑记录**见通用指南 `references/mklink-migration.md` 和实战案例 `references/migration-cases.md`（Case A：TRAE 案例）。
