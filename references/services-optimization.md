# Windows 服务优化参考手册

> 覆盖 50+ Windows 10/11 服务，每项标注**风险等级**（✅ 安全 / ⚠️ 谨慎 / ❌ 不要禁用）。按用户画像（家庭用户 / 开发者 / 游戏玩家 / 笔记本）推荐不同方案。所有禁用操作**可逆**——提供完整回退命令。

---

## 目录

- [风险等级说明](#风险等级说明)
- [一、遥测与数据收集](#一遥测与数据收集)
- [二、搜索与索引](#二搜索与索引)
- [三、Xbox / 游戏相关](#三xbox--游戏相关)
- [四、打印 / 传真](#四打印--传真)
- [五、远程访问](#五远程访问)
- [六、生物识别 / 智能卡](#六生物识别--智能卡)
- [七、蓝牙 / 其他](#七蓝牙--其他)
- [八、Microsoft 账户 / 云服务](#八microsoft-账户--云服务)
- [九、SysMain / 内存管理](#九sysmain--内存管理)
- [十、Defender / 安全](#十defender--安全)
- [十一、第三方自动更新服务](#十一第三方自动更新服务)
- [十二、其他可优化项](#十二其他可优化项)
- [用户画像推荐方案](#用户画像推荐方案)
- [通用操作流程](#通用操作流程)
- [回退方法](#回退方法)
- [绝对不要禁用的核心服务](#绝对不要禁用的核心服务)

---

## 风险等级说明

| 等级 | 含义 |
|------|------|
| ✅ **安全禁用** | 不影响系统功能、可恢复，普通用户可放心操作 |
| ⚠️ **谨慎禁用** | 特定场景才有收益（如不用 Xbox / 不用打印机），可能影响某些功能 |
| ❌ **不要禁用** | 破坏系统功能或安全，**绝对不动** |

---

## 一、遥测与数据收集

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **DiagTrack** | Connected User Experiences and Telemetry | ✅ | 微软遥测。禁用后停止向微软发使用数据，不影响系统功能 |
| **dmwappushservice** | WAP Push Message Routing Service | ✅ | 企业 MDM 相关，普通用户可禁用 |
| **diagnosticshub.standardcollector.service** | Diagnostic Execution Service | ✅ | 诊断数据收集，普通用户可禁用 |
| **diagsvc** | Diagnostic Policy Service | ⚠️ | 禁用后 Windows 疑难解答无法工作 |
| **DusmSvc** | Data Usage Monitoring Service | ✅ | 移动宽带监控，台式机可禁用 |

**通用禁用命令**（需管理员）：
```cmd
sc config DiagTrack start= disabled
sc stop DiagTrack
sc config dmwappushservice start= disabled
sc stop dmwappushservice
sc config diagnosticshub.standardcollector.service start= disabled
sc stop diagnosticshub.standardcollector.service
```

**影响**：禁用后微软不再收集你的使用数据。Windows 更新不受影响。Cortana 和"建议"功能可能减弱。

---

## 二、搜索与索引

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **WSearch** | Windows Search | ⚠️ | 索引服务。禁用后搜索变慢（毫秒级→秒级），但节省 CPU 和磁盘 I/O |

**禁用命令**（需管理员）：
```cmd
sc config WSearch start= disabled
sc stop WSearch
```

**影响**：
- 文件资源管理器搜索从即时变全盘扫描
- Outlook 搜索受影响
- 开始菜单搜索变慢
- **SSD 用户影响较小**（随机读取快），**HDD 用户影响较大**

**替代方案**：用 Everything（文件搜索）或 Listary（启动器），比 Windows Search 更轻量。

---

## 三、Xbox / 游戏相关

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **XblAuthManager** | Xbox Live Auth Manager | ✅ | Xbox 身份验证。不用 Xbox 可禁用 |
| **XblGameSave** | Xbox Live Game Save | ✅ | Xbox 云存档。不用可禁用 |
| **XboxGipSvc** | Xbox Accessory Management Service | ✅ | Xbox 配件管理 |
| **XboxNetApiSvc** | Xbox Live Networking Service | ✅ | Xbox 网络 |
| **GammingServices** | Gaming Services | ⚠️ | **游戏玩家保留**——Microsoft Store 游戏和 Xbox Game Pass 需要 |
| **BcastDVRUserService** | GameDVR and Broadcast User Service | ⚠️ | 游戏录制和直播，不用可禁用 |

**禁用命令**（非游戏玩家）：
```cmd
sc config XblAuthManager start= disabled && sc stop XblAuthManager
sc config XblGameSave start= disabled && sc stop XblGameSave
sc config XboxGipSvc start= disabled && sc stop XboxGipSvc
sc config XboxNetApiSvc start= disabled && sc stop XboxNetApiSvc
sc config BcastDVRUserService start= disabled
```

---

## 四、打印 / 传真

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **Spooler** | Print Spooler | ⚠️ | 不用打印机的用户可禁用 |
| **Fax** | Fax | ✅ | 不用传真可禁用 |

**禁用命令**：
```cmd
sc config Spooler start= disabled && sc stop Spooler
sc config Fax start= disabled && sc stop Fax
```

---

## 五、远程访问

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **RemoteRegistry** | Remote Registry | ✅ | 远程注册表访问。**强烈建议禁用**——安全风险 |
| **TermService** | Remote Desktop Services | ⚠️ | 远程桌面。不用可禁用 |
| **SessionEnv** | Remote Desktop Configuration | ⚠️ | 同上 |
| **UmRdpService** | Remote Desktop Services UserMode Port Redirector | ⚠️ | 同上 |

---

## 六、生物识别 / 智能卡

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **WbioSrvc** | Windows Biometric Service | ⚠️ | 不用 Windows Hello 可禁用 |
| **SCardSvr** | Smart Card | ⚠️ | 不用智能卡可禁用 |
| **SCPolicySvc** | Smart Card Removal Policy | ⚠️ | 同上 |
| **CertPropSvc** | Smart Card Device Enumeration Service | ⚠️ | 同上 |

---

## 七、蓝牙 / 其他

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **BTAGService** | Bluetooth Audio Gateway Service | ⚠️ | 不用蓝牙音频 |
| **BthAvctpSvc** | AVCTP service | ⚠️ | 蓝牙音频 |
| **bthserv** | Bluetooth Support Service | ⚠️ | 蓝牙支持 |
| **lfsvc** | Geolocation Service | ✅ | 定位服务，不用可禁用 |
| **MapsBroker** | Downloaded Maps Manager | ✅ | 离线地图 |
| **WerSvc** | Windows Error Reporting Service | ✅ | 错误报告 |

---

## 八、Microsoft 账户 / 云服务

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **OneSyncSvc** | Sync Host_<用户名> | ✅ | 同步主机（邮件/应用设置）。不用 Microsoft 账户可禁用 |
| **WSAPPX** | AppXSvc | ⚠️ | 应用部署服务，Microsoft Store 需要 |
| **InstallService** | Microsoft Store Install Service | ⚠️ | 同上 |
| **PcaSvc** | Program Compatibility Assistant Service | ✅ | 程序兼容性助手 |

---

## 九、SysMain / 内存管理

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **SysMain** | SysMain (Superfetch) | ⚠️ | **关键判断**——见下方说明 |

**SysMain 该不该关？这是一个有争议的话题：**

| 立场 | 理由 |
|------|------|
| **应该关** | SysMain 在某些机器（4-8 GB 内存 + 机械硬盘）会增加启动延迟、占用磁盘 I/O |
| **不应该关** | SysMain 在 SSD + 8 GB 以上内存的机器上**能显著加快应用启动**（预加载常用应用） |
| **本技能建议** | **保留**——现代机器（SSD + 8 GB+）关掉反而变慢。详见 `memory-optimization.md` 的批判性分析 |

**判断方法**：
```powershell
Get-PhysicalDisk | Select-Object FriendlyName, MediaType
# MediaType: SSD = 4 / HDD = 3
```

如果磁盘是 SSD + 内存 8 GB 以上：**保留 SysMain**。

---

## 十、Defender / 安全

> **不要尝试禁用 Defender**——属于 ❌ 等级。Defender 在 Win10/11 已经非常轻量，禁用它带来的安全风险远大于性能收益。

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **WinDefend** | Windows Defender Antivirus Service | ❌ | **绝对不动** |
| **mpssvc** | Windows Firewall | ❌ | **绝对不动** |
| **SecurityHealthService** | Windows Security Health Service | ⚠️ | 安全中心 UI，不用可禁用（不影响 Defender） |

**替代优化**：用 Defender Exclusion（排除列表）让 Defender 跳过 IDE 缓存、构建输出等——详见 `performance-tuning.md`。

---

## 十一、第三方自动更新服务

很多第三方软件会装"自动更新器"服务。这些通常**可以安全禁用**：

| 服务名模式 | 软件 | 风险 |
|-----------|------|------|
| `AdobeARMservice` | Adobe Reader / Acrobat | ✅ |
| `AdobeUpdateService` | 同上 | ✅ |
| `GoogleUpdate*` | Google Chrome / Earth | ✅ |
| `JavaUpdateSched` | Java | ✅ |
| `WPS*` | WPS Office | ✅（保留 WPS 本体不影响） |
| `QianwenUpdater*` | 千问/夸克浏览器 | ✅ |
| `NVIDIA*Update` | NVIDIA 更新器 | ⚠️（驱动更新可保留） |
| `Steam Client Service` | Steam | ❌（保留） |
| `WPS Cloud Service` | WPS 云服务 | ⚠️ |

**批量禁用**：
```powershell
$thirdPartyUpdates = @("AdobeARMservice","AdobeUpdateService","GoogleUpdate*","JavaUpdateSched","QianwenUpdater*")
foreach ($p in $thirdPartyUpdates) {
    Get-Service -EA SilentlyContinue |
        Where-Object { $_.Name -like $p } |
        ForEach-Object {
            Stop-Service -Name $_.Name -Force -EA SilentlyContinue
            sc.exe config $_.Name start= disabled
            Write-Host "[OK] 禁用: $($_.Name)"
        }
}
```

---

## 十二、其他可优化项

| 服务名 | 显示名 | 风险 | 说明 |
|--------|--------|------|------|
| **TabletInputService** | Touch Keyboard and Handwriting Panel Service | ⚠️ | 不用触屏可禁用 |
| **WFDSConMgrSvc** | Wi-Fi Direct Services | ⚠️ | 不用 Wi-Fi Direct 可禁用 |
| **WMPNetworkSvc** | Windows Media Player Network Sharing Service | ✅ | WMP 网络共享 |
| **RetailDemo** | Retail Demo Service | ✅ | 零售演示模式（一般机器上没有） |
| **wisvc** | Windows Insider Service | ✅ | 预览体验计划 |
| **WpnService** | WpnService (Windows Push Notifications) | ✅ | 推送通知 |

---

## 用户画像推荐方案

### 家庭用户

**推荐禁用**（✅）：
- DiagTrack / dmwappushservice / DusmSvc（遥测）
- Xbox 系列（XblAuthManager、XblGameSave、XboxGipSvc、XboxNetApiSvc）
- RemoteRegistry（安全风险）
- WbioSrvc / SCardSvr（不用 Windows Hello）
- Fax
- WerSvc（错误报告）
- 第三方更新服务（Adobe / Google / Java）

**谨慎考虑**（⚠️）：
- Spooler（不打印可关）
- lfsvc / MapsBroker（不用定位/地图）
- WSearch（用 Everything 替代）

**绝对不动**：
- Defender / Firewall / SysMain（保留）
- 所有核心服务（RpcSs、DcomLaunch、Power 等）

### 开发者

**推荐禁用**（✅）：
- 同家庭用户
- **OneSyncSvc**（不用 MS 账户同步）
- **WSAPPX / InstallService**（不用 Microsoft Store）
- **WpnService**（推送通知）
- **BcastDVRUserService**（游戏录制）

**保留**（开发者会用到）：
- SysMain（应用启动加速）
- WSearch（VS Code / IDE 文件搜索依赖）
- TermService（远程开发）
- All Defender 服务（用 Exclusion 优化而不是禁用）

### 游戏玩家

**保留**：
- SysMain（游戏预加载）
- GammingServices
- BcastDVRUserService（游戏录制）
- NVIDIA 更新服务（驱动更新）

**禁用**：
- 遥测服务（节省资源）
- WbioSrvc / 智能卡服务
- WerSvc

### 笔记本用户

**保留**：
- 所有电源管理相关服务
- 蓝牙服务（如用蓝牙鼠标/耳机）
- SysMain（应用预加载，节省启动时间）

**谨慎禁用**：
- WbioSrvc（指纹解锁）
- 第三方更新服务（如想手动更新）

---

## 通用操作流程

### Step 1：备份当前状态

```powershell
# 导出所有服务状态到 CSV（备份）
Get-Service | Select-Object Name, DisplayName, StartType, Status |
    Export-Csv "$env:USERPROFILE\services_backup_$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
Write-Host "已备份服务状态到: $env:USERPROFILE\services_backup_*.csv"
```

### Step 2：建系统还原点

```powershell
# 管理员权限
Checkpoint-Computer -Description "BeforeServicesOptimization" -RestorePointType "MODIFY_SETTINGS"
```

### Step 3：禁用服务（管理员）

```powershell
$servicesToDisable = @(
    "DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service",
    "DusmSvc", "XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc",
    "RemoteRegistry", "Fax", "WerSvc", "lfsvc", "MapsBroker",
    "WbioSrvc", "SCardSvr", "SCPolicySvc", "CertPropSvc"
    # 按你的画像加减
)
foreach ($svcName in $servicesToDisable) {
    $svc = Get-Service -Name $svcName -EA SilentlyContinue
    if ($svc) {
        Stop-Service -Name $svcName -Force -EA SilentlyContinue
        sc.exe config $svcName start= disabled
        Write-Host "[OK] 禁用: $svcName"
    }
}
```

### Step 4：验证

```powershell
# 检查状态
Get-Service | Where-Object { $_.StartType -eq 'Disabled' } | Select-Object Name, DisplayName
```

---

## 回退方法

### 单个服务恢复

```cmd
sc config <服务名> start= auto
sc start <服务名>
```

或者用 GUI：`services.msc` → 找到服务 → 右键 → 属性 → 启动类型改为"自动" → 启动。

### 批量恢复

从之前备份的 CSV 恢复：
```powershell
$backup = Import-Csv "$env:USERPROFILE\services_backup_20260819.csv"
foreach ($svc in $backup) {
    if ($svc.StartType -ne 'Disabled') {
        sc.exe config $svc.Name start= $svc.StartType | Out-Null
    }
}
```

### 用系统还原点回退

```powershell
# 列出可用还原点
Get-ComputerRestorePoint | Format-Table

# 恢复到指定还原点
Restore-Computer -RestorePoint <序号>
```

---

## 绝对不要禁用的核心服务

> 这些服务是 Windows 核心组件，禁用会导致**系统崩溃或重大功能丧失**。任何情况下都不要禁用。

| 服务 | 作用 |
|------|------|
| **RpcSs** | RPC（远程过程调用）——Windows 大部分操作依赖它 |
| **DcomLaunch** | DCOM 服务启动器 |
| **PlugPlay** | 即插即用设备管理 |
| **Power** | 电源管理 |
| **WinDefend** | Windows Defender |
| **mpssvc** | Windows 防火墙 |
| **Schedule** | 计划任务 |
| **UserManager** | 用户管理 |
| **ProfSvc** | 用户配置文件服务 |
| **EventLog** | 事件日志 |
| **BITS** | 后台智能传输服务（Windows Update 需要） |
| **wuauserv** | Windows Update |
| **AudioSrv** | Windows 音频 |
| **Themes** | 主题服务 |
| **lsass** | 本地安全认证子系统 |
| **winlogon** | 登录管理 |
| **SamSs** | 安全管理账户 |
| **LanmanServer** | Server 服务（文件共享） |
| **LanmanWorkstation** | Workstation 服务 |
| **Browser** | 计算机浏览器 |

**判断方法**：如果服务名/显示名含 `Rpc`、`Dcom`、`Power`、`Defend`、`mps`、`Schedule`、`BITS`、`wuauserv`、`EventLog` 等关键词——**默认保留**。
