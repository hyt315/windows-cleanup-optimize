# 内存优化参考手册（含批判性分析）

> **重要结论**：市面上绝大多数"内存清理工具"（360 内存清理、CCleaner、Mem Reduct、Razer Cortex 等）都是 **placebo（安慰剂）**。它们调用 `EmptyWorkingSet` 只是把数据从 Working Set 移到 Standby Memory——**实际占用物理 RAM 没变**。本节先科普原理，再教你**真正有效**的内存优化。

---

## 目录

- [一、Windows 内存管理原理](#一windows-内存管理原理)
- [二、"内存清理工具"的真相](#二内存清理工具的真相)
- [三、真正有效的内存优化（5 类）](#三真正有效的内存优化5-类)
- [四、识别真正的内存泄漏进程](#四识别真正的内存泄漏进程)
- [五、虚拟内存（页面文件）调优](#五虚拟内存页面文件调优)
- [六、应用层内存优化](#六应用层内存优化)
- [七、监控与诊断命令](#七监控与诊断命令)

---

## 一、Windows 内存管理原理

### 内存的 5 种状态

| 状态 | 含义 | 是否占用物理 RAM |
|------|------|------------------|
| **Free** | 完全空闲 | ❌ |
| **Zeroed** | 已清零（系统准备好直接用） | ❌ |
| **Standby** | 备用（最近用过但当前未用） | ✅ |
| **Modified** | 已修改但未写回磁盘 | ✅ |
| **Active (Working Set)** | 当前进程正在使用 | ✅ |

### 关键认知

> ⚠️ **"内存使用率高"≠"内存不够用"**

| 指标 | 含义 | 是否需要担心 |
|------|------|--------------|
| **Working Set (活动)** 高 | 进程实际使用 | 仅当 Available < 500 MB 时 |
| **Standby 高** | 系统缓存（好的！） | **不需要担心**——空闲时立即可用 |
| **Modified 高** | 等待写回磁盘 | 偶尔高是正常的 |
| **Available 低** | 真正内存压力 | ⚠️ 此时需要优化 |

**Available** = Free + Standby —— 这是判断"内存够不够用"的关键指标。

**Standby Memory 不该被清理**——它是 Windows 用来加速文件读写的缓存。下次访问同一文件时，命中 Standby 缓存 = 几乎即时返回；不命中 = 需要从磁盘读取（HDD 上可能慢 100 倍）。

---

## 二、"内存清理工具"的真相

### 工具列表与真实作用

| 工具 | 实际做了什么 | 真实效果 |
|------|--------------|----------|
| **360 内存清理** | 调用 `EmptyWorkingSet` API | ❌ Placebo |
| **CCleaner (Registry Cleaner + 内存优化)** | 同上 | ❌ Placebo |
| **Mem Reduct** | 同上 | ❌ Placebo |
| **Razer Cortex (游戏加速)** | 同上 | ❌ Placebo |
| **IObit Advanced SystemCare** | 同上 | ❌ Placebo |

### `EmptyWorkingSet` 的真相

```cpp
// 这些"清理工具"的本质
SetProcessWorkingSetSize(process, -1, -1);  // 强制压缩 Working Set
```

效果：
- 把内存页从 Working Set **移到 Standby 列表**
- **物理 RAM 占用不变**
- 工具显示"释放了 XX MB"——这个数字是"Working Set 减少了 XX"，不是"RAM 减少了 XX"

### 为什么"看起来有用"但实际无用

| 用户感受 | 真相 |
|----------|------|
| "清理后系统快了一点" | **错觉**——清理后 Standby 增加，下一次访问相同内容变快；但这不是"清理"的好处，而是**正常缓存机制** |
| "内存占用从 80% 降到 50%" | **数字游戏**——从 Working Set 转移到 Standby，物理 RAM 不变 |
| "清理后能多开几个程序" | **短期**——因为腾出 Working Set 配额，但 Standby 可以立刻复用，**长期没区别** |

### 真正有害的一面

频繁调用 `EmptyWorkingSet` 的副作用：
- **增加磁盘 I/O**——被踢出 Working Set 的页可能被写回磁盘
- **下次访问同一数据变慢**——需要重新从磁盘加载
- **SSD 寿命轻微影响**——写回磁盘触发 SSD 写入（影响极小但不是零）

---

## 三、真正有效的内存优化（5 类）

### ✅ 优化 1：减少开机自启进程

**原理**：自启进程开机后就常驻，**直接拉高基线内存占用**。

**效果**：减少 100-500 MB 基线内存（每个自启进程 50-200 MB 不等）

**方法**：调用 `startup-audit.md` 的自启项审计与禁用。

### ✅ 优化 2：识别真正的内存泄漏进程

**什么是内存泄漏**：
- 进程持续占用越来越多内存，但**不释放**
- 重启进程后内存释放
- 通常是软件 bug，不是 Windows 问题

**识别方法**：见下文"四、识别真正的内存泄漏进程"。

### ✅ 优化 3：浏览器 Memory Saver

**Chrome / Edge 内置功能**：
- 设置 → 性能 → 启用"内存节省程序"
- 不活跃的标签页会被"休眠"，释放占用的内存

**效果**：100+ 个 Chrome 标签页的用户，可释放 1-4 GB 内存（取决于标签页内容）。

### ✅ 优化 4：应用层内存配置

**JVM 应用**（IntelliJ / Eclipse / VS Code 等）：
```powershell
# IntelliJ 在 Help → Edit Custom Properties
idea.max.intellisense.filesize=10mb
# VS Code 在 settings.json
"typescript.tsserver.maxTsServerMemory": 4096
```

**数据库**（MySQL / PostgreSQL）：
- 不要无限制设置 `buffer_pool_size`
- 经验值：物理内存的 50-70%

**Docker**：
- 限制单个容器内存（`docker run -m 4g`）

### ✅ 优化 5：升级硬件（终极方案）

| 现状 | 升级建议 |
|------|----------|
| 4 GB 内存 + Win10 | 升级到 8 GB（最低） |
| 8 GB 内存 + Chrome 多标签 | 升级到 16 GB |
| 16 GB + IDE + Docker | 升级到 32 GB |
| 32 GB 还想快 | 升级到 DDR5 + 更快的 SSD |

---

## 四、识别真正的内存泄漏进程

### 诊断命令

```powershell
# 按 Working Set 排序（最直观的内存占用）
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 20 |
    Format-Table Name, Id, @{N='WorkingSet(MB)';E={[math]::Round($_.WorkingSet/1MB,1)}}, Path -AutoSize
```

### 真正的内存泄漏检测

**步骤**：
1. **基线测量**——记录每个进程的 Working Set（MB）
2. **等待一段时间**（如 30 分钟）
3. **再次测量**——比较 Working Set 增长
4. **找出"持续增长"且不释放的进程**

**自动化脚本**：
```powershell
$logFile = "$env:USERPROFILE\memory_monitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

# 记录基线
Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}}, @{N='Time';E={Get-Date -Format 'HH:mm:ss'}} |
    Export-Csv $logFile -NoTypeInformation

Write-Host "基线已记录到: $logFile"
Write-Host "请等待 30 分钟后再次运行对比脚本。"
```

**对比脚本**（第二次运行时）：
```powershell
# 读取基线 + 当前值
$baseline = Import-Csv "$env:USERPROFILE\memory_monitor_20260819_120000.csv"
$current = Get-Process | Select-Object Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}}

# 找出疑似泄漏
$leakSuspects = $baseline | ForEach-Object {
    $now = $current | Where-Object { $_.Name -eq $_.Name -and $_.Id -eq $_.Id }
    if ($now) {
        $delta = $now.WS_MB - $_.WS_MB
        if ($delta -gt 50) {
            [PSCustomObject]@{
                Name = $_.Name
                Id = $_.Id
                Baseline_MB = $_.WS_MB
                Current_MB = $now.WS_MB
                Delta_MB = $delta
            }
        }
    }
}
$leakSuspects | Sort-Object Delta_MB -Descending | Format-Table -AutoSize
```

### 常见泄漏软件

- 早期版本的 Chrome（已知 GPU 进程泄漏）
- Java 应用（常见 PermGen / Metaspace 泄漏）
- Electron 应用（某些版本）
- Adobe 系列（Reader / Acrobat）
- 老旧 Office 版本

**修复**：
- 软件升级到最新版本
- 设置定期自动重启（如 Chrome 设置退出时清缓存）
- 联系软件厂商反馈

---

## 五、虚拟内存（页面文件）调优

### 页面文件基础

- **页面文件 (pagefile.sys)** = 物理 RAM 满时溢出的"硬盘当内存用"
- 默认位置：`C:\pagefile.sys`，大小由系统管理

### 关键认知

> ❌ **"我内存够大，不需要页面文件"是错的**

**为什么？**
1. Windows 需要它生成**崩溃转储**（蓝屏时保存错误信息）
2. 某些应用**必须**有页面文件才能运行（如 SQL Server、某些游戏）
3. 浏览器 / Office 等可能在内存压力大时崩溃

### 推荐配置

**经验值**（来自 Microsoft 文档与社区共识）：

| 物理内存 | 页面文件大小（系统管理即可） | 手动设置建议 |
|----------|------------------------------|-------------|
| 4 GB | 系统管理（默认） | 4-8 GB |
| 8 GB | 系统管理（默认） | 4-8 GB |
| 16 GB | 系统管理（默认） | 1-4 GB（可小但不要 0） |
| 32 GB+ | 系统管理（默认） | 1-2 GB（最小值，给崩溃转储用） |

> ⚠️ **不要设为 0**——会导致崩溃转储失败、某些应用崩溃

### 查看当前页面文件

```powershell
Get-CimInstance Win32_PageFile | Select-Object Name, InitialSize, MaximumSize
```

### 推荐做法

1. **保持系统管理**（最稳）：系统属性 → 高级 → 性能 → 设置 → 高级 → 虚拟内存 → "系统管理的大小"
2. **手动设置**（仅当你清楚需求）：选"自定义大小"，设置初始大小和最大值相同（避免动态调整卡顿）

### 进阶：把页面文件移到 D 盘

**适合**：C 盘 SSD 容量紧张，D 盘有空间

**步骤**（系统属性 → 高级 → 性能 → 设置 → 高级 → 虚拟内存 → 更改）：
1. C 盘选"无分页文件" → 设置
2. D 盘选"自定义大小"或"系统管理的大小" → 设置
3. 重启生效

**风险**：某些应用（如某些游戏）假设页面文件在 C 盘，可能找不到。**测试后再下结论**。

---

## 六、应用层内存优化

### 浏览器（Chrome / Edge）

```
设置 → 性能 → 启用"内存节省程序"
设置 → 性能 → 限制后台进程数（建议保留 4-8 个）
```

**Memory Saver 效果**（实测）：
- 100 标签页 → 释放 1-4 GB
- 不影响后台播放的音频 / 视频

### IDE（JetBrains）

```
Help → Edit Custom Properties:
idea.max.intellisense.filesize=10mb
idea.cycle.buffer.size=1024

Help → Change Memory Settings → 调整 Maximum Heap Size
```

### VS Code

```json
// settings.json
{
    "typescript.tsserver.maxTsServerMemory": 4096,
    "extensions.supportUntrustedWorkspaces": false
}
```

### Node.js 项目

```json
// package.json
{
    "scripts": {
        "dev": "node --max-old-space-size=4096 ./node_modules/.bin/xxx"
    }
}
```

### 大模型 / AI 应用

- Ollama / LM Studio：限制模型加载内存
- TRAE / Cursor：关闭不需要的扩展

---

## 七、监控与诊断命令

### 实时内存状态

```powershell
Get-Counter '\Memory\Available MBytes'         # 可用内存
Get-Counter '\Memory\Committed Bytes'          # 提交字节（虚拟内存占用）
Get-Counter '\Memory\% Committed Bytes In Use' # 提交使用百分比
```

### 进程级监控

```powershell
Get-Process | Sort-Object WorkingSet -Descending |
    Select-Object -First 20 |
    Format-Table Name, Id, @{N='WS_MB';E={[math]::Round($_.WorkingSet/1MB,1)}}, Handles -AutoSize
```

### 推荐工具

| 工具 | 来源 | 功能 |
|------|------|------|
| **RAMMap** (Sysinternals) | Microsoft 官方 | 内存详细分布可视化（5 种状态都看得到） |
| **Process Explorer** (Sysinternals) | Microsoft 官方 | 进程树 + Working Set / Private Bytes 历史曲线 |
| **Resource Monitor** | Windows 内置 | `resmon.exe` — 实时内存/CPU/磁盘/网络 |
| **Task Manager** | Windows 内置 | 基础内存信息 + 性能曲线 |

---

## 八、内存优化检查清单

按顺序检查：

- [ ] 减少开机自启进程（见 `startup-audit.md`）
- [ ] 关闭浏览器不活跃标签页 / 启用 Memory Saver
- [ ] 检查是否有内存泄漏进程（4 节脚本）
- [ ] 确认页面文件已启用且不是 0
- [ ] 物理内存 < 8 GB → 考虑升级硬件
- [ ] 监控一段时间（1 周）确认效果

**不要做**：
- ❌ 装"内存清理工具"
- ❌ 频繁调用 `EmptyWorkingSet`
- ❌ 禁用 SysMain（详见 `services-optimization.md` SysMain 节）
- ❌ 把页面文件设为 0
- ❌ 禁用 Windows Defender（不是内存优化方法，且风险巨大）
