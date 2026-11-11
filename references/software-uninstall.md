# 软件卸载与残留清理（Software Uninstall）

> Windows 卸载程序通常只删安装目录和自己的卸载注册表项，AppData 里的配置/缓存、计划任务、后台服务、驱动常常留下。本节给出"**真正卸干净**"的完整流程：先盘点 → 走软件自己的卸载程序 → 重启 → 复扫 → 残留打分 → 用户确认后经模块清理（可回退）→ 自保护软件逐级升级处理。
>
> **汇报口径**：卸载程序跑完只能说"**已启动卸载程序 / 已提交卸载**"。必须重启并复扫（`Get-WcoInstalledProgram` + `Find-WcoLeftover`）确认条目和残留都不在了，才能说"已卸载"。没有复扫，不说"已彻底删除"。

---

## 目录

- [完整卸载流程](#完整卸载流程)
- [第 0 步：盘点](#第-0-步盘点)
- [第 1 步：走官方卸载](#第-1-步走官方卸载)
- [第 2–3 步：重启并复扫](#第-23-步重启并复扫)
- [第 4 步：残留打分](#第-4-步残留打分)
- [第 5 步：确认后清理残留](#第-5-步确认后清理残留)
- [第 6 步：自保护软件逐级升级](#第-6-步自保护软件逐级升级)
- [识别卸载器套路](#识别卸载器套路)
- [弹窗定位：3 秒抓现行](#弹窗定位3-秒抓现行)
- [浏览器劫持修复](#浏览器劫持修复)
- [专项：WPS Office](#专项wps-office)
- [专项：钉钉 (DingTalk)](#专项钉钉-dingtalk)
- [专项：360 家族（最难）](#专项360-家族最难)
- [专项：百度网盘 / 迅雷 / 搜狗输入法](#专项百度网盘--迅雷--搜狗输入法)
- [第三方卸载工具](#第三方卸载工具)

---

## 完整卸载流程

```
第 0 步  盘点：T25 / Get-WcoInstalledProgram（确认是哪个程序、发行主体、卸载命令、捆绑了什么）
   ↓
第 1 步  官方卸载：设置 / 控制面板 / Invoke-WcoUninstall（MSI → msiexec /x，否则跑软件自己的卸载程序）
         / winget uninstall --interactive（一次一个）/ 商店应用 Remove-WcoAppxPackage
   ↓
第 2 步  重启（驱动和被占用的文件通常要重启后才真正移除）
   ↓
第 3 步  复扫：Get-WcoInstalledProgram + T25，确认卸载条目已消失
   ↓
第 4 步  残留打分：Find-WcoLeftover（只读，给出置信度）
   ↓
第 5 步  用户逐项确认后清理：计划任务 → 服务 → 驱动（手动高危）→ 注册表键 → 文件夹进回收站
   ↓
第 6 步  卸不掉的自保护软件：关自我保护再官方卸载 → 安全模式 → 最后手段
   ↓
复扫并汇报（之前/之后对比）
```

每一步都可停：标准卸载后复扫已经干净，后面就不用做。所有写操作先演练（不带 `-Apply`），用户确认后再带 `-Apply`；结束 `Export-WcoUndo` 生成回退脚本。

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1
```

---

## 第 0 步：盘点

```powershell
.\scripts\templates\t25-inventory-programs.ps1          # 已安装程序 + 商店应用，对照 data/bloatware-catalog.json
Get-WcoInstalledProgram -Name '*2345*' | Format-List      # 单个软件的详情：发行主体、版本、安装位置、卸载命令、MSI 产品码、签名者
```

- 看清楚 DisplayName（`Invoke-WcoUninstall` 要用**完整准确**的名字）、Publisher、InstallLocation、UninstallString、是否 MSI（有 ProductCode）。
- 一个家族常有多个条目（主程序 + 插件 + 更新组件），列给用户，逐个决定。
- `SystemComponent=1` 或没有 UninstallString 的条目在控制面板里看不到，T25 会单独列出。
- 卸载前记下盘点结果，最后用来做之前/之后对比。

---

## 第 1 步：走官方卸载

**界面方式**（首选，用户能看到每个对话框）：
- Win11：设置 › 应用 › 已安装的应用 → 目标右侧"…" → 卸载
- Win10：设置 › 应用 › 应用和功能 → 目标 → 卸载
- 控制面板：`Win+R` → `appwiz.cpl`

**模块方式**（跑的仍是软件自己的卸载程序，有界面）：

```powershell
Invoke-WcoUninstall -Name '2345看图王'            # 演练：打印将要执行的命令
Invoke-WcoUninstall -Name '2345看图王' -Apply     # 执行：MSI 用 msiexec.exe /x {产品码}（有界面，不加 /qn）；否则运行 UninstallString
Invoke-WcoUninstall -ProductCode '{GUID}' -Apply  # 按 MSI 产品码
```

- 返回"已启动卸载程序"。卸载界面里的每个勾选项（"保留配置""修复""顺便安装 XX"）**读给用户听，由用户选**。
- 不默认使用 `QuietUninstallString` 或静默参数：静默卸载时用户看不到捆绑勾选和挽留选项。
- 卸载记录写入 `changes.json`（类型 uninstall）；卸载不可自动撤销，`undo.ps1` 里只有说明。

**winget**（Windows 11 自带；Windows 10 1809+ 需要"应用安装程序"）：

```powershell
winget list --name "2345"                          # 先看匹配到哪些（按子串匹配，不支持通配符）
winget uninstall --id <列表里的 ID> --interactive  # 一次一个；--interactive 让卸载界面出来
```

- **一次只卸一个**，卸完确认再下一个；**不要用 `--silent` 批量卸**捆绑软件。
- `winget list` 里 Source 为空的条目（不是 winget 装的）同样能卸，ID 以列表为准。

**商店 / 预装应用（Appx）**：

```powershell
Remove-WcoAppxPackage -Name '*CandyCrush*'                          # 演练：列出将删除的包
Remove-WcoAppxPackage -Name '*CandyCrush*' -Apply                   # 当前用户
Remove-WcoAppxPackage -Name '*CandyCrush*' -AllUsers -Provisioned -Apply   # 所有用户 + 新用户也不再预装（需管理员）
```

- 只删预配包（Provisioned）不会从**已有**账户里删掉该应用，所以两者都要处理（[Remove-AppxProvisionedPackage](https://learn.microsoft.com/powershell/module/dism/remove-appxprovisionedpackage)）。
- 模块拒绝删除：框架包、不可移除包、系统包，以及 Store、App Installer、WebView2、VCLibs、UI.Xaml、Windows 安全中心、开始菜单/Shell 组件。回退只能从商店或 winget 重新安装。
- **不要卸载 WebView2 运行时**：很多桌面应用（Office、各种 Electron/WebView 外壳）依赖它，`msedgewebview2.exe` 进程是正常的。

---

## 第 2–3 步：重启并复扫

```powershell
# 让用户保存工作后自己重启（不要替用户直接重启）。重启后：
Get-WcoInstalledProgram -Name '*2345*'                  # 卸载条目应已消失
.\scripts\templates\t25-inventory-programs.ps1          # 与第 0 步对比
```

- 条目还在：卸载程序没跑完、被取消、或需要重启后继续。重新运行一次，或进入第 6 步。
- 条目没了但进程/服务还在跑：多半是捆绑组件或独立服务，继续第 4 步。

---

## 第 4 步：残留打分

```powershell
Find-WcoLeftover -Name '2345看图王' -Publisher '<盘点到的 Publisher>' -InstallLocation '<盘点到的 InstallLocation>'
```

只读。它检查 Program Files / Program Files (x86)、ProgramData、`%APPDATA%`、`%LOCALAPPDATA%`、`HKCU/HKLM\SOFTWARE\<发行主体或产品名>`、安装目录下的服务和计划任务，给每个候选打分（思路参考 BCUninstaller 的置信度规则，代码为本仓库自写）：

| 置信度 | 含义 | 默认 |
|-------|------|------|
| **VeryGood / Good** | 名字精确匹配、在该软件独立目录里、由卸载记录指向 | 用户要求时才预选 |
| **Questionable** | 只部分匹配、目录里还有可执行文件 | 逐个人工核对 |
| **Bad** | 目录仍被其他已安装程序使用、厂商公共目录 | 不处理 |

规则要点：
- **4 个字符以内的名字不做模糊匹配**（防"QQ""WPS"这类短名误伤）。
- **厂商公共目录/键不整体删除**：`Tencent`（QQ、微信、电脑管家共用）、`Kingsoft`（WPS 和毒霸共用）、`Baidu`（输入法、网盘共用）、`Common Files`、`Microsoft`。只处理具体产品的子目录/子键。
- 跳过 junction / 符号链接（可能指向别的盘上的真实数据）。
- 聊天记录、文档、存档等用户数据单独问用户，默认保留。

---

## 第 5 步：确认后清理残留

把第 4 步结果按类型列给用户，用户逐项确认后按下面顺序处理（全部先演练、再 `-Apply`）：

**① 计划任务**（先禁用观察，确认无用再删；删除前会导出 XML，可重新注册）：

```powershell
Disable-WcoScheduledTask -TaskPath '\' -TaskName '2345PicUpdate'            # 可回退
Remove-WcoScheduledTask  -TaskPath '\' -TaskName '2345PicUpdate' -Apply     # 卸载残留确认后；拒绝 \Microsoft\ 下的任务
```

**② 服务**（必须先停止并设为禁用，才允许删除；删除前导出服务注册表键）：

```powershell
Set-WcoServiceStartType -Name '<服务名>' -StartType disabled -Apply
Stop-Service -Name '<服务名>'
Remove-WcoService -Name '<服务名>'           # 演练
Remove-WcoService -Name '<服务名>' -Apply    # 回退 = reg import 后重启
```

- 按**确切服务名**处理，不要用 `360*`、`*2345*` 这类通配符批量删（会碰到显示名碰巧相似的其他服务）。模块拒绝微软签名服务和"绝对不能禁用"列表里的服务。
- **先跑官方卸载程序再删服务**：反过来做，官方卸载程序可能因为找不到服务而失败，留下更难处理的半卸载状态。

**③ 驱动**（🔴 CRITICAL，没有自动删除函数，手动处理）：
- `Get-Service` 看不到驱动。查看：`Get-CimInstance Win32_SystemDriver | Where-Object PathName -match '<产品关键字>'`；过滤驱动用管理员 `fltmc filters`；驱动包用 `pnputil /enum-drivers`（只列驱动库里的第三方驱动包，不是完整的内核驱动清单）。
- 只在**官方卸载 + 重启之后**仍有残留、且驱动包的提供者（Provider）确实是已卸载产品时才处理：

```cmd
:: 先建还原点（管理员 PowerShell：Checkpoint-Computer -Description "BeforeDriverDelete"）
pnputil /export-driver oem42.inf "%TEMP%\wco\driver_backup"
pnputil /delete-driver oem42.inf /uninstall
```

- **永远不要手删 `.sys` 文件或 `C:\Windows\System32\DriverStore\FileRepository` 里的目录**；只用 `pnputil /delete-driver`（[pnputil 语法](https://learn.microsoft.com/windows-hardware/drivers/devtest/pnputil-command-syntax)）。非 PnP 的过滤驱动用 pnputil 删不掉，交给第 6 步（安全模式 / 安全软件）。

**④ 注册表键**（删除前 `reg export`，回退 `reg import`）：

```powershell
Remove-WcoRegistryKey -Path 'HKCU:\Software\2345Pic'          # 演练
Remove-WcoRegistryKey -Path 'HKCU:\Software\2345Pic' -Apply   # 执行
```

- 模块拒绝根键和共享键：`HKLM:\SOFTWARE`、`\SOFTWARE\Microsoft*`、`\SOFTWARE\Classes` 根、`\SOFTWARE\Policies` 根、`\SOFTWARE\WOW6432Node` 根、`Services` 根、厂商共用根键（如 `\SOFTWARE\Kingsoft`，只能删具体产品的子键）。
- 不做"注册表清理"（扫描孤立项一类的工具）：微软不支持注册表清理工具，收益几乎为零。

**⑤ 文件夹**（进回收站，可还原）：

```powershell
.\scripts\templates\t07-safe-recycle.ps1 -Path "$env:APPDATA\2345Pic","$env:LOCALAPPDATA\2345Pic" -Label '2345看图王残留'          # 演练
.\scripts\templates\t07-safe-recycle.ps1 -Path "$env:APPDATA\2345Pic","$env:LOCALAPPDATA\2345Pic" -Label '2345看图王残留' -Apply   # 执行
```

- 回收站不可用（U 盘/网络盘、设为直接删除、体积超过上限、策略未知）时模块拒绝执行，不会退化为永久删除。
- Program Files 下的目录需要管理员。

**最后复扫**：再跑一次 `Get-WcoInstalledProgram` + `Find-WcoLeftover` + T25，给用户之前/之后对比，然后才说"已卸载"。

---

## 第 6 步：自保护软件逐级升级

适用于 360、部分安全软件、钉钉保镖等带自我保护的软件。按顺序，前一级成功就停：

1. **关软件自己的自我保护**（在软件设置里），再走第 1 步官方卸载。不要先 `Stop-Process -Force` 硬杀进程——自保护软件会拦截或重启进程，而且会打断它自己的卸载流程。
2. **重启后复扫**。内核驱动通常在重启后才真正卸掉；**重启前不要去删驱动文件**。
3. **仍有残留**：先建还原点（`Checkpoint-Computer -Description "BeforeCleanup"`，需管理员；系统默认 24 小时内只建一个），开 BitLocker 的电脑先确认恢复密钥已备份（`manage-bde -status C:`）。然后进安全模式：设置 › 系统 › 恢复 › 高级启动 › 立即重新启动 → 疑难解答 › 高级选项 › 启动设置 → 重启后按 4。Windows 10/11 默认**按 F8 进不了安全模式**。在安全模式里重跑官方卸载程序，或按第 5 步清理残留。
4. **最后手段（🔴 CRITICAL，默认不推荐）**：厂商自己的专用清除工具优先；第三方强卸脚本（如 GitHub 上针对 360 的强卸脚本）只有前面都失败、用户明确要求时才提，必须先让用户（或你逐行）读完脚本内容、建好还原点。**不要从网上直接 `irm | iex` 运行任何脚本。**

**⚠️ 风险**：删错内核驱动可能导致无法开机或断网（有激活工具类驱动把访问重定向到 `tcpip.sys` 的案例，强删会删掉网络驱动）。任何删除驱动的动作都要先有还原点。

---

## 识别卸载器套路

捆绑软件的卸载程序常见这些设计，遇到时停下来读给用户：

- 默认选中"**修复**""**保留**""**我再想想**"，真正的"卸载"按钮小而灰。
- 多轮挽留弹窗（"卸载后将失去 XX 保护"）。
- 卸载过程中带勾选的"顺便安装/设为首页"。
- 卸载完成后打开广告网页，或卸载 A 后又装了 B（第 3 步复扫能发现）。
- `UninstallString` 指向网页链接、或指向一个名字像"修复工具"的程序：先 `Get-WcoInstalledProgram` 看清楚，再决定是否用 `msiexec /x` 或 winget。

---

## 弹窗定位：3 秒抓现行

屏幕突然弹出广告、不知道是哪个程序时，用模板 `scripts/templates/t20-locate-popup-window.ps1`，或下面的最小版本（`GetForegroundWindow` 取前台窗口所属进程）：

```powershell
if (-not ('WindowHelper' -as [type])) {
Add-Type @"
    using System; using System.Runtime.InteropServices;
    public class WindowHelper {
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    }
"@
}
Write-Host "请在 3 秒内点击那个广告弹窗..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
$hwnd = [WindowHelper]::GetForegroundWindow()
$pidRef = 0; [void][WindowHelper]::GetWindowThreadProcessId($hwnd, [ref]$pidRef)
if ($pidRef -ne 0) {
    $proc = Get-Process -Id $pidRef -ErrorAction SilentlyContinue
    "进程: $($proc.Name)  PID: $($proc.Id)  路径: $($proc.Path)"
    if ($proc.Path) { (Get-AuthenticodeSignature -LiteralPath $proc.Path).SignerCertificate.Subject }
}
```

> 系统通知气泡和不抢焦点的弹窗不会成为前台窗口；抓不到时让用户在弹窗出现时点一下它再运行，或看 设置 › 系统 › 通知 里是哪个应用在发通知。

---

## 浏览器劫持修复

**先用浏览器自己的设置**：
- **Chrome**：设置 › 搜索引擎 → 改回；设置 › 启动时 → 删可疑页面；扩展程序 → 删可疑扩展；必要时 设置 › 重置设置。
- **Edge**：设置 › 开始、主页和新建标签页；隐私、搜索和服务 › 地址栏和搜索；必要时 设置 › 重置设置。
- **Firefox**：`about:preferences` 主页、`about:preferences#search`。

**设置变灰、显示"由你的组织管理"** → 被写了策略：

1. `t23-audit-browser-hijack.ps1` 列出 HKLM 和 HKCU 下的 Chrome / Edge / Firefox 策略；或在浏览器打开 `chrome://policy`、`edge://policy`。
2. 公司/学校的电脑，策略可能是单位下发的，不要动，联系 IT。
3. 个人电脑：只删被劫持写入的那几个值（`HomepageLocation`、`RestoreOnStartup`、`RestoreOnStartupURLs`、`NewTabPageLocation`、`DefaultSearchProvider*`、可疑的 `ExtensionInstallForcelist` 项），**不要删整个 `...\Policies\Google\Chrome` 或 `...\Microsoft\Edge` 键**——里面可能有用户自己或其他软件的正常策略。删除单个值（先备份、记账、可回退）：

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1
$key = 'HKLM\SOFTWARE\Policies\Google\Chrome'; $name = 'HomepageLocation'      # 以 T23 列出的为准
$s = Get-WcoSession; $bak = Join-Path $s.Dir "reg\browser_policy_$name.reg"
reg.exe export $key $bak /y
Remove-ItemProperty -LiteralPath "Registry::$key" -Name $name                    # HKLM 需管理员
[void](Add-WcoChange -Kind registry -Target "$key\$name" -Before '(见备份)' -After '(已删除)' -Undo "reg.exe import `"$bak`"" -Risk MEDIUM)
Export-WcoUndo
```

4. 删了又回来：有程序或驱动在后台写，回到 T24/T25 找来源；驱动级劫持交给安全软件（见 `bloatware-catalog.md` 8b）。

---

## 专项：WPS Office

### 卸载

1. 第 0 步盘点：WPS 常有多个条目（WPS Office、WPS 加载项、Kingsoft 组件），且常装在非标准位置（`<自定义安装根>\WPS Office\<版本号>\office6\`、`D:\Program Files\Kingsoft\`）——用 `Get-WcoInstalledProgram -Name '*WPS*'` 找真实路径，不要硬编码。
2. 让用户先退出 WPS（任务栏和托盘都关掉）。仍有进程时按**确切进程名**结束，不要用宽泛正则：
   ```powershell
   Get-Process -Name wps, wpp, et, wpscloudsvr, ksolaunch -ErrorAction SilentlyContinue | Select-Object Name, Id, Path
   # 确认都是 WPS 的路径后：
   Get-Process -Name wps, wpp, et, wpscloudsvr, ksolaunch -ErrorAction SilentlyContinue | Stop-Process
   ```
3. 第 1–3 步：官方卸载 → 重启 → 复扫。
4. 第 4–5 步：`Find-WcoLeftover -Name 'WPS Office' -Publisher '<盘点到的发行主体>'`。常见残留：`%APPDATA%\kingsoft\office6`（配置）、`%APPDATA%\WPS Cloud Files`（云文档缓存，**先问用户里面有没有没同步的文档**）、`%LOCALAPPDATA%\Kingsoft`、`C:\ProgramData\Kingsoft`、任务 `WpsUpdateTask_<用户>` / `WpsUpdateLogonTask_<用户>` / `WpsWakeWnsLogonTask`。
5. 注册表：只删 WPS 产品子键（如 `HKCU:\Software\Kingsoft\Office`），**不删 `HKCU\Software\Kingsoft` 根键**——同一台机器若还有金山其他软件会被一起删掉，模块也会拒绝。

**保留 WPS 只清垃圾**：删 `addons\pool\win-i386\` 下多版本插件中的旧版本（保留最新）、`%LOCALAPPDATA%\Kingsoft\WPS Office\Temp\`，全部走 `t07-safe-recycle.ps1`；在 WPS 设置里关推送与广告。

### 治本：自动升级任务反复复活的三层修复

**症状**：禁用 `WpsUpdateTask_<用户名>` 和 `WpsUpdateLogonTask_<用户名>` 后，下次打开 WPS 又被 `ksolaunch.exe /wpsupdate` 重新写回。

**根因**：WPS 启动器 `ksolaunch.exe` 每次 WPS 运行时检查并重新注册更新任务；`wpscloudsvr` 服务也会注册 `WpsWakeWnsLogonTask`。

**三层防护**（缺一不可，单独任何一层都会被绕过）：

| 层 | 操作 | 权限 |
|---|---|---|
| ① 配置层（治本） | `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo` 下 `UpdateMode` 从 `auto` 改为 `manual`，同时把 `LastUpdateMode` 也改成 `manual`（否则 WPS 启动时可能用 LastUpdateMode 把 UpdateMode 改回去） | 当前用户 |
| ② 任务层（兜底） | 禁用 `WpsUpdateTask_<user>`、`WpsUpdateLogonTask_<user>`、`WpsWakeWnsLogonTask` | 根目录任务需管理员 |
| ③ 服务层（兜底） | `wpscloudsvr` 设为禁用 | 管理员 |

```powershell
Import-Module .\scripts\lib\Wco.Common.psm1
$k = 'HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo'
# ① 配置层（普通权限）——Set-WcoRegistryValue 会先 reg export 整个 updateinfo 键
Set-WcoRegistryValue -Key $k -Name UpdateMode              -Value 'manual' -Type String
Set-WcoRegistryValue -Key $k -Name LastUpdateMode          -Value 'manual' -Type String
Set-WcoRegistryValue -Key $k -Name UpdateNewPageAutoShown  -Value 'false'  -Type String

# ② ③（管理员 PowerShell 里跑）
Get-ScheduledTask | Where-Object { $_.TaskName -like 'Wps*' } | Select-Object TaskPath, TaskName, State   # 先确认实际路径
Disable-WcoScheduledTask -TaskPath '\' -TaskName "WpsUpdateTask_$env:USERNAME"
Disable-WcoScheduledTask -TaskPath '\' -TaskName "WpsUpdateLogonTask_$env:USERNAME"
Disable-WcoScheduledTask -TaskPath '\' -TaskName 'WpsWakeWnsLogonTask'
Set-WcoServiceStartType -Name wpscloudsvr -StartType disabled
# 以上都是演练；用户确认后每行加 -Apply 再跑，然后 Export-WcoUndo
```

**回退**：运行会话目录里的 `undo.ps1`（注册表从备份导入、任务重新启用、服务恢复原启动类型）。

> 用户找不到 WPS 界面里的"自动升级"开关（有些版本藏得深或没有）时，改 UpdateMode 是最快的治本路径——界面开关和这个注册表值是同一配置。注意：管理员会话里的 `HKCU` 若是另一个管理员账户启动的，会写到那个账户下；配置层请在用户自己的普通 PowerShell 里跑。

---

## 专项：钉钉 (DingTalk)

钉钉会安装"钉钉保镖"（`AlibabaProtect` 服务），有自我保护，标准卸载后可能残留。

1. 退出钉钉，按第 1 步官方卸载钉钉；"阿里巴巴 PC 安全服务"如有独立卸载条目，也走它自己的卸载程序。
2. 重启 → 复扫。
3. 服务仍在：
   ```powershell
   Get-CimInstance Win32_Service -Filter "Name='AlibabaProtect'" | Select-Object Name, State, StartMode, PathName
   Set-WcoServiceStartType -Name AlibabaProtect -StartType disabled -Apply
   Stop-Service -Name AlibabaProtect
   Remove-WcoService -Name AlibabaProtect            # 演练；确认后 -Apply
   ```
   停不下来（自我保护拒绝）→ 第 6 步（安全模式里处理）。
4. 目录 `C:\Program Files (x86)\DingTalk`、`C:\Program Files (x86)\AlibabaProtect` 及卸载键残留：`Find-WcoLeftover -Name '钉钉'` 打分后，用 `t07-safe-recycle.ps1` 和 `Remove-WcoRegistryKey` 处理（管理员）。

---

## 专项：360 家族（最难）

360 自我保护最强，**直接删文件、删服务基本无效且有风险**。按第 6 步的顺序：

1. **先关 360 的自我保护**：360 安全卫士 → 设置 → 安全防护中心里关闭"自我保护"（各版本位置不同，以界面为准）。不关的话卸载程序常常卡住。
2. **走官方卸载**：设置 › 应用 › 已安装的应用 → 360 安全卫士 / 360 杀毒 → 卸载；或 `winget list --name "360"` 看匹配到哪些，再 `winget uninstall --id <ID> --interactive` 一个一个卸。卸载中出现"保留隔离区/保留配置"之类的选项，问用户。
3. **重启**，再做下面的残留检测。内核驱动通常重启后才真正卸掉，**重启前不要动驱动文件**。
4. **还有残留**：建还原点 → 安全模式（设置 › 恢复 › 高级启动，F8 默认无效）→ 在安全模式里重跑卸载或按第 5 步清理。
5. **第三方强卸脚本**：🔴 CRITICAL，最后手段，规则见第 6 步第 4 条。

**360 残留检测（只读）**：

```powershell
Get-CimInstance Win32_Service      | Where-Object { $_.PathName -match '\\360' } | Select-Object Name, State, PathName
Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match '^360' -or $_.PathName -match '\\360' } | Select-Object Name, State, PathName
pnputil /enum-drivers | Select-String -Context 0,6 '360'      # 驱动库里的驱动包
Get-ScheduledTask | Where-Object { $_.TaskName -like '*360*' } | Select-Object TaskPath, TaskName, State
Find-WcoLeftover -Name '360安全卫士'
```

按 `PathName` 判断归属，比按服务显示名匹配可靠（显示名以"360"开头的不一定是 360 公司的软件）。

---

## 专项：百度网盘 / 迅雷 / 搜狗输入法

**百度网盘**：退出界面后，`YunDetectService` 服务和右键扩展仍常驻。
- 还要用网盘：只把服务设为禁用（`Set-WcoServiceStartType -Name YunDetectService -StartType disabled`，可回退），在网盘设置里关开机启动。
- 不用了：官方卸载 → 重启 → 复扫；服务仍在再按第 5 步 ② 删除；`%APPDATA%\Baidu\BaiduNetdisk` 走 `t07-safe-recycle.ps1`（先问用户里面有没有下载到一半的文件）。注意 `%APPDATA%\Baidu` 可能还装着百度输入法的数据，不整目录删。

**迅雷**：`XLServicePlatform`、`ThunderNetwork` 服务在退出客户端后仍可能运行（P2P 上传）。
- 还要用：两个服务设为禁用或手动（`Set-WcoServiceStartType`），迅雷设置里关开机启动和"下载完成后继续上传"类选项。
- 不用了：官方卸载 → 重启 → 复扫 → 残留服务按第 5 步 ②，`%LOCALAPPDATA%\Thunder Network`、`%APPDATA%\Thunder Network` 走回收站。

**搜狗输入法**：输入法以 IME 形式加载进各个程序，打字时会拉起 `SogouCloud.exe`、`SGDownload.exe`、`PinyinUp.exe`。
1. 搜狗设置里关闭"云计算候选"和资讯/热点推送。
2. 禁用其更新任务（先列出，再逐个 `Disable-WcoScheduledTask -TaskPath <路径> -TaskName <名称>`）。
3. 仍弹窗时可给 `SGDownload.exe` 加出站防火墙规则。`netsh` 的 `program=` 需要**确切路径**（通配符是否支持未核实，很可能不生效），先找真实路径：
   ```powershell
   Get-ChildItem "${env:ProgramFiles(x86)}\SogouInput" -Recurse -Filter SGDownload.exe -EA SilentlyContinue | Select-Object -ExpandProperty FullName
   ```
   ```cmd
   netsh advfirewall firewall add rule name="Block_SGDownload" dir=out action=block program="<上面查到的完整路径>"
   :: 回退：netsh advfirewall firewall delete rule name="Block_SGDownload"
   ```
   输入法升级后版本目录会变，规则需要重建。

---

## 第三方卸载工具

标准流程搞不定、或用户想要图形界面时再用：

| 工具 | 许可 | 特点 | 注意 |
|------|------|------|------|
| **BCUninstaller（Bulk Crap Uninstaller）** | 开源，Apache-2.0（[GitHub](https://github.com/BCUninstaller/Bulk-Crap-Uninstaller)） | 残留扫描带置信度（Very Good / Good / Questionable / Bad）；本仓库 `Find-WcoLeftover` 的打分思路参考自它 | 不要用它的"静默卸载"处理捆绑软件（看不到捆绑勾选）；只默认选 Good 以上的残留，Questionable 人工核对；据调研，回收站不可用时它会改为永久删除——先确认回收站可用 |
| **Geek Uninstaller** | 免费（个人），闭源 | 单文件便携；卸载后扫注册表和文件残留 | "强制删除"会跳过官方卸载程序直接删，只在官方卸载失败时用 |
| **Revo Uninstaller Free** | 免费版，闭源 | Hunter 模式（拖瞄准镜到窗口定位程序） | 同上 |
| **HiBit Uninstaller** | 免费，**非开源**（未见公开源码，存疑） | 单文件便携 | 自带"修复注册表"类功能，不要用 |

> 第三方工具的残留扫描结果也要逐项看，不要"全选删除"：厂商公共目录、仍被其他软件使用的目录会被误判。本仓库不再推荐 IObit Uninstaller（该厂商产品常被批评捆绑推广，和本技能"去捆绑"的目标冲突）。

---

## 相关文档

- 识别清单与广告载体 → `bloatware-catalog.md`
- 只关自启、不卸载 → `startup-audit.md`
- 服务启动类型与"绝对不能禁用"列表 → `services-optimization.md`
- 踩坑 → `pitfalls.md`"卸载与流氓软件"一节
