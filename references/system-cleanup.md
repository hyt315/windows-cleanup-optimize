# 系统级安全清理

除了用户目录下的缓存和残留，Windows 系统层面也有几个安全的清理手段。这些操作不涉及用户文件，但部分需要管理员权限。

## 目录

- Windows 磁盘清理工具（cleanmgr）
- 存储感知（Storage Sense）自动清理
- DISM 组件存储清理
- 休眠文件（hiberfil.sys）
- 页面文件（pagefile.sys）迁移
- 驱动存储库残留清理（DriverStore / pnputil）
- Delivery Optimization 缓存清理
- 注册表残留检测（可选，需谨慎）
- 微软官方清理入口（优先推荐用户自助）

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
| 运行存储感知 | 磁盘空间不足时 或 每周 | 磁盘较小的机器可设每周 |
| 回收站文件保留 | 30 天 | 回收站不是长期备份，30 天足够反悔期 |
| 下载文件夹清理 | **默认"从不"，谨慎开启** | 开启后会自动删"超过 N 天未打开"的下载文件——安装包、合同、资料可能被误删且**不进回收站**（微软文档明确：下载文件夹删除不走回收站）。除非用户确认下载文件夹只放临时物，否则保持"从不"，只让它清临时文件和回收站 |
| 临时文件 | 开启 | 正在使用的文件不会被处理，安全 |
| 本地可用的云内容（OneDrive） | 默认 30 天未打开转在线 | 只释放本地占位，不删云端文件，安全 |

要点：
- 存储感知**只作用于系统盘（C 盘）**，其他盘需在"高级存储设置 → 其他驱动器上使用的存储"单独处理
- 默认关闭，首次可在低磁盘空间时手动触发"立即释放空间"
- 它是自动化的"第一道防线"，本技能的手动扫描是"第二道防线"——两者配合而非替代

## DISM 组件存储清理

WinSxS 目录是 Windows 组件存储，会随系统更新不断膨胀。直接删文件极其危险，只能用 DISM 命令安全清理：

```powershell
# 需要先检查健康状态（可选，耗时较长）
Dism /Online /Cleanup-Image /ScanHealth

# 清理被取代的组件（安全，推荐）
Dism /Online /Cleanup-Image /StartComponentCleanup

# 在上述基础上进一步清理旧版本备份（激进：之后无法卸载已安装的更新）
Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
```

第一条 `ScanHealth` 只是扫描不修改，可以放心跑。第二条 `StartComponentCleanup` 是安全操作，只删已被新版取代的旧组件。第三条带 `/ResetBase` 的比较激进——执行后无法回滚已安装的 Windows 更新，建议只在空间极度紧张时使用。

## 休眠文件（hiberfil.sys）

如果用户不使用休眠功能（大多数台式机/外接电源笔记本用户不用），可以关闭休眠来释放空间：

```cmd
:: 需要管理员权限的 CMD
powercfg -h off
```

休眠文件大小通常等于物理内存的 40%-75%（例如 16 GB 内存的机器上约 6-12 GB）。关闭后文件立即删除，空间立即释放。如果将来想恢复休眠，执行 `powercfg -h on` 即可。

**注意：** 关闭休眠同时会禁用"快速启动"（Fast Startup），开机速度会略慢。对 SSD 用户影响不大。

## 页面文件（pagefile.sys）迁移

如果用户有 D 盘等其他磁盘，可以把页面文件从 C 盘迁到 D 盘：

1. 右键"此电脑" → 属性 → 高级系统设置 → 性能"设置" → 高级 → 虚拟内存"更改"
2. 取消 C 盘的页面文件（选"无分页文件"→ 设置）
3. 在 D 盘设置页面文件（选"系统管理的大小"→ 设置）
4. 重启生效

页面文件大小通常为物理内存的 1-1.5 倍。迁移后 C 盘可释放数 GB，但 D 盘必须有足够空间。不建议完全关闭页面文件——某些程序（如大型游戏、Adobe 系列）在内存不足时依赖页面文件，关闭可能导致崩溃。

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
pnputil -d oemXX.inf                                      # 删除旧版本驱动包
```

规则：同一驱动（同名 INF）保留**最新版本**，删其余旧版。实战案例删除约 40 个旧驱动释放约 8 GB（多数为 NVIDIA）。第三方图形化工具 DevManView 亦可，但 pnputil 最稳。删除后接入新设备需重新联网装驱动（属预期行为）。

## Delivery Optimization 缓存清理

Windows 更新、商店、Edge、Defender 的下载经由 Delivery Optimization（P2P），缓存目录：

- `C:\Windows\SoftwareDistribution\DeliveryOptimization`
- 或 `C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache`

清理方式（按优先级）：
1. 设置 → Windows 更新 → 高级选项 → 传递优化（可清空或限制带宽/缓存盘）
2. `cleanmgr` 勾选相关项
3. 手动清空缓存目录（删了下次更新重新下载，无风险；建议先停 `DoSvc` 服务避免占用，`Stop-Service DoSvc`）

可选的更优方案：组策略/注册表把缓存目录改到非系统盘（`DoCachePath`），一劳永逸。

## 注册表残留检测（可选，需谨慎）

卸载软件后 `HKCU\Software`、`HKLM\SOFTWARE`、`HKEY_USERS\.DEFAULT\Software` 可能残留孤儿键。**只读检测 + 用户确认 + 备份后删除**，切勿批量删：

```powershell
# 只读列出：与已安装应用列表交叉比对（匹配词构建方法见主文件 1.4）
Get-ChildItem 'HKCU:\Software' -ErrorAction SilentlyContinue | ForEach-Object {
    # 对每个键判断是否与 installedLower 匹配，无匹配输出为"疑似残留"
}
# 删除前必须：reg export 备份该键；删除用 Remove-Item -Recurse 删除键
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
