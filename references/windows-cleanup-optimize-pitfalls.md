# windows-cleanup-optimize 核心避坑库与官方规范基线

<!-- skill-doctor: allow-block SEC002 -->

> 本指南聚合 GitHub 顶级开源磁盘清理工程实践、微软官方架构内部白皮书（DISM/VSS/CompactOS）与【冷门长尾探索池】中的真实生产级故障，为 Windows 深度清理与磁盘优化提供防破坏与避坑准则。

---

## 目录

- 一、 微软官方规范与系统级清理基线 (Microsoft Official Baselines)
- 二、 【冷门长尾探索池】极端特异性杀手坑 (Fringe Edge Cases)
- 三、 GitHub 顶级开源项目与同类 Agent 技能对标经验 (Peer Skills & Top OSS)
- 四、 自动化安全核验探针 (Safety Probes)

---

## 一、 微软官方规范与系统级清理基线

### 1. WinSxS 组件存储库与 Hard Link 错觉
- **官方原理**：`C:\Windows\System32` 中的大量文件并非独立实体，而是通过 NTFS 硬链接（Hard Link）指向 `C:\Windows\WinSxS` 中的物理文件。普通扫描工具（如简单的目录求和）会重复计算硬链接大小，产生 WinSxS 虚胖假象（看起来占用 20GB+，实际独占空间仅 6~8GB）。
- **官方清理规范**：
  - 第一步（分析可回收空间）：`Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore`；
  - 第二步（标准安全回收）：`Dism.exe /Online /Cleanup-Image /StartComponentCleanup`。
- **🚨 致命风险禁区（`/ResetBase`）**：
  - 严禁默认执行 `Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase`！
  - **根因**：`/ResetBase` 会物理删除组件存储中所有被取代的旧版本补丁，执行后**当前所有已安装的累积更新（LCU）将永久无法卸载和回滚**。若未来微软补丁出现兼容性 Bug，用户将无法通过卸载补丁自救。必须仅在用户明确了解该不可逆后果时手动授权执行。

### 2. Windows 交付优化缓存 (Delivery Optimization)
- **官方规范**：Windows 10/11 从网络或对等节点下载更新时，会在 `C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache` 缓存分块文件。
- **推荐做法**：调用系统原生支持的 PowerShell 命令 `Delete-DeliveryOptimizationCache` 或使用系统磁盘清理 API，严禁手动直接 `rmdir` 导致 BITS 传递队列异常。

### 3. CompactOS 原生系统文件压缩
- **官方原理**：微软自 Windows 10 引入的基于 WOF（Windows Overlay Filter）与 XPRESS4K/LZX 算法的系统核心文件无损压缩技术。
- **查询状态**：`compact.exe /compactos:query`；
- **安全启用**：`compact.exe /compactos:always`，可在不影响系统性能与冷启动速度的前提下，稳定释放 2.0GB ~ 4.5GB C 盘空间。

### 4. 休眠文件 `hiberfil.sys` 与快速启动的取舍平衡
- **常识误区**：许多脚本直接执行 `powercfg -h off`，虽然释放了与物理内存大小相当的 `hiberfil.sys`，但会**静默关闭 Windows 快速启动（Fast Startup）**，导致机械硬盘或旧电脑开机变慢 3~5 倍，且在现代待机（Modern Standby / S0ix）笔记本上可能引起异常耗电。
- **最佳实践**：
  - 若需保留快速启动但节省空间，执行：`powercfg /h /type reduced`（体积缩减 50% 并保留快速启动）；
  - 仅在用户确认不使用休眠且要求极致空间释放时，才执行 `powercfg -h off`。

### 5. 虚拟内存页面文件 (`pagefile.sys`) 底线
- **崩溃转储基线**：即便物理内存（RAM）高达 32GB/64GB，也**严禁将页面文件完全设为 0**。
- **根因**：完全禁用页面文件会导致 Windows 在遭遇内核故障时无法生成内存转储（Minidump / Memory.dmp），且部分老旧软件与 Direct3D 大作在 Commit Charge 达到 100% 时会直接崩溃闪退（报 0x0000003B / 0x0000001A MEMORY_MANAGEMENT）。页面文件安全下限为 1024MB。

---

## 二、 【冷门长尾探索池】极端特异性杀手坑

### 1. OneDrive / iCloud "文件随选 (Files On-Demand)" 水合雪崩陷阱
- **病症**：许多递归扫描、哈希校验或清理脚本在扫描 `%USERPROFILE%` 时，越扫 C 盘反而越满，网络流量暴增数百兆。
- **底层机理**：
  - 云存储的“文件随选”采用 NTFS 重解析点（Reparse Points）与稀疏文件机制，本地仅保存几个字节的占位符元数据；
  - 传统脚本遍历读取文件头、获取哈希或读取内容时，Windows 文件系统微筛选驱动（Filter Driver）会将其判定为“用户正在读取该文件”，从而触发云端自动将整份文件实时下载（Hydration 水合）到本地 SSD，导致空间直接被占满！
- **防御对策**：
  - 在 PowerShell 遍历中，必须检查并跳过包含以下属性的文件：
    ```powershell
    $isCloudPlaceholder = ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or
                          ($file.Attributes -band [System.IO.FileAttributes]::SparseFile)
    if ($isCloudPlaceholder) { continue } # 跳过，严禁读取内容
    ```

### 2. `C:\Windows\Installer` (.msi / .msp) 误删灾难
- **病症**：扫描发现 `C:\Windows\Installer` 占用数 GB 乃至数十 GB，用户或激进清理工具手动全选删除。
- **后果**：直接导致已安装的 Microsoft Office、Visual Studio、SQL Server、AutoCAD 等大型软件**永久无法更新、打补丁、修复或卸载**，再次点击卸载将报错 `The installation source for this product is not available`（微软官方明确声明手动删除该目录文件不受支持）。
- **防御对策**：
  - 将 `C:\Windows\Installer` 列入全局只读白名单，严禁直接 `Remove-Item`；
  - 仅支持通过官方卸载程序卸载废弃软件，或借助经过验证的孤儿补丁分析工具（如 PatchCleaner）进行只读探测。

### 3. VSS 卷影副本 (Volume Shadow Copy) 静默清除隐患
- **病症**：使用 `vssadmin delete shadows /all` 一键清空卷影存储以释放几十 GB 空间。
- **后果**：所有系统还原点（System Restore Points）以及文件“以前的版本”（Previous Versions）瞬间物理蒸发。若后续系统更新异常或遭受恶意软件篡改，机器将彻底失去本地秒级回滚防线。
- **防御对策**：
  - 不得将清空卷影副本设为默认执行项；
  - 提供只读查询：`vssadmin list shadowstorage`，仅在空间极度告急且告知用户“所有历史还原点将失效”后由用户显式触发。

### 4. SoftwareDistribution 目录与 Windows Update 服务锁死
- **病症**：直接对 `C:\Windows\SoftwareDistribution` 执行强制递归删除，报“文件被占用拒绝访问”或导致 Windows Update 服务出现 0x80248007 错误码。
- **防御对策**：
  - 仅可清理下载缓存子目录 `C:\Windows\SoftwareDistribution\Download`；
  - 若需重置更新缓存，必须按规范停用服务并按序重启：
    `net stop wuauserv` ➔ `net stop cryptsvc` ➔ 重命名或清理 ➔ `net start cryptsvc` ➔ `net start wuauserv`。

---

## 三、 GitHub 顶级开源项目与同类 Agent 技能对标经验

| 维度 | 行业标杆工具 / 项目 | 沉淀的工程设计范式 |
|---|---|---|
| **MFT 秒级遍历** | **WizTree / Everything** | 对于超大容量磁盘，放弃极慢的逐层 `Get-ChildItem -Recurse`，建议在需要全盘热力图时提示用户使用 MFT 级轻量工具辅助验证。 |
| **五档安全隔离架构** | **BleachBit / Czkawka** | 将清理目标划分严格的安全等级：<br>1. **第一档（无感无损缓存）**：系统与浏览器临时文件、缩略图缓存；<br>2. **第二档（已卸载残留）**：注册表空键、废弃 Roaming 文件夹；<br>3. **第三档（开发环境与构建产物）**：`node_modules`、`.gradle`、`target/`；<br>4. **第四档（应用大文件搬家）**：微信/QQ 存储目录 mklink 重定向；<br>5. **第五档（系统核心禁区）**：`WinSxS`、`Installer`、驱动库，只读排查，绝不强删。 |
| **就近内联动作范式** | **Agent Skills 行业标准** | 消除主工作流中的“可参考/详见”，所有参考手册在步骤下方以 `👉 动作：读取 [文件]` 直达，彻底杜绝 AI 跳步。 |

---

## 四、 自动化安全核验探针 (Safety Probes)

所有诊断脚本与清理建议在落地前，必须通过以下静态与运行时探针断言：

1. **重解析点探针（防云端脱水文件被拉下）**：
   ```powershell
   # 验证代码是否具备重解析点拦截
   if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
       Write-Verbose "Skipping ReparsePoint: $($item.FullName)"
   }
   ```
2. **只读预检探针（Zero-Mutation 断言）**：
   - 探测命令中绝不包含 `-Force` 删除语句；
   - 估算大小必须输出为结构化 JSON 或 Markdown 事实卡供用户审核。
