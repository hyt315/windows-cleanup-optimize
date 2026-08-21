# Windows 系统性能调优

> 覆盖电源计划、视觉效果、磁盘、网络、文件系统、搜索索引等 7 大维度的优化。每项标**风险等级**（LOW / MEDIUM / HIGH / CRITICAL）和**预期收益**——只推荐**实际有效**的优化，**辟谣**常见误区。

---

## 目录

- [风险等级与收益说明](#风险等级与收益说明)
- [一、电源计划优化](#一电源计划优化)
- [二、视觉效果优化](#二视觉效果优化)
- [三、磁盘性能优化](#三磁盘性能优化)
- [四、网络性能优化](#四网络性能优化)
- [五、文件系统优化](#五文件系统优化)
- [六、搜索/索引优化](#六搜索索引优化)
- [七、Defender 排除列表（开发者的好帮手）](#七defender-排除列表开发者的好帮手)
- [常见误区辟谣](#常见误区辟谣)
- [快速操作清单](#快速操作清单)

---

## 风险等级与收益说明

| 等级 | 含义 |
|------|------|
| 🟢 **LOW** | 安全，推荐操作，几乎无副作用 |
| 🟡 **MEDIUM** | 有条件推荐，需了解取舍 |
| 🔴 **HIGH** | 有风险，可能影响安全/稳定性/功能 |
| ⛔ **CRITICAL** | 极度不推荐，可能导致严重问题 |

收益说明：**低** = 主观感知 / **中** = 实测可测量 / **高** = 明显差异（启动更快、延迟更低）

---

## 一、电源计划优化

### 1.1 四种电源计划对比

| 计划 | CPU 最小状态 | CPU 最大状态 | PCI Express 链接 | 适用 |
|------|-------------|-------------|------------------|------|
| **节能** | 5% | 50-60% | 开启 | 仅办公/网页 |
| **平衡**（默认） | 5% | 100%（动态） | 开启 | **日常通用** |
| **高性能** | 100% | 100% | 关闭 | 渲染/编译/游戏 |
| **卓越性能**（隐藏） | 100% | 100% | 关闭 + 激进调度 | 专业工作站 |

**关键差异**：
- **平衡模式** = 默认推荐。现代 CPU 的 SpeedStep/Boost 技术使其在大多数场景下与高性能模式差异极小
- **高性能** = CPU 始终保持最高频率，禁用 ASPM（PCIe 节能），增加功耗和发热
- **节能模式** = 严重限制性能，**绝对不要选**作为常规使用

### 1.2 启用"卓越性能"（隐藏）

**风险**：🟢 LOW（台式机）/ 🟡 MEDIUM（笔记本电池）

```cmd
:: 管理员 CMD
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
```

然后在"电源选项"中选择"Ultimate Performance"。

**收益**：更激进的 CPU 调度，唤醒延迟更低（适合工作站 / 服务器）。

### 1.3 查看当前电源计划

```powershell
powercfg /getactivescheme
```

**台式机推荐**：高性能（如果 CPU 不是笔记本型号）/ 卓越性能（工作站）
**笔记本推荐**：插电 → 高性能，电池 → 平衡

### 1.4 笔记本 AC/DC 独立设置

```cmd
:: 插电时最大 CPU 状态 100%
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
:: 电池时最大 CPU 状态 80%
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 80
```

---

## 二、视觉效果优化

### 2.1 入口

系统属性 → 高级 → 性能 → 设置 → 视觉效果

Windows 提供了 4 档预设 + 自定义 20 项细项。

### 2.2 推荐设置

**建议保留**（禁用会严重影响可用性）：

| 效果 | 原因 |
|------|------|
| **平滑屏幕字体边缘** (ClearType) | 禁用后文字发虚 |
| **显示缩略图而不是图标** | 实用功能 |
| **显示窗口阴影** | 极低开销 |

**可以安全禁用**（影响美观，对可用性影响小）：

| 效果 | 预期收益 |
|------|----------|
| **窗口内的动画控件和元素** | 中（减少 GPU 合成负担） |
| **任务栏动画** | 低 |
| **淡入淡出效果** | 低 |
| **鼠标指针阴影** | 低 |
| **窗口最大化/最小化动画** | 低 |

### 2.3 快速设置命令

```cmd
:: 启用最佳性能（保留字体平滑）
SOURCES:
:: GUI 方式：右键此电脑 → 属性 → 高级系统设置 → 性能 → 设置 → 选"调整为最佳性能" → 勾选"平滑屏幕字体边缘"
```

**效果**：老机器感知明显，新机器无感。

---

## 三、磁盘性能优化

### 3.1 SSD 维护（必备）

**TRIM 是 SSD 必备维护**——没有它 SSD 性能会逐渐下降。

**检查 TRIM 是否启用**：
```cmd
fsutil behavior query DisableDeleteNotify
```
返回 `DisableDeleteNotify = 0` = TRIM 已启用（默认值）

**手动触发 TRIM**（对 SSD 盘符，如 D:）：
```cmd
defrag D: /O /L
```
> Windows 10/11 默认每周自动跑优化（TRIM for SSD / Defrag for HDD），一般无需手动。

### 3.2 HDD 碎片整理

**机械硬盘**（HDD）需要定期碎片整理。
**固态硬盘**（SSD）**不需要**，反而有害（写入放大）。

**查看磁盘类型**：
```powershell
Get-PhysicalDisk | Select-Object FriendlyName, MediaType
# MediaType: 4 = SSD, 3 = HDD
```

**手动碎片整理**（仅 HDD）：
```cmd
defrag C: /O /V
```

### 3.3 磁盘写入缓存策略

**风险**：🟡 MEDIUM（台式机安全，笔记本有断电数据丢失风险）

**查看当前**：
```
设备管理器 → 磁盘驱动器 → 你的硬盘 → 属性 → 策略
```

**建议**：
- 台式机 + UPS：**启用**写入缓存（性能更佳）
- 笔记本：**保留默认**（避免突然断电丢数据）

### 3.4 SSD 索引优化（可选）

**风险**：🟢 LOW（仅对性能有轻微影响）

SSD 上 Windows Search 索引器会消耗写入寿命（理论上）。但现代 SSD 寿命足够（TBW 通常 > 300 TB），影响可忽略。

**操作**：保留默认即可，无需折腾。

---

## 四、网络性能优化

### 4.1 Nagle 算法（在线游戏玩家）

**风险**：🟡 MEDIUM（仅游戏场景）

Nagle 算法合并小数据包以节省带宽，但会增加延迟。**竞技游戏玩家禁用**。

**禁用**（需要改注册表）：
```powershell
# 对全局 TCP 连接禁用 Nagle（修改 HKEY_LOCAL_MACHINE）
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name "TCPNoDelay" -Value 1 -Type DWord
```

**回退**：
```powershell
Remove-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Force
Remove-ItemProperty -Path $regPath -Name "TCPNoDelay" -Force
```

### 4.2 DoH（加密 DNS）

**风险**：🟢 LOW（免费安全升级）

DNS over HTTPS 加密 DNS 查询——避免 ISP / 公共 WiFi 监听。

**Win11**：
设置 → 网络和 Internet → WiFi / 以太网 → DNS 属性 → 选"加密的 DNS"模板（如 Cloudflare 或 Google）

**Win10**：需改注册表或装第三方工具（如 DNS-over-HTTPS 客户端）。

### 4.3 TCP 自动调优级别

**默认已经是 normal**（系统管理）。手动调整收益小，不推荐折腾。

---

## 五、文件系统优化

### 5.1 NTFS Last Access Time 戳

**风险**：🟢 LOW（Win10 1803+ 已默认禁用）

NTFS 默认记录每个文件的"最后访问时间"——每次读取都会更新元数据，**有性能开销**。

**Win10 1803+**：系统已默认禁用，无需操作。
**早期版本**：可用 `fsutil behavior set disablelastaccess 1` 启用。

### 5.2 NTFS 8.3 短文件名

**风险**：🟢 LOW（已默认禁用）

保留短文件名（DOS 时代的 8.3 格式）有性能开销。现代系统已默认禁用，无需操作。

### 5.3 NTFS 日志大小

**风险**：🟡 MEDIUM（不建议普通用户调整）

NTFS 日志 (`$LogFile`) 默认 64 MB。增大可减少大事务的元数据写入，但占用更多空间。一般不需要动。

---

## 六、搜索/索引优化

### 6.1 Windows Search 索引范围

**默认行为**：索引用户库（文档、图片、音乐、桌面等）。

**自定义范围**：
1. `control /name Microsoft.IndexingOptions`
2. "修改" → 选择要索引的位置
3. 建议索引：用户库、开始菜单、Outlook（如果用）

**不索引**：系统盘根目录（性能差）、大项目目录（如 `D:\code` 的大型代码库）

### 6.2 重建索引

**时机**：搜索结果异常、索引损坏时

**步骤**：
1. 打开"索引选项"
2. "高级" → "重建"

**耗时**：可能 1-8 小时（取决于磁盘大小和文件数量）。

### 6.3 用第三方搜索替代

**Everything**（文件搜索）：建立 MFT 索引，搜索速度比 Windows Search 快 10-100 倍。

**适用场景**：
- 不用 Outlook 全文搜索
- 主要搜索文件名（不是文件内容）
- 需要在非索引位置快速搜索

**配合方案**：禁用 WSearch 服务（见 `services-optimization.md`），用 Everything 替代。

---

## 七、Defender 排除列表（开发者的好帮手）

### 7.1 为什么用排除列表而不是禁用 Defender

- **禁用 Defender**：安全风险极高（⛔ CRITICAL）
- **加排除列表**：Defender 不扫描指定路径 → 性能更好，**安全不受影响**

### 7.2 适合加排除的路径

| 类型 | 例子 |
|------|------|
| **IDE 缓存** | `%LOCALAPPDATA%\JetBrains\*`, `%USERPROFILE%\.cache\*` |
| **构建输出** | `D:\code\projects\**\node_modules`, `**\dist`, `**\build`, `**\.next`, `**\target` |
| **开发工具数据** | `%LOCALAPPDATA%\Trae CN\*`, `%APPDATA%\Code\*` |
| **大文件目录** | 虚拟磁盘镜像、ISO 文件目录 |

### 7.3 添加排除（PowerShell 提权）

```powershell
# 管理员
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
Add-MpPreference -ExclusionPath "$env:USERPROFILE\.cache"
Add-MpPreference -ExclusionPath "D:\code"

# 查看当前排除列表
(Get-MpPreference).ExclusionPath
```

### 7.4 排除进程（性能关键）

```powershell
# 排除 IDE 进程
Add-MpPreference -ExclusionProcess "Code.exe"
Add-MpPreference -ExclusionProcess "idea64.exe"
Add-MpPreference -ExclusionProcess "devenv.exe"
```

---

## 常见误区辟谣

### ❌ 误区 1："禁用 SysMain / Superfetch 就能加速"

**真相**：现代机器（SSD + 8 GB+）关掉反而变慢。SysMain 预加载常用应用，**加速冷启动**。

**判断**：用 `Get-PhysicalDisk` 看磁盘类型，SSD + 8 GB+ = 保留 SysMain。

详见 `memory-optimization.md` 和 `services-optimization.md` SysMain 节。

### ❌ 误区 2："关 Windows Update 提速"

**真相**：Windows Update 通常不"显著"占资源。关闭后：
- 安全风险 🔴 HIGH（无安全补丁）
- 系统可能不稳定
- **收益几乎为零**

**正确做法**：让 Update 自动更新，或设置"工作时间不更新"。

### ❌ 误区 3："关 Defender 提速"

**真相**：Defender 在 Win10/11 已经非常轻量（CPU 占用 < 2%）。关闭后：
- 安全风险 ⛔ CRITICAL（无恶意软件防护）
- 性能收益 **< 1%**

**正确做法**：用排除列表（见七、Defender 排除列表）。

### ❌ 误区 4："xx 优化大师 / xx 清理王能提速"

**真相**：绝大多数"优化大师"做的是：
- 假清理（EmptyWorkingSet 类 placebo，见 `memory-optimization.md`）
- 假修复（修改无害的注册表项）
- 真骚扰（装更多 bloatware、弹广告）

**正确做法**：用本技能（`startup-audit.md` + `services-optimization.md` + `performance-tuning.md` 组合）手动优化。

### ❌ 误区 5："内存越大越好"

**真相**：32 GB+ 内存对普通用户**几乎没有收益**。
- 大内存场景：虚拟机、视频编辑、大型 IDE + Docker
- 普通用户：8 GB 足够，16 GB 充裕

---

## 快速操作清单

**5 分钟可完成的优化**（按收益排序）：

1. **电源计划**改"高性能"（管理员）
   ```cmd
   powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
   ```

2. **视觉效果**改"最佳性能"（保留字体平滑）
   GUI：系统属性 → 高级 → 性能设置 → "调整为最佳性能" → 勾字体平滑

3. **Defender 排除**加 IDE 缓存路径（管理员 PowerShell）
   ```powershell
   Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
   ```

4. **自启项清理**（HKCU Run + 计划任务）
   ```powershell
   # 见 startup-audit.md
   ```

5. **遥测服务禁用**（管理员）
   ```cmd
   sc config DiagTrack start= disabled && sc stop DiagTrack
   sc config dmwappushservice start= disabled && sc stop dmwappushservice
   ```

**30 分钟完成的优化**：
- 上述 + 完整自启项审计
- 视觉效果自定义（保留哪些、禁用哪些）
- Defender 排除进程列表
- WSearch 用 Everything 替代

**1 小时以上深度优化**（仅当上述做完仍感慢）：
- 检查内存泄漏（见 `memory-optimization.md`）
- 升级硬件（内存 / SSD）
- 检查是否有后台 bloatware（见 `bloatware-catalog.md`）

---

## 优化前后对比

| 维度 | 优化前 | 优化后 | 验证方法 |
|------|--------|--------|----------|
| 开机时间 | 长 | 短 | 任务管理器 → 启动 |
| 空闲内存占用 | 高 | 低 | `Get-Counter '\Memory\Available MBytes'` |
| 进程数 | 多 | 少 | `Get-Process \| Measure-Object` |
| 启动项数 | 多 | 少 | `Get-ScheduledTask \| Where State -ne Disabled` |
| 后台服务数 | 多 | 少 | `Get-Service \| Where Status -eq Running \| Measure` |
| 电源计划 | 平衡 | 高性能 | `powercfg /getactivescheme` |
