# 迁移实战案例集

> 三个代表性案例覆盖不同复杂度：
> - **Case A**：TRAE AppData（含稀疏文件陷阱，最复杂）
> - **Case B**：VS Code 用户数据（最常见的 IDE 场景）
> - **Case C**：任意软件通用模式（无特殊陷阱的快速迁移）

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
| 目标体积膨胀 2-3 倍 | robocopy 展开稀疏文件 | 对含稀疏文件的子目录改用 xcopy 或 Copy-Item |
| xcopy 跳过部分文件 | 路径超 260 字符限制 | 对该子目录用 robocopy（支持长路径） |
| 坏副本删不掉 | Remove-Item 逐文件删除太慢 | 先 Rename-Item 改名（瞬间完成），最后集中清理 |
| 大目录清理慢 | robocopy `/MIR` 输出几十 MB 日志 | 加 `/NFL /NDL /NJH /NJS /NC /NS` 静默模式 |

### 迁移过程

#### 第一步：尝试 robocopy 全量复制 — 失败

使用 `robocopy /E /R:1 /W:1 /MT:8`，结果：

- 源 VMCache：64,079 文件 / 1,313 MB
- 目标 VMCache：209,949 文件 / 3,786 MB

**两个问题同时发生**：

1. **稀疏文件膨胀**：VMCache 里的虚拟磁盘镜像是 sparse file（逻辑大小远小于分配大小），robocopy 默认将稀疏文件展开到完整大小，导致目标体积膨胀约 2.5 倍。
2. **junction 跟踪导致文件重复**：robocopy 默认跟随源目录内的 junction point，把 junction 指向的目标内容也复制了一份，导致文件数暴增约 3 倍。

总计目标变成 289,881 文件 / 8,232 MB（源只有 5,759 MB）。

#### 第二步：清理坏副本 — 卡住 → Rename-Item 抢救

`Remove-Item -Recurse -Force` 对 289K 文件的目录极慢，部分文件被锁无法删除。

**解决**：Rename-Item 改名比 Remove-Item 快得多（瞬间完成）。把坏副本改名为 `.bad`，留到最后清理。

#### 第三步：xcopy 复制主体 — 部分成功

`xcopy /E /I /H /Y /Q` 复制了 80,343 / 144,011 文件。缺的 63,668 个文件全在 VMCache 里——沙盒虚拟磁盘内的 `node_modules` 路径深度嵌套，超过了 Windows 260 字符路径长度限制，xcopy 对这些文件报"系统找不到路径"并跳过。

#### 第四步：robocopy /XJ 补充 VMCache — 成功

`robocopy /E /XJ /R:1 /W:1`（`/XJ` 排除 junction，`/E` 包含空子目录），57 秒完成：

- 源 VMCache：64,079 文件 / 1,312.93 MB
- 目标 VMCache：64,270 文件 / 1,313.52 MB（几乎一致，微小差异正常）

**最终验证**：源 144,011 文件 / 5,758.64 MB → 目标 144,199 文件 / 5,759.19 MB（差异 188 文件 / 0.55 MB，来自 xcopy 和 robocopy 两次操作的叠加，不影响功能）。

#### 第五步：SendToRecycleBin + mklink /J — 成功

`SendToRecycleBin` 的 `DeleteDirectory` API 成功处理了 144K 文件的大目录（耗时约 30 秒）。`mklink /J` 创建 junction 即时生效。

#### 第六步：清理 + 释放空间

- `.bad` 目录：robocopy 空目录 `/MIR` 镜像法快速清空（注意：这会永久删除文件，不走回收站）
- 回收站：`Clear-RecycleBin -Force` 清空

**最终结果：C 盘从 137.43 GB → 142.54 GB，释放 5.11 GB。**

### 这个案例的关键启示

1. **含稀疏文件的目录不能整体 robocopy**——必须单独处理（xcopy 或 Copy-Item）
2. **xcopy 和 robocopy 是互补关系**——没有万能工具，只有混合策略
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

#### 第三步：xcopy 复制（VS Code 无稀疏文件，xcopy 一次到位）

```cmd
xcopy /E /I /H /Y /Q "%APPDATA%\Code" "D:\DevData\VSCode\Roaming\Code"
xcopy /E /I /H /Y /Q "%USERPROFILE%\.vscode" "D:\DevData\VSCode\UserProfile\.vscode"
```

VS Code 的扩展目录可能很深（嵌套的 `node_modules`），xcopy 260 字符限制可能触发——若提示"系统找不到路径"，对 `extensions` 子目录单独跑一次 robocopy `/E /XJ /R:1 /W:1`。

#### 第四步：验证文件数与大小

```powershell
$src = Get-ChildItem "$env:APPDATA\Code" -Recurse -Force -File -EA SilentlyContinue
$dst = Get-ChildItem "D:\DevData\VSCode\Roaming\Code" -Recurse -Force -File -EA SilentlyContinue
Write-Host "源: $($src.Count) 文件"
Write-Host "目标: $($dst.Count) 文件"
```

通常文件数完全一致（VS Code 数据不含 junction，xcopy 不会膨胀）。

#### 第五步：删源 + 建 junction

```powershell
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory("$env:APPDATA\Code", 'OnlyErrorDialogs', 'SendToRecycleBin')
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory("$env:USERPROFILE\.vscode", 'OnlyErrorDialogs', 'SendToRecycleBin')

# 用 cmd（junction 命令）
cmd /c mklink /J "%APPDATA%\Code" "D:\DevData\VSCode\Roaming\Code"
cmd /c mklink /J "%USERPROFILE%\.vscode" "D:\DevData\VSCode\UserProfile\.vscode"
```

#### 第六步：验证

1. 启动 VS Code，确认扩展列表、设置、登录状态都正常
2. 新建一个临时文件并保存，确认文件监听（保存触发自动格式化等）正常
3. 关掉再开，确认状态保持

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

- 软件在 mklink-migration.md 兼容性矩阵中标注为"✅ 完全兼容"
- 软件数据**不含稀疏文件、不含深 junction**（普通 Electron / .NET 应用都满足）
- 数据量 < 5 GB（避免 xcopy 长路径问题）

### 简化流程（5 步完成）

#### 第一步：完全退出软件

```cmd
taskkill /F /IM <进程名>.exe
```

#### 第二步：创建目标目录

```cmd
mkdir "D:\AppData\<Roaming|Local>\<AppFolder>"
```

#### 第三步：xcopy 复制

```cmd
xcopy /E /I /H /Y /Q "<源路径>" "D:\AppData\<Roaming|Local>\<AppFolder>"
```

如果报错"系统找不到路径"（260 字符限制），对相应子目录用 robocopy `/E /XJ /R:1 /W:1` 补充。

#### 第四步：删源 + 建 junction

```powershell
# 用 PowerShell 删源目录（走回收站）
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('<源路径>', 'OnlyErrorDialogs', 'SendToRecycleBin')

# 建 junction（用 cmd）
cmd /c mklink /J "<源路径>" "D:\AppData\<Roaming|Local>\<AppFolder>"
```

#### 第五步：验证

1. 启动应用，确认能打开
2. 新建/修改数据，确认能保存
3. 关掉再开，确认数据持久

### 时间估计

- 1 GB 数据：xcopy ~30 秒 + 验证 ~30 秒 = 1 分钟
- 5 GB 数据：xcopy ~2 分钟 + 验证 ~1 分钟 = 3 分钟
- 全程操作 < 5 分钟

### 适用范围最广的软件

- CherryStudio
- Cursor
- Claude Desktop
- Kimi Desktop
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
| 复制工具组合 | xcopy + robocopy | 仅 xcopy | 仅 xcopy |
| 是否需要官方替代 | ❌（mklink 是首选） | ✅ Portable Mode | ❌ |
| 难度 | ⭐⭐⭐ | ⭐⭐ | ⭐ |
| 预计时间 | 30-60 分钟 | 10-15 分钟 | < 5 分钟 |

**经验法则**：

1. 先在 mklink-migration.md 兼容性矩阵查目标软件
2. 不在矩阵中或标"⚠️ 部分兼容"：先看有没有官方配置项
3. 完全兼容 + 无稀疏文件：直接套 Case C
4. 含稀疏文件 / 大型虚拟磁盘：套 Case A 的混合策略
5. IDE 类工具：考虑 Case B 的 Portable Mode 替代方案
