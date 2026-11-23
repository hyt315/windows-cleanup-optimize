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
- [七、Defender 与开发目录（Dev Drive 优先）](#七defender-与开发目录v20-重写dev-drive-优先排除列表降为--high)
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

**默认推荐**：**保持"平衡"**（见 1.1，现代 CPU 下与高性能差异极小）。
**台式机**：用户明确要求、且负载是长时间渲染/编译/游戏时，才改"高性能"/"卓越性能"（工作站）。
**笔记本**：保持平衡；插电时可在 设置 › 系统 › 电源 的"电源模式"里选"最佳性能"，不改电源计划。

> 模板 14（`t14-show-power-visual.ps1`）从 v2.1 起是**只读报告**：只显示当前电源计划和视觉效果设置，不再自动切换电源计划或加 Defender 排除。

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

### 4.1 Nagle 算法（在线游戏竞技玩家）

**风险**：🟡 MEDIUM（仅游戏竞技场景推荐）

Nagle 算法合并小数据包以节省网络带宽，但会引入数十毫秒的微小延迟。**电竞游戏玩家可精准禁用**。

> ⚠️ **官方技术纠偏**（[Microsoft Learn: TcpAckFrequency](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/description-tcp-ip-related-registry-keys)）：
> 网上流传直接写在 `Tcpip\Parameters` 根键下是**完全无效**的（系统根本不读取）。必须写入正在联网的**网卡具体接口 GUID** 下：`Tcpip\Parameters\Interfaces\{AdapterGUID}`。

**正确禁用命令（PowerShell 管理员）**：
```powershell
# 1. 动态获取当前正在联网的主网卡接口 GUID
$activeNic = Get-NetAdapter | Where-Object Status -eq 'Up' | Sort-Object LinkSpeed -Descending | Select-Object -First 1
if ($activeNic) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($activeNic.InterfaceGuid)"
    Set-ItemProperty -Path $regPath -Name "TcpAckFrequency" -Value 1 -Type DWord
    Set-ItemProperty -Path $regPath -Name "TCPNoDelay" -Value 1 -Type DWord
    Write-Host "已对活跃网卡 [$($activeNic.Name)] 禁用 Nagle 算法（TcpAckFrequency=1, TCPNoDelay=1）"
}
```

**回退恢复**：
```powershell
$activeNic = Get-NetAdapter | Where-Object Status -eq 'Up' | Sort-Object LinkSpeed -Descending | Select-Object -First 1
if ($activeNic) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($activeNic.InterfaceGuid)"
    Remove-ItemProperty -Path $regPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "TCPNoDelay" -ErrorAction SilentlyContinue
    Write-Host "已恢复默认 Nagle 算法设置"
}
```

### 4.2 现代 TCP 窗口自适应与拥塞控制（Win10 / Win11）

**风险**：🟢 LOW（系统底层标准维护）

- **TCP 窗口自适应复位**（确保千兆宽带跑满）：某些第三方网络加速器退出后会将 autotuninglevel 篡改为 disabled，导致下载速度腰斩。
  ```cmd
  netsh int tcp set global autotuninglevel=normal
  ```
- **拥塞控制提供者检查**：
  ```powershell
  Get-NetTCPSetting | Select-Object SettingName, CongestionProvider
  ```
  Windows 11 默认已升级为 `CUBIC` 算法，在高速高丢包网络中吞吐表现远胜于老旧的 NewReno。
- **网卡节能（EEE）跳 ping 避坑（游戏玩家专项）**：
  在“设备管理器 → 网络适配器 → 你的有线网卡 → 属性 → 高级”中，找到 **“节能以太网 (Energy Efficient Ethernet)”** 与 **“环保节能 (Green Ethernet)”**，将其设为 **关闭 (Disabled)**。这可以减少网卡在无密集数据流时自动降频休眠导致的突发跳 ping（效果因网卡和驱动而异，改完观察，不明显就改回）。

### 4.3 DoH（加密 DNS）

**风险**：🟢 LOW（免费安全升级）

DNS over HTTPS 加密 DNS 查询——避免 ISP / 公共 WiFi 监听与域名劫持。

**Win11**：
设置 → 网络和 Internet → WiFi / 以太网 → DNS 属性 → 选"加密的 DNS"模板（如 Cloudflare 或 阿里云公共 DNS）。

**Win10**：需改注册表或装第三方客户端。

### 4.4 代理/VPN 退出后断网、单连接二进制代理残留、多网关抢占与无线节能排查

当用户反馈**"关掉 VPN/代理后浏览器打不开（重新打开代理软件但不连接反而恢复）"、"进入系统设置网络/拨号主页一直转圈"或"点击网页首包很慢"**时，模板 23（`t23-audit-browser-hijack.ps1`）会自动核查以下常见根因：

1. **残留本地死代理与 `Connections` 单连接二进制标志位未复位**：
   - 不少代理或 RAS 拨号加速插件不仅修改 `HKCU\...\Internet Settings\ProxyEnable`，还会调用 `wininet.dll!InternetSetOptionW`（`INTERNET_OPTION_PER_CONNECTION_OPTION = 75`）同时写入 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections` 下的 `DefaultConnectionSettings`、`SavedLegacySettings` 以及具体 PPPoE/VPN 拨号项。
   - 当客户端异常退出或直接关机前未完成清理时，即便 `ProxyEnable` 已被改回 `0`，上述二进制值的第 8 字节（`dwFlags`）仍可能停留在 `0x02`/`0x03`（代理开启）或包含无效 PAC URL、`0x08`（WPAD 自动检测）及编码损坏的乱码连接名，导致浏览器与 PPPoE 拨号链路在次日开机后仍持续走死代理端口直至重新唤起客户端主程序。
   - 修复思路：清理时需先备份 `Connections` 键，同步将 `ProxyEnable=0`、移除 `AutoConfigURL`，并按单连接通过 `InternetSetOptionW(75)`（`PROXY_TYPE_DIRECT = 1` + 递增版本号）复位所有拨号及默认连接项，再调用 `InternetSetOption(39/37)` 与 `DnsFlushResolverCache()`；若配置退出守护脚本，建议一并监听 `SessionEnding` / `WM_QUERYENDSESSION` 事件以防止未关代理直接关机导致次日断网。
2. **虚拟网卡路由抢占、桥接光猫假网关与 TCP 静态排除端口残留（🟡 MEDIUM）**：
   - **虚拟网卡抢占**：VMware NAT（`VMnet8`）或遗留 `TAP-Windows` / `QMTAP` 虚拟网卡如果配有默认网关（`0.0.0.0/0`）或低 `InterfaceMetric`，关闭代理后默认路由会被黑洞网关接管；多余物理网卡若绑定了不使用的桥接协议（如 `vmware_bridge`）也会拖慢建连探测。正确处理：清除虚拟网卡默认网关并设高跃点数（如 `Set-NetIPInterface -InterfaceMetric 500`），禁用闲置虚拟网卡或其桥接绑定，卸载不再使用的 `QMTAP`/`TAP-Windows` 幽灵设备（`pnputil /remove-device`）。
   - **多物理网卡假网关（桥接光猫拨号常见）**：当主联网走 Wi-Fi，而有线网卡接入桥接光猫（需通过 PPPoE 宽带拨号联网）或无外网内网交换机时，有线网卡可能通过 DHCP 自动拿到不可路由外网的默认网关与 DNS（如 `192.168.1.1` 且跃点数较低），导致 Windows 11 设置主页（拨号联网模块）及部分应用优先向假网关发包、超时转圈 15–30 秒。处理前记录原 IP/DHCP 配置以便回退，确认不需要该网关时可移除其默认网关与 DNS 或调整接口跃点数，并保持 `NlaSvc` 正常工作。
   - **管理员静态 TCP 排除端口**：卸载虚拟化或分布式集群工具后，`netsh int ipv4 show excludedportrange protocol=tcp` 中可能遗留带 `*` 标记的静态排除端口段（例如 `50000-50059`），占用本机开发调试端口，核实后可用 `netsh int ipv4 delete excludedportrange` 清除。
3. **Edge `SleepingTabsTimeout` 策略过短（🟡 MEDIUM）**：若发现 `HKLM\SOFTWARE\Policies\Microsoft\Edge\SleepingTabsTimeout` 被设为极小值（如 `15` 秒），切换标签后页面迅速冻结导致点击恢复缓慢，可调整为 `900`（15 分钟）或交由默认管理（先备份策略值）。
4. **笔记本电池模式无线网卡节能过深（🟢 LOW）**：部分 OEM 电源方案在电池（DC）模式下把无线适配器"节能模式"（GUID `12bbebe6-58d6-4636-95bb-3217ef867c1a`）设为 `2`（中等节能）或 `3`（最高节能），建议改为 `1`（低节能）以降低网页首包卡顿：
   ```cmd
   powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 1
   powercfg /setactive SCHEME_CURRENT
   ```
5. **IPv6 直连泄漏评估**：仅在用户明确排查 VPN 仅接管 IPv4 且导致双栈网页泄漏时，才按用户确认评估禁用主网卡 `ms_tcpip6` 绑定（`Disable-NetAdapterBinding -ComponentID ms_tcpip6`）；常规用户保持默认。

---

## 五、文件系统优化

### 5.1 NTFS Last Access Time 戳

**风险**：🟢 LOW（Win10 1803 起默认「系统管理」）

NTFS 默认记录每个文件的"最后访问时间"——每次读取都会更新元数据，**有性能开销**。

**Win10 1803 起**：默认是「系统管理」（`NtfsDisableLastAccessUpdate` 的第 1 位），系统按卷大小决定是否更新访问时间（社区资料称系统卷 ≤128 GB 时开启，微软未给出阈值数值）。先 `fsutil behavior query disablelastaccess` 看当前状态，一般不用改。
**确实想关**：`fsutil behavior set disablelastaccess 1`（关闭访问时间更新）；改回系统管理用 `fsutil behavior set disablelastaccess 2`。依据：MS-FSA 规范与 fsutil behavior 文档（访问于 2026-11-23）。

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

## 七、Defender 与开发目录（v2.0 重写：Dev Drive 优先，排除列表降为 🟠 HIGH）

### 7.1 先用 Dev Drive，不要先加排除

- **Defender 排除 = 这个目录不再被实时扫描**。旧版本说"安全不受影响"是错的：恶意 npm/pip 包、下载到 `D:\code` 的样本都不会被拦截。
- 微软给开发者的官方方案是 **Dev Drive**（ReFS 卷，Windows 11 22621.2338 及以上，至少 50 GB；内存最低 8 GB，建议 16 GB）：Defender 的"性能模式"（异步扫描）**需要同时满足两个条件**——Dev Drive 受信任，**且 Defender 实时保护处于打开状态**。速度接近排除，但仍在扫描。
- 创建：设置 › 系统 › 存储 › 高级存储设置 › 磁盘和卷 › 创建 Dev Drive（"新建 VHD"更灵活；微软说明独立分区性能更好）。已有分区不能原地转换，格式化会清空数据。
- 查看是否受信任：`fsutil devdrv query D:`。**VHD 移动、复制到别处或重新挂载后会变成不受信任**，需要管理员执行 `fsutil devdrv trust D:` 重新信任（只信任自己创建的盘）。
- 包缓存迁过去的做法见 `drive-migration-official.md` 的 Dev Drive 一节。

依据：Microsoft Learn《Set up a Dev Drive on Windows 11》https://learn.microsoft.com/en-us/windows/dev-drive/ （访问于 2026-11-11）。

### 7.2 实在要加排除时（🟠 HIGH，逐项确认）

只排除**可再生成的构建产物和包缓存**，不排除源码根目录、下载目录、整个用户目录：

| 可以考虑 | 不要排除 |
|------|------|
| 某个项目的 `node_modules`、`target`、`build` 输出 | `D:\code` 整盘、`%USERPROFILE%`、`Downloads` |
| JetBrains / Gradle 的缓存目录 | 任何会放下载来的 exe / 脚本的目录 |

```powershell
# 管理员。每加一条都写进变更记录，回退命令是 Remove-MpPreference
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
# 回退：Remove-MpPreference -ExclusionPath "$env:LOCALAPPDATA\JetBrains"
(Get-MpPreference).ExclusionPath   # 查看当前排除列表
```

向用户说明代价：**这个目录里的文件不再被 Defender 实时拦截**。用户没说"我接受"，就不加。

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

**正确做法**：开发目录放到 Dev Drive，让 Defender 用性能模式（见第七节）；排除列表是 🟠 HIGH 的最后手段。

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

1. **电源计划保持"平衡"**（默认推荐，见 1.1/1.3）。只有台式机用户明确要求时才切换"高性能"：
   ```cmd
   :: 可选，台式机且用户要求时。回退：powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e（平衡）
   powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
   ```

2. **视觉效果**改"最佳性能"（保留字体平滑）
   GUI：系统属性 → 高级 → 性能设置 → "调整为最佳性能" → 勾字体平滑

3. **开发者**：代码和包缓存放 Dev Drive（第七节）。Defender 排除不在"快速清单"里，属 🟠 HIGH，须逐项确认。

4. **自启项清理**（HKCU Run + 计划任务）
   ```powershell
   # 见 startup-audit.md
   ```

5. **遥测服务禁用**（管理员，用 `Set-WcoServiceStartType` 先演练再 `-Apply`，见 `services-optimization.md`）
   ```powershell
   Set-WcoServiceStartType -Name DiagTrack -StartType disabled          # 加 -Apply 执行
   Set-WcoServiceStartType -Name dmwappushservice -StartType disabled   # 公司/学校管理（Intune/MDM）的电脑不要禁用
   ```

**30 分钟完成的优化**：
- 上述 + 完整自启项审计
- 视觉效果自定义（保留哪些、禁用哪些）
- Defender 排除：只在 Dev Drive 不可行时，按 7.2 逐项确认（🟠 HIGH）
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
| 空闲内存占用 | 高 | 低 | `(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory`（KB；不用英文计数器路径，中文系统会找不到） |
| 进程数 | 多 | 少 | `Get-Process \| Measure-Object` |
| 启动项数 | 多 | 少 | `Get-ScheduledTask \| Where State -ne Disabled` |
| 后台服务数 | 多 | 少 | `Get-Service \| Where Status -eq Running \| Measure` |
| 电源计划 | 平衡 | 平衡（台式机按需高性能） | `powercfg /getactivescheme` |
