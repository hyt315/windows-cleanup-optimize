<#
.SYNOPSIS
    windows-cleanup-optimize 公共模块（v2.1）：权限检测、体积统计、回收站预检、变更留痕与一键回退、
    启动项开关、计划任务/服务/注册表键删除、已安装程序清单、卸载、商店应用移除、残留评分。
.DESCRIPTION
    所有写操作函数默认只演练（返回 Status=DryRun 与将要执行的 Plan），传 -Apply 才真正执行。
    每次真正执行都写入会话目录下的 changes.json，并可用 Export-WcoUndo 生成 undo.ps1。
    动 HKLM、服务、驱动、计划任务的写操作在非管理员会话里直接拒绝（Status=Blocked）。
    卸载只报告"已启动卸载程序"，是否卸干净以复扫（Get-WcoInstalledProgram + Find-WcoLeftover）为准。
    兼容 Windows PowerShell 5.1 与 PowerShell 7。文件以 UTF-8 BOM 保存（5.1 读中文必需）。
#>

Set-StrictMode -Version 2

$script:WcoSession = $null
$script:IsWin = ($env:OS -eq 'Windows_NT')

# 不允许停用 / 删除的服务（安全、更新、系统核心）。Set-WcoServiceStartType 不会把它们改成 disabled/demand，
# Remove-WcoService 一律拒绝。
$script:WcoProtectedServices = @(
    'WinDefend', 'WdNisSvc', 'WdFilter', 'WdBoot', 'Sense', 'SecurityHealthService', 'wscsvc', 'mpssvc', 'BFE',
    'wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'BITS', 'CryptSvc', 'TrustedInstaller', 'msiserver', 'BDESVC',
    'RpcSs', 'RpcEptMapper', 'DcomLaunch', 'LSM', 'EventLog', 'Schedule', 'Winmgmt', 'PlugPlay', 'Power',
    'ProfSvc', 'gpsvc', 'SamSs', 'KeyIso', 'VaultSvc', 'Dhcp', 'Dnscache', 'nsi', 'NlaSvc', 'netprofm',
    'BrokerInfrastructure', 'CoreMessagingRegistrar', 'StateRepository', 'AppXSvc', 'ClipSVC', 'SystemEventsBroker',
    'TimeBrokerSvc', 'UserManager', 'Audiosrv', 'AudioEndpointBuilder', 'LanmanWorkstation', 'EFS', 'sppsvc'
)

# 不允许移除的商店/系统组件包（按 Name 通配匹配）。照片、计算器等普通应用可移除，不在此列。
$script:WcoProtectedAppx = @(
    'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.DesktopAppInstaller', 'Microsoft.Winget.*',
    'Microsoft.WebView2*', 'Microsoft.Win32WebViewHost', 'Microsoft.VCLibs*', 'Microsoft.UI.Xaml*', 'Microsoft.NET.*',
    'Microsoft.WindowsAppRuntime*', 'Microsoft.SecHealthUI', 'Microsoft.Windows.SecHealthUI', '*Defender*',
    'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost', 'MicrosoftWindows.Client.*',
    'Microsoft.AAD.BrokerPlugin', 'Microsoft.AccountsControl', 'Microsoft.LockApp', 'Microsoft.Windows.CloudExperienceHost',
    'Microsoft.Windows.ContentDeliveryManager', 'windows.immersivecontrolpanel', 'Microsoft.Windows.Search',
    'Microsoft.Services.Store.Engagement', 'Microsoft.Windows.OOBENetworkConnectionFlow', 'Microsoft.BioEnrollment',
    'Microsoft.CredDialogHost', 'Microsoft.Windows.AssignedAccessLockApp', 'Microsoft.Windows.ParentalControls'
)

# StartupApproved 作用域 → 注册表键
$script:WcoStartupApprovedKeys = [ordered]@{
    'HKCU-Run'           = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    'HKLM-Run'           = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    'HKLM-Run32'         = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
    'HKCU-StartupFolder' = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
    'HKLM-StartupFolder' = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
}

# ---------------------------------------------------------------- 小工具
function Get-WcoProp {
    <# 安全读属性：对象为空或没有该属性时返回 $null（StrictMode 下直接 .Name 会抛错）。 #>
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function ConvertTo-WcoPsLiteral {
    <# 生成单引号 PowerShell 字面量，供 undo.ps1 使用。 #>
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { $Text = '' }
    return "'" + $Text.Replace("'", "''") + "'"
}

function ConvertTo-WcoNativeKey {
    <# 'HKLM:\X' / 'HKEY_LOCAL_MACHINE\X' / 'Registry::HKEY_LOCAL_MACHINE\X' → 'HKLM\X'（reg.exe 格式）。 #>
    param([Parameter(Mandatory)][string]$Path)
    $p = $Path.Trim().TrimEnd('\')
    $p = $p -replace '^(Microsoft\.PowerShell\.Core\\)?Registry::', ''
    $map = @{
        'HKEY_LOCAL_MACHINE' = 'HKLM'; 'HKEY_CURRENT_USER' = 'HKCU'; 'HKEY_CLASSES_ROOT' = 'HKCR'
        'HKEY_USERS' = 'HKU'; 'HKEY_CURRENT_CONFIG' = 'HKCC'
    }
    $m = [regex]::Match($p, '^(?<h>[A-Za-z_]+):?(\\(?<rest>.*))?$')
    if (-not $m.Success) { throw "无法识别的注册表路径：$Path" }
    $h = $m.Groups['h'].Value.ToUpper()
    if ($map.ContainsKey($h)) { $h = $map[$h] }
    if ($h -notin @('HKLM', 'HKCU', 'HKCR', 'HKU', 'HKCC')) { throw "无法识别的注册表根：$Path" }
    $rest = $m.Groups['rest'].Value
    if ($rest) { return "$h\$rest" }
    return $h
}

function ConvertTo-WcoPsKey {
    <# 'HKLM\X' → 'Registry::HKEY_LOCAL_MACHINE\X'（PowerShell 提供程序格式，可直接用于 -LiteralPath）。 #>
    param([Parameter(Mandatory)][string]$Key)
    $n = ConvertTo-WcoNativeKey $Key
    $map = @{ 'HKLM' = 'HKEY_LOCAL_MACHINE'; 'HKCU' = 'HKEY_CURRENT_USER'; 'HKCR' = 'HKEY_CLASSES_ROOT'; 'HKU' = 'HKEY_USERS'; 'HKCC' = 'HKEY_CURRENT_CONFIG' }
    $parts = $n.Split('\', 2)
    $root = 'Registry::' + $map[$parts[0]]
    if ($parts.Count -gt 1) { return "$root\$($parts[1])" }
    return $root
}

function Test-WcoNeedsAdminForKey {
    param([Parameter(Mandatory)][string]$Key)
    $n = ConvertTo-WcoNativeKey $Key
    return -not ($n -like 'HKCU*')
}

# ---- 原子读写（单独成函数，便于测试时 Mock；只在这里真正碰注册表 / reg.exe）
function Get-WcoRegValue {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Name)
    $r = [pscustomobject]@{ Exists = $false; Value = $null; Kind = $null }
    if (-not $script:IsWin) { return $r }
    $ps = ConvertTo-WcoPsKey $Key
    $k = Get-Item -LiteralPath $ps -ErrorAction SilentlyContinue
    if (-not $k) { return $r }
    if ($k.GetValueNames() -contains $Name) {
        $r.Exists = $true
        $r.Value = $k.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
        $r.Kind = [string]$k.GetValueKind($Name)
    }
    return $r
}

function Test-WcoRegKey {
    param([Parameter(Mandatory)][string]$Key)
    if (-not $script:IsWin) { return $false }
    return [bool](Test-Path -LiteralPath (ConvertTo-WcoPsKey $Key))
}

function Set-WcoRegValueRaw {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Value, [string]$Type = 'DWord')
    $ps = ConvertTo-WcoPsKey $Key
    if (-not (Test-Path -LiteralPath $ps)) { New-Item -Path $ps -Force | Out-Null }
    New-ItemProperty -LiteralPath $ps -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Export-WcoRegKey {
    <# reg export 整个键；成功返回 $true（检查 $LASTEXITCODE 与文件是否落盘）。 #>
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$File)
    $n = ConvertTo-WcoNativeKey $Key
    & reg.exe export $n $File /y 2>&1 | Out-Null
    return (($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $File))
}

function Remove-WcoRegKeyRaw {
    param([Parameter(Mandatory)][string]$Key)
    Remove-Item -LiteralPath (ConvertTo-WcoPsKey $Key) -Recurse -Force -ErrorAction Stop
}

function Test-WcoFileExist {
    param([string]$Path)
    if (-not $Path) { return $false }
    return [bool](Test-Path -LiteralPath $Path -PathType Leaf)
}

function Get-WcoFileSigner {
    <#
    读取文件的 Authenticode 签名。返回 Status（Valid/NotSigned/HashMismatch/…/Unavailable）、Subject、Organization、IsMicrosoft。
    系统文件多为编录签名（catalog），Get-AuthenticodeSignature 能识别。
    #>
    param([string]$Path)
    $r = [pscustomobject]@{ Path = $Path; Status = 'Unavailable'; Subject = $null; Organization = $null; IsMicrosoft = $false }
    if (-not $Path -or -not (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue)) { return $r }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $r.Status = 'FileNotFound'; return $r }
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        $r.Status = [string]$sig.Status
        if ($sig.SignerCertificate) {
            $r.Subject = $sig.SignerCertificate.Subject
            $o = [regex]::Match($r.Subject, '(?:^|,\s*)O="?([^",]+)')
            $cn = [regex]::Match($r.Subject, '(?:^|,\s*)CN="?([^",]+)')
            $r.Organization = if ($o.Success) { $o.Groups[1].Value.Trim() } elseif ($cn.Success) { $cn.Groups[1].Value.Trim() } else { $r.Subject }
            $r.IsMicrosoft = ($r.Status -eq 'Valid' -and $r.Subject -match 'O=Microsoft Corporation')
        }
    } catch {
        $r.Status = 'Error'
    }
    return $r
}

function Resolve-WcoExecutablePath {
    <# 从 ImagePath / DisplayIcon / 命令行里取出 exe 路径（去引号、去参数、展开环境变量、去掉 ",0"）。 #>
    param([string]$CommandLine)
    if (-not $CommandLine) { return $null }
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    $c = $c -replace '^\\\?\?\\', ''
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -gt 1) { return $c.Substring(1, $end - 1) }
        return $null
    }
    $m = [regex]::Match($c, '^(.+?\.(exe|dll|sys|com|cpl|ocx))(?=[\s,]|$)', 'IgnoreCase')
    if ($m.Success) {
        $p = $m.Groups[1].Value
        if ($p -match '^\\SystemRoot\\') { $p = $p -replace '^\\SystemRoot', $env:SystemRoot }
        if ($p -match '^(?i)system32\\') { $p = Join-Path $env:SystemRoot $p }
        return $p
    }
    return ($c -replace ',\s*-?\d+$', '')
}

function Split-WcoCommandLine {
    <# 把 UninstallString 拆成可执行文件 + 参数（不经 Invoke-Expression，防注入）。 #>
    param([Parameter(Mandatory)][string]$CommandLine)
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    $file = $null; $argText = ''
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -lt 0) { return $null }
        $file = $c.Substring(1, $end - 1)
        $argText = $c.Substring($end + 1).Trim()
    } else {
        $m = [regex]::Match($c, '^(.+?\.(exe|cmd|bat|com))(\s+|$)', 'IgnoreCase')
        if ($m.Success) {
            $file = $m.Groups[1].Value
            $argText = $c.Substring($m.Length).Trim()
        } else {
            $parts = $c.Split(' ', 2)
            $file = $parts[0]
            if ($parts.Count -gt 1) { $argText = $parts[1].Trim() }
        }
    }
    return [pscustomobject]@{ FilePath = $file; Arguments = $argText }
}

# ---------------------------------------------------------------- 权限
function Test-WcoAdmin {
    if ($env:OS -ne 'Windows_NT') { return $false }
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- 会话与留痕
function Start-WcoSession {
    param([string]$Root = (Join-Path $env:TEMP 'wco'))
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path $Root "session_$ts"
    if (Test-Path -LiteralPath $dir) { $dir = "${dir}_$([guid]::NewGuid().ToString('N').Substring(0, 6))" }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'reg') -Force | Out-Null
    $script:WcoSession = [pscustomobject]@{ Dir = $dir; Ledger = (Join-Path $dir 'changes.json'); Changes = New-Object System.Collections.ArrayList }
    return $script:WcoSession
}

function Get-WcoSession {
    if (-not $script:WcoSession) { [void](Start-WcoSession) }
    return $script:WcoSession
}

function Import-WcoSession {
    <# 进程退出后，从已有的 changes.json 恢复会话，以便重新生成 undo.ps1。 #>
    param([Parameter(Mandatory)][string]$Ledger)
    $full = (Resolve-Path -LiteralPath $Ledger -ErrorAction Stop).ProviderPath
    $items = @(Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json)
    $list = New-Object System.Collections.ArrayList
    foreach ($i in $items) { if ($null -ne $i) { [void]$list.Add($i) } }
    $script:WcoSession = [pscustomobject]@{ Dir = (Split-Path -Parent $full); Ledger = $full; Changes = $list }
    return $script:WcoSession
}

function Add-WcoChange {
    <# 记录一条已执行的变更。Undo 为可直接执行的 PowerShell 命令文本；无法自动回退时写 $null 并在 Note 里说明。 #>
    param(
        [Parameter(Mandatory)][ValidateSet('recycle', 'service', 'service-delete', 'registry', 'registry-key', 'scheduled-task',
            'scheduled-task-delete', 'startup-approved', 'uninstall', 'appx', 'ifeo', 'other')][string]$Kind,
        [Parameter(Mandatory)][string]$Target,
        [string]$Before,
        [string]$After,
        [string]$Undo,
        [ValidateSet('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')][string]$Risk = 'LOW',
        [string]$Note
    )
    $s = Get-WcoSession
    $entry = [pscustomobject]@{
        Time = (Get-Date).ToString('s'); Kind = $Kind; Target = $Target
        Before = $Before; After = $After; Undo = $Undo; Risk = $Risk; Note = $Note
    }
    [void]$s.Changes.Add($entry)
    # -InputObject + @()：只有一条记录时也写成 JSON 数组（管道写法会写成单个对象）
    ConvertTo-Json -InputObject @($s.Changes) -Depth 4 | Set-Content -LiteralPath $s.Ledger -Encoding UTF8
    return $entry
}

function Export-WcoUndo {
    <# 按与执行相反的顺序生成 undo.ps1。回收站、卸载类变更只写说明（无法脚本化精确还原）。 #>
    $s = Get-WcoSession
    $path = Join-Path $s.Dir 'undo.ps1'
    $lines = @(
        '# windows-cleanup-optimize 自动生成的回退脚本',
        "# 会话：$($s.Dir)",
        '# 请以管理员身份运行；运行前先通读一遍。',
        '$ErrorActionPreference = ''Continue''',
        ''
    )
    $arr = @($s.Changes)
    [array]::Reverse($arr)
    foreach ($c in $arr) {
        $lines += "# [$($c.Kind)] $($c.Target)  ($($c.Time))"
        if ($c.Undo) { $lines += $c.Undo } else { $lines += "# 无法自动回退：$($c.Note)" }
        if ($c.Undo -and $c.Note) { $lines += "# 说明：$($c.Note)" }
        $lines += ''
    }
    # 带 BOM，保证 Windows PowerShell 5.1 正确读取中文注释
    [IO.File]::WriteAllText($path, ($lines -join "`r`n"), (New-Object Text.UTF8Encoding($true)))
    return $path
}

# ---------------------------------------------------------------- 体积统计
function Measure-WcoDirectory {
    <#
    .SYNOPSIS
        统计目录体积。手动栈遍历，遇到 junction / 符号链接 / 云占位符等重解析点一律不进入、不计数。
    .DESCRIPTION
        Windows PowerShell 5.1 的 Get-ChildItem -Recurse 会顺着 junction 走进去（PowerShell 6.0 起才默认不跟随），
        已经 mklink 迁到 D 盘的数据会被重复算到 C 盘，所以统一用本函数。路径按字面处理（[ ] 不当通配符）。
        -Cache 传入同一个哈希表时，已量过的子目录直接取缓存，不重复遍历。
        注意：硬链接（如微信 4.x 迁移数据、WinSxS）会被重复计数，实际可释放空间可能更小。
    #>
    param([Parameter(Mandatory)][string]$Path, [hashtable]$Cache)
    $r = [pscustomobject]@{ Path = $Path; Exists = $true; Bytes = [int64]0; Files = 0; ReparseSkipped = 0; Errors = 0; LongPath = 0 }
    try { $full = [IO.Path]::GetFullPath($Path) } catch { $r.Exists = $false; $r.Errors = 1; return $r }
    if ($Cache -and $Cache.ContainsKey($full)) { $r.Bytes = [int64]$Cache[$full]; return $r }
    $rp = [IO.FileAttributes]::ReparsePoint
    $root = New-Object IO.DirectoryInfo($full)
    if (-not $root.Exists) {
        $fi = New-Object IO.FileInfo($full)
        if ($fi.Exists) {
            if ($fi.Attributes -band $rp) { $r.ReparseSkipped = 1 } else { $r.Bytes = $fi.Length; $r.Files = 1 }
        } else { $r.Exists = $false }
        return $r
    }
    if ($root.Attributes -band $rp) { $r.ReparseSkipped = 1; return $r }
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $entries = $null
        try {
            $entries = $d.GetFileSystemInfos()
        } catch [IO.PathTooLongException] {
            $r.LongPath++; continue
        } catch {
            $r.Errors++; continue
        }
        foreach ($e in $entries) {
            try {
                if ($e.Attributes -band $rp) { $r.ReparseSkipped++; continue }
                if ($e -is [IO.DirectoryInfo]) {
                    if ($Cache -and $Cache.ContainsKey($e.FullName)) { $r.Bytes += [int64]$Cache[$e.FullName]; continue }
                    $stack.Push($e)
                } else {
                    $r.Bytes += $e.Length; $r.Files++
                }
            } catch [IO.PathTooLongException] {
                $r.LongPath++
            } catch {
                $r.Errors++
            }
        }
    }
    if ($Cache) { $Cache[$full] = $r.Bytes }
    return $r
}

function Get-WcoItemSizeMB {
    param([Parameter(Mandatory)][string]$Path)
    $m = Measure-WcoDirectory -Path $Path
    return [math]::Round($m.Bytes / 1MB, 2)
}

# ---------------------------------------------------------------- 回收站预检
function Get-WcoRecycleBinPolicy {
    <#
    返回目标路径所在卷的回收站策略：是否有回收站、是否"不移入回收站直接删除"、容量上限（MB）、是否被组策略接管。
    依据：HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\{GUID} 下的 NukeOnDelete 与
    MaxCapacity（单位 MB）；组策略层 HKCU/HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer 的
    NoRecycleFiles、RecycleBinSize（优先级以策略为准；精确优先级未找到官方说明，一律按"不安全"处理）。
    读不到时 Known=$false，调用方必须按"不安全"处理。
    #>
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $result = [pscustomobject]@{ Path = $full; HasRecycleBin = $false; NukeOnDelete = $null; MaxCapacityMB = $null; Known = $false; PolicyOverride = $false; Reason = '' }
    if ($full.StartsWith('\\')) { $result.Reason = '网络路径没有回收站'; return $result }
    $root = [IO.Path]::GetPathRoot($full)
    $drive = New-Object IO.DriveInfo($root)
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { $result.Reason = "卷类型为 $($drive.DriveType)，没有回收站"; return $result }
    $result.HasRecycleBin = $true
    foreach ($pk in @('HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer')) {
        $nr = Get-WcoRegValue -Key $pk -Name 'NoRecycleFiles'
        if ($nr.Exists -and [int]$nr.Value -eq 1) { $result.NukeOnDelete = $true; $result.PolicyOverride = $true; $result.Reason = "组策略 $pk\NoRecycleFiles=1（删除不进回收站）" }
        $rs = Get-WcoRegValue -Key $pk -Name 'RecycleBinSize'
        if ($rs.Exists) { $result.PolicyOverride = $true; if (-not $result.Reason) { $result.Reason = "组策略 $pk\RecycleBinSize=$($rs.Value) 接管了回收站容量" } }
    }
    try {
        $letter = $root.TrimEnd('\')
        $vol = Get-CimInstance Win32_Volume -Filter "DriveLetter='$letter'" -ErrorAction Stop
        $guid = ([regex]::Match([string](Get-WcoProp $vol 'DeviceID'), '\{[0-9A-Fa-f-]+\}')).Value
        $key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\$guid"
        if ($guid -and (Test-WcoRegKey $key)) {
            $nk = Get-WcoRegValue -Key $key -Name 'NukeOnDelete'
            if ($null -eq $result.NukeOnDelete) { $result.NukeOnDelete = [bool]($nk.Exists -and [int]$nk.Value -eq 1) }
            $mc = Get-WcoRegValue -Key $key -Name 'MaxCapacity'
            if ($mc.Exists) { $result.MaxCapacityMB = [int64]$mc.Value }
            $result.Known = $true
        } elseif (-not $result.Reason) {
            $result.Reason = '未找到该卷的回收站策略键（可能从未在资源管理器里打开过回收站属性）'
        }
    } catch {
        $result.Reason = "读取回收站策略失败：$($_.Exception.Message)"
    }
    return $result
}

function Invoke-WcoRecycle {
    <#
    .SYNOPSIS
        把文件或目录移入回收站（模板 7 的实现）。默认只演练，-Apply 才执行。
    .DESCRIPTION
        执行前依次检查：路径存在 → 不是 junction/符号链接（是则拒绝，交给模板 6）→ 所在卷有回收站
        → 回收站未设为"直接删除"、未被组策略接管 → 回收站策略可读（读不到一律拒绝）
        → 体积不超过回收站上限（超过时 Windows 会直接永久删除）→ 目录内没有超长路径。
        任何一项不满足都返回 Status=Blocked / LongPath，不执行，由 AI 呈报给用户决定。
        执行状态：Recycled / Partial（目录只移走了一部分，已记账）/ Locked / LongPath / Error。
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Label = $Path,
        [switch]$Apply
    )
    $r = [pscustomobject]@{ Label = $Label; Path = $Path; SizeMB = 0; Status = ''; Reason = '' }
    if (-not (Test-Path -LiteralPath $Path)) { $r.Status = 'Skip'; $r.Reason = '路径不存在'; return $r }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $r.Status = 'Blocked'; $r.Reason = '是 junction/符号链接，先按模板 6 处理，避免删到链接目标'; return $r
    }
    $r.SizeMB = Get-WcoItemSizeMB -Path $Path
    $pol = Get-WcoRecycleBinPolicy -Path $Path
    if (-not $pol.HasRecycleBin) { $r.Status = 'Blocked'; $r.Reason = "$($pol.Reason)，移入回收站会变成永久删除"; return $r }
    if ($pol.NukeOnDelete) { $r.Status = 'Blocked'; $r.Reason = "该卷回收站设为`"不移入回收站，直接删除`" $($pol.Reason)".Trim(); return $r }
    if (Get-WcoProp $pol 'PolicyOverride') { $r.Status = 'Blocked'; $r.Reason = "回收站由组策略接管（$($pol.Reason)），无法确认会进回收站"; return $r }
    if (-not $pol.Known) {
        $r.Status = 'Blocked'
        $r.Reason = "回收站上限未知（$($pol.Reason)）。请先在回收站上右键 → 属性，确认该盘的回收站大小后再试"
        return $r
    }
    if ($pol.MaxCapacityMB -and $r.SizeMB -gt $pol.MaxCapacityMB) {
        $r.Status = 'Blocked'; $r.Reason = "体积 $($r.SizeMB) MB 超过回收站上限 $($pol.MaxCapacityMB) MB，Windows 会直接永久删除"; return $r
    }
    if ($item.PSIsContainer) {
        $m = Measure-WcoDirectory -Path $item.FullName
        if ($m.LongPath -gt 0) { $r.Status = 'LongPath'; $r.Reason = "目录内有 $($m.LongPath) 处超长路径（>260），回收站可能处理不了，已跳过；先缩短路径或手动处理"; return $r }
        if ($m.Errors -gt 0) { $r.Reason = "有 $($m.Errors) 个子目录读不了，体积可能偏小" }
    }
    if (-not $Apply) { $r.Status = 'DryRun'; return $r }
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        if ($item.PSIsContainer) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        $r.Status = 'Recycled'
        [void](Add-WcoChange -Kind recycle -Target $item.FullName -Before "$($r.SizeMB) MB" -After '回收站' -Note '从回收站右键"还原"即可恢复到原位置' -Risk LOW)
    } catch [IO.PathTooLongException] {
        $r.Status = 'LongPath'; $r.Reason = "路径过长，已停止（不会改用永久删除）：$($_.Exception.Message)"
    } catch [IO.IOException] {
        $r.Status = 'Locked'; $r.Reason = "文件被占用，已跳过：$($_.Exception.Message)"
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message
    }
    if ($r.Status -in @('Locked', 'LongPath', 'Error') -and $item.PSIsContainer -and (Test-Path -LiteralPath $item.FullName)) {
        $left = Get-WcoItemSizeMB -Path $item.FullName
        if ($left -lt $r.SizeMB) {
            $moved = [math]::Round($r.SizeMB - $left, 2)
            $r.Reason = "$($r.Reason)；已有约 $moved MB 移入回收站，剩余 $left MB 未动"
            $r.Status = 'Partial'
            [void](Add-WcoChange -Kind recycle -Target $item.FullName -Before "$($r.SizeMB) MB" -After "部分移入回收站（约 $moved MB）" -Note '部分文件已进回收站，可从回收站还原；其余仍在原位' -Risk LOW)
        }
    }
    return $r
}

# ---------------------------------------------------------------- 服务
function Get-WcoServiceInfo {
    param([Parameter(Mandatory)][string]$Name)
    $safe = $Name.Replace("'", "''")
    return Get-CimInstance Win32_Service -Filter "Name='$safe'" -ErrorAction SilentlyContinue
}

function ConvertTo-WcoScStart {
    param($Svc)
    $mode = [string](Get-WcoProp $Svc 'StartMode')
    switch ($mode) {
        'Auto' { if (Get-WcoProp $Svc 'DelayedAutoStart') { return 'delayed-auto' } else { return 'auto' } }
        'Manual' { return 'demand' }
        'Disabled' { return 'disabled' }
        default { return $mode.ToLower() }
    }
}

function Set-WcoServiceStartType {
    <# 修改服务启动类型前先记下原值（含"自动(延迟启动)"），回退时恢复原值而不是一律 auto。默认只演练。 #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('auto', 'delayed-auto', 'demand', 'disabled')][string]$StartType,
        [ValidateSet('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')][string]$Risk = 'MEDIUM',
        [switch]$Apply
    )
    $svc = Get-WcoServiceInfo -Name $Name
    if (-not $svc) { return [pscustomobject]@{ Name = $Name; Status = 'Skip'; Reason = '服务不存在' } }
    $before = ConvertTo-WcoScStart $svc
    if ($StartType -in @('disabled', 'demand') -and ($script:WcoProtectedServices -contains $Name)) {
        return [pscustomobject]@{ Name = $Name; Status = 'Blocked'; Before = $before; After = $StartType; Reason = '安全/更新/系统核心服务，不改启动类型' }
    }
    if ($Name -match '_[0-9a-f]{4,}$') {
        $tpl = $Name -replace '_[0-9a-f]{4,}$', ''
        return [pscustomobject]@{ Name = $Name; Status = 'Blocked'; Before = $before; After = $StartType; Reason = "这是按用户生成的服务实例，重新登录会再生成；请改模板服务 $tpl" }
    }
    if (-not $Apply) { return [pscustomobject]@{ Name = $Name; Status = 'DryRun'; Before = $before; After = $StartType; Plan = "sc.exe config $Name start= $StartType" } }
    if (-not (Test-WcoAdmin)) { return [pscustomobject]@{ Name = $Name; Status = 'Blocked'; Before = $before; After = $StartType; Reason = '改服务需要管理员权限' } }
    & sc.exe config $Name start= $StartType | Out-Null
    if ($LASTEXITCODE -eq 5) { return [pscustomobject]@{ Name = $Name; Status = 'Protected'; Before = $before; Reason = '拒绝访问：受系统保护的服务（sc.exe 返回 5）' } }
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Name = $Name; Status = 'Error'; Before = $before; Reason = "sc.exe 返回 $LASTEXITCODE" } }
    [void](Add-WcoChange -Kind service -Target $Name -Before $before -After $StartType -Undo "sc.exe config $Name start= $before" -Risk $Risk)
    return [pscustomobject]@{ Name = $Name; Status = 'Changed'; Before = $before; After = $StartType }
}

function Remove-WcoService {
    <#
    .SYNOPSIS
        删除一个第三方服务（sc.exe delete）。默认只演练，-Apply 才执行；需要管理员。
    .DESCRIPTION
        前提：服务已停止且已用 Set-WcoServiceStartType 设为 disabled（先停用观察，再删除）。
        拒绝：受保护清单内的服务、svchost 承载的共享服务、Microsoft 签名的服务、签名无法确认且位于 Windows 目录的服务。
        删除前 reg export HKLM\SYSTEM\CurrentControlSet\Services\<名称>；回退 = reg import + 重启。
        顺序提醒：先运行软件自己的卸载程序（Invoke-WcoUninstall），卸载后仍残留的服务才用本函数。
    #>
    param([Parameter(Mandatory)][string]$Name, [switch]$Apply)
    $r = [pscustomobject]@{ Name = $Name; Status = ''; ImagePath = $null; Signer = $null; Plan = "sc.exe delete $Name"; Reason = '' }
    if ($script:WcoProtectedServices -contains $Name) { $r.Status = 'Blocked'; $r.Reason = '安全/更新/系统核心服务，禁止删除'; return $r }
    $svc = Get-WcoServiceInfo -Name $Name
    if (-not $svc) { $r.Status = 'Skip'; $r.Reason = '服务不存在'; return $r }
    $r.ImagePath = [string](Get-WcoProp $svc 'PathName')
    $exe = Resolve-WcoExecutablePath $r.ImagePath
    if ($exe -and (Split-Path -Leaf $exe) -ieq 'svchost.exe') { $r.Status = 'Blocked'; $r.Reason = 'svchost 承载的共享服务属于系统组件，禁止删除'; return $r }
    $sig = Get-WcoFileSigner -Path $exe
    $r.Signer = $sig.Organization
    if ($sig.IsMicrosoft) { $r.Status = 'Blocked'; $r.Reason = 'Microsoft 签名的服务，禁止删除'; return $r }
    if ($sig.Status -ne 'Valid' -and $exe -and $env:SystemRoot -and $exe.StartsWith($env:SystemRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $r.Status = 'Blocked'; $r.Reason = '位于 Windows 目录且签名无法确认，按系统服务处理，禁止删除'; return $r
    }
    if ((Get-WcoProp $svc 'State') -ne 'Stopped' -or (Get-WcoProp $svc 'StartMode') -ne 'Disabled') {
        $r.Status = 'Blocked'
        $r.Reason = "需先停止并禁用（当前 State=$(Get-WcoProp $svc 'State')，StartMode=$(Get-WcoProp $svc 'StartMode')）：先 Set-WcoServiceStartType -StartType disabled -Apply，重启观察无异常后再删"
        return $r
    }
    if (-not $Apply) { $r.Status = 'DryRun'; return $r }
    if (-not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = '删除服务需要管理员权限'; return $r }
    $s = Get-WcoSession
    $key = "HKLM\SYSTEM\CurrentControlSet\Services\$Name"
    $bak = Join-Path $s.Dir ('reg\service_' + ($Name -replace '[^\w.-]', '_') + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.reg')
    if (-not (Export-WcoRegKey -Key $key -File $bak)) { $r.Status = 'Error'; $r.Reason = "reg export 失败，未删除：$key"; return $r }
    & sc.exe delete $Name | Out-Null
    if ($LASTEXITCODE -ne 0) { $r.Status = 'Error'; $r.Reason = "sc.exe delete 返回 $LASTEXITCODE"; return $r }
    [void](Add-WcoChange -Kind service-delete -Target $Name -Before "ImagePath=$($r.ImagePath)" -After 'deleted' -Undo "reg.exe import `"$bak`"" -Risk HIGH -Note '导入后需重启服务才会重新出现')
    $r.Status = 'Deleted'
    return $r
}

# ---------------------------------------------------------------- 注册表
function Set-WcoRegistryValue {
    <# 改注册表值前先 reg export 整个键做备份，回退命令为 reg import。默认只演练。 #>
    param(
        [Parameter(Mandatory)][string]$Key,          # 形如 HKCU\Software\Xxx
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('String', 'DWord', 'QWord', 'ExpandString', 'MultiString', 'Binary')][string]$Type = 'DWord',
        [ValidateSet('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')][string]$Risk = 'MEDIUM',
        [ValidateSet('registry', 'ifeo')][string]$Kind = 'registry',
        [switch]$Apply
    )
    $nk = ConvertTo-WcoNativeKey $Key
    $psKey = ConvertTo-WcoPsKey $nk
    $cur = Get-WcoRegValue -Key $nk -Name $Name
    $old = $cur.Value
    if (-not $Apply) { return [pscustomobject]@{ Key = $nk; Name = $Name; Status = 'DryRun'; Before = $old; After = $Value } }
    if ((Test-WcoNeedsAdminForKey $nk) -and -not (Test-WcoAdmin)) { return [pscustomobject]@{ Key = $nk; Name = $Name; Status = 'Blocked'; Reason = '写 HKLM 需要管理员权限' } }
    $s = Get-WcoSession
    $undo = $null
    if (Test-WcoRegKey $nk) {
        if ($cur.Exists) {
            $bak = Join-Path $s.Dir ('reg\' + ([guid]::NewGuid().ToString('N')) + '.reg')
            if (-not (Export-WcoRegKey -Key $nk -File $bak)) { return [pscustomobject]@{ Key = $nk; Name = $Name; Status = 'Error'; Reason = 'reg export 失败，未修改' } }
            $undo = "reg.exe import `"$bak`""
        } else {
            $undo = "Remove-ItemProperty -LiteralPath $(ConvertTo-WcoPsLiteral $psKey) -Name $(ConvertTo-WcoPsLiteral $Name) -ErrorAction SilentlyContinue"
        }
    } else {
        # 找到最近的已存在祖先，回退时删掉新建的最顶层键（而不只是叶子）
        $top = $nk
        $parent = $nk.Substring(0, $nk.LastIndexOf('\'))
        while ($parent.Contains('\') -and -not (Test-WcoRegKey $parent)) {
            $top = $parent
            $parent = $parent.Substring(0, $parent.LastIndexOf('\'))
        }
        $undo = "Remove-Item -LiteralPath $(ConvertTo-WcoPsLiteral (ConvertTo-WcoPsKey $top)) -Recurse -ErrorAction SilentlyContinue"
    }
    Set-WcoRegValueRaw -Key $nk -Name $Name -Value $Value -Type $Type
    [void](Add-WcoChange -Kind $Kind -Target "$nk\$Name" -Before "$old" -After "$Value" -Undo $undo -Risk $Risk)
    return [pscustomobject]@{ Key = $nk; Name = $Name; Status = 'Changed'; Before = $old; After = $Value }
}

function Test-WcoProtectedRegistryKey {
    <#
    判断注册表键是否禁止整键删除。返回原因字符串；可删时返回空串。
    拒绝：各根键与一级键、SOFTWARE\Microsoft*（含 WOW6432Node）、Classes / Policies / WOW6432Node 根、
    HKCR 根与 CLSID 根、整个 HKLM\SYSTEM（服务请用 Remove-WcoService）、多个产品共用的厂商根键（只允许删具体产品子键）。
    #>
    param([Parameter(Mandatory)][string]$Key)
    try { $n = ConvertTo-WcoNativeKey $Key } catch { return "路径无法识别：$Key" }
    $parts = @($n.Split('\') | Where-Object { $_ -ne '' })
    if ($parts.Count -le 2) { return '根键或一级键，禁止整键删除' }
    $hive = $parts[0].ToUpper()
    $p1 = $parts[1].ToLower()
    if ($hive -eq 'HKLM' -and $p1 -eq 'system') { return 'HKLM\SYSTEM 不允许整键删除；服务请用 Remove-WcoService' }
    if ($hive -eq 'HKCR' -and $parts.Count -le 2) { return 'HKCR 根键' }
    if ($hive -eq 'HKCR' -and $parts[1] -ieq 'CLSID' -and $parts.Count -le 2) { return 'CLSID 根' }
    $rest = @($parts[2..($parts.Count - 1)])
    if ($p1 -eq 'software') {
        $i = 0
        if ($rest[0] -ieq 'WOW6432Node') {
            if ($rest.Count -eq 1) { return 'SOFTWARE\WOW6432Node 根' }
            $i = 1
        }
        $vendor = $rest[$i].ToLower()
        $depth = $rest.Count - $i
        if ($vendor -like 'microsoft*') { return 'SOFTWARE\Microsoft 下的键属于系统/微软组件，禁止整键删除' }
        if ($vendor -in @('classes', 'policies', 'clients', 'registeredapplications', 'odbc') -and $depth -eq 1) { return "SOFTWARE\$($rest[$i]) 根" }
        $shared = @('kingsoft', 'tencent', 'baidu', 'alibaba', 'google', 'adobe', 'intel', 'nvidia corporation', 'apple inc.',
            'mozilla', 'oracle', 'realtek', 'amd', 'ati technologies', 'lenovo', 'hp', 'hewlett-packard', 'dell', 'asus',
            'asustek', 'huawei', 'qihu', '360', 'netease', 'bytedance', 'wow6432node')
        if ($vendor -in $shared -and $depth -eq 1) { return "$($rest[$i]) 是多个产品共用的厂商根键，只能删具体产品的子键" }
    }
    return ''
}

function Remove-WcoRegistryKey {
    <#
    .SYNOPSIS
        整键删除注册表键（卸载残留）。默认只演练，-Apply 才执行；HKLM 需要管理员。
    .DESCRIPTION
        先 reg export 到会话目录，再删除；回退 = reg import。共享根键/系统键一律拒绝，见 Test-WcoProtectedRegistryKey。
    #>
    param([Parameter(Mandatory)][string]$Path, [switch]$Apply)
    $r = [pscustomobject]@{ Path = $Path; Status = ''; Reason = '' }
    $why = Test-WcoProtectedRegistryKey -Key $Path
    if ($why) { $r.Status = 'Blocked'; $r.Reason = $why; return $r }
    $nk = ConvertTo-WcoNativeKey $Path
    $r.Path = $nk
    if (-not (Test-WcoRegKey $nk)) { $r.Status = 'Skip'; $r.Reason = '键不存在'; return $r }
    if (-not $Apply) { $r.Status = 'DryRun'; $r.Reason = "将先 reg export 再删除 $nk"; return $r }
    if ((Test-WcoNeedsAdminForKey $nk) -and -not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = '删除 HKLM 键需要管理员权限'; return $r }
    $s = Get-WcoSession
    $bak = Join-Path $s.Dir ('reg\key_' + [guid]::NewGuid().ToString('N') + '.reg')
    if (-not (Export-WcoRegKey -Key $nk -File $bak)) { $r.Status = 'Error'; $r.Reason = 'reg export 失败，未删除'; return $r }
    try {
        Remove-WcoRegKeyRaw -Key $nk
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message; return $r
    }
    [void](Add-WcoChange -Kind registry-key -Target $nk -Before "backup=$bak" -After 'deleted' -Undo "reg.exe import `"$bak`"" -Risk MEDIUM)
    $r.Status = 'Deleted'
    return $r
}

# ---------------------------------------------------------------- 启动项（StartupApproved）
function ConvertTo-WcoStartupApprovedData {
    <# 生成 12 字节 StartupApproved 值：启用 = 02 00 00 00 + 8 个 0；禁用 = 03 00 00 00 + 禁用时间（FILETIME，UTC）。 #>
    param([Parameter(Mandatory)][bool]$Enabled, [datetime]$Time = (Get-Date))
    $b = New-Object byte[] 12
    if ($Enabled) {
        $b[0] = 2
    } else {
        $b[0] = 3
        $ft = [BitConverter]::GetBytes([int64]$Time.ToFileTimeUtc())
        [Array]::Copy($ft, 0, $b, 4, 8)
    }
    return , $b
}

function ConvertFrom-WcoStartupApprovedData {
    <#
    解读 StartupApproved 值。首字节 0x02/0x06 = 启用，0x03/0x07 = 禁用（第 5-12 字节为禁用时间 FILETIME）。
    微软没有公开文档；依据：H. Carvey（windowsir.blogspot.com, 2022-07）、Nutanix（2021-12）、Stack Overflow 59847480，
    三方一致（访问于 2026-11-11）。没有值 = 默认启用。
    #>
    param([AllowNull()][byte[]]$Bytes)
    $r = [pscustomobject]@{ State = 'Absent'; Enabled = $true; DisabledAt = $null; Hex = '' }
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return $r }
    $r.Hex = ($Bytes | ForEach-Object { $_.ToString('X2') }) -join ' '
    switch ($Bytes[0]) {
        { $_ -in 2, 6 } { $r.State = 'Enabled'; $r.Enabled = $true }
        { $_ -in 3, 7 } {
            $r.State = 'Disabled'; $r.Enabled = $false
            if ($Bytes.Length -ge 12) {
                $ft = [BitConverter]::ToInt64($Bytes, 4)
                if ($ft -gt 0) { try { $r.DisabledAt = [datetime]::FromFileTimeUtc($ft).ToLocalTime() } catch { $r.DisabledAt = $null } }
            }
        }
        default { $r.State = 'Unknown'; $r.Enabled = $true }
    }
    return $r
}

function Get-WcoStartupApproved {
    <# 只读：列出 StartupApproved 各作用域下的值及解读结果。 #>
    param([string[]]$Scope = @($script:WcoStartupApprovedKeys.Keys))
    $out = @()
    if (-not $script:IsWin) { return $out }
    foreach ($sc in $Scope) {
        $key = $script:WcoStartupApprovedKeys[$sc]
        if (-not $key) { continue }
        $k = Get-Item -LiteralPath (ConvertTo-WcoPsKey $key) -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            $v = $k.GetValue($n)
            $d = ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]]$v)
            $out += [pscustomobject]@{ Scope = $sc; Name = $n; State = $d.State; DisabledAt = $d.DisabledAt; Hex = $d.Hex }
        }
    }
    return $out
}

function Test-WcoStartupSource {
    <# 确认 StartupApproved 对应的启动项本体存在（Run 值或启动文件夹里的文件）。 #>
    param([Parameter(Mandatory)][string]$Scope, [Parameter(Mandatory)][string]$Name)
    switch ($Scope) {
        'HKCU-Run' { return (Get-WcoRegValue -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' -Name $Name).Exists }
        'HKLM-Run' { return (Get-WcoRegValue -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Run' -Name $Name).Exists }
        'HKLM-Run32' { return (Get-WcoRegValue -Key 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' -Name $Name).Exists }
        'HKCU-StartupFolder' { return Test-WcoFileExist (Join-Path ([Environment]::GetFolderPath('Startup')) $Name) }
        'HKLM-StartupFolder' { return Test-WcoFileExist (Join-Path ([Environment]::GetFolderPath('CommonStartup')) $Name) }
    }
    return $false
}

function Set-WcoStartupApproved {
    <#
    .SYNOPSIS
        像任务管理器「启动应用」/ 设置 › 应用 › 启动 那样开关一个 Run 键或启动文件夹项（不删除 Run 值）。
    .DESCRIPTION
        写 12 字节 StartupApproved 值：启用首字节 0x02，禁用首字节 0x03 + 禁用时间。默认只演练，-Apply 才执行。
        记录原字节（或"absent"），回退时恢复原字节或删除该值。HKLM-* 作用域需要管理员。
        这是关闭 Run 键/启动文件夹自启的首选方式；删除 Run 值属于可选的"彻底删除"，需用户另行确认。
    .EXAMPLE
        Set-WcoStartupApproved -Name 'BaiduYunDetect' -Scope HKCU-Run -Enabled $false -Apply
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('HKCU-Run', 'HKLM-Run', 'HKLM-Run32', 'HKCU-StartupFolder', 'HKLM-StartupFolder')][string]$Scope,
        [Parameter(Mandatory)][bool]$Enabled,
        [switch]$Force,
        [switch]$Apply
    )
    $key = $script:WcoStartupApprovedKeys[$Scope]
    $cur = Get-WcoRegValue -Key $key -Name $Name
    $before = if ($cur.Exists) { (ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]]$cur.Value)) } else { $null }
    $beforeText = if ($before) { "$($before.State) [$($before.Hex)]" } else { 'absent' }
    $want = if ($Enabled) { 'Enabled' } else { 'Disabled' }
    $r = [pscustomobject]@{ Name = $Name; Scope = $Scope; Key = $key; Status = ''; Before = $beforeText; After = $want; Reason = '' }
    if (-not $Force -and -not (Test-WcoStartupSource -Scope $Scope -Name $Name)) {
        $r.Status = 'Skip'; $r.Reason = '找不到对应的启动项（Run 值或启动文件夹文件）；名称要与 Run 值名 / 快捷方式文件名完全一致'; return $r
    }
    $isEnabledNow = (-not $before) -or $before.Enabled
    if ($Enabled -eq $isEnabledNow -and ($before -or $Enabled)) { $r.Status = 'Skip'; $r.Reason = "已经是 $want"; return $r }
    if (-not $Apply) { $r.Status = 'DryRun'; $r.Reason = "将写 $key\$Name = $want"; return $r }
    if ($Scope -like 'HKLM-*' -and -not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = 'HKLM 作用域需要管理员权限'; return $r }
    $bytes = ConvertTo-WcoStartupApprovedData -Enabled $Enabled
    $psKey = ConvertTo-WcoPsKey $key
    if ($cur.Exists) {
        $old = @([byte[]]$cur.Value | ForEach-Object { '0x{0:X2}' -f $_ }) -join ','
        $undo = "Set-ItemProperty -LiteralPath $(ConvertTo-WcoPsLiteral $psKey) -Name $(ConvertTo-WcoPsLiteral $Name) -Type Binary -Value ([byte[]]@($old))"
    } else {
        $undo = "Remove-ItemProperty -LiteralPath $(ConvertTo-WcoPsLiteral $psKey) -Name $(ConvertTo-WcoPsLiteral $Name) -ErrorAction SilentlyContinue"
    }
    try {
        Set-WcoRegValueRaw -Key $key -Name $Name -Value $bytes -Type Binary
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message; return $r
    }
    [void](Add-WcoChange -Kind startup-approved -Target "$key\$Name" -Before $beforeText -After $want -Undo $undo -Risk LOW)
    $r.Status = 'Changed'
    return $r
}

function Get-WcoStartupItem {
    <#
    只读：汇总登录自启位置（Run / RunOnce / RunOnceEx / WOW6432Node / Policies\Explorer\Run / 启动文件夹），
    并把 StartupApproved 状态对上（Approved=Enabled/Disabled/Absent(→默认启用)/n/a）。
    #>
    $out = @()
    if (-not $script:IsWin) { return $out }
    $approved = @{}
    foreach ($a in @(Get-WcoStartupApproved)) { $approved["$($a.Scope)|$($a.Name)"] = $a }
    $runKeys = @(
        @{ Src = 'HKCU-Run'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'; Scope = 'HKCU-Run' },
        @{ Src = 'HKLM-Run'; Key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Run'; Scope = 'HKLM-Run' },
        @{ Src = 'HKLM-Run32'; Key = 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Scope = 'HKLM-Run32' },
        @{ Src = 'HKCU-RunOnce'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = $null },
        @{ Src = 'HKLM-RunOnce'; Key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = $null },
        @{ Src = 'HKLM-RunOnce32'; Key = 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Scope = $null },
        @{ Src = 'HKCU-Policies-Run'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Scope = $null },
        @{ Src = 'HKLM-Policies-Run'; Key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Scope = $null }
    )
    foreach ($rk in $runKeys) {
        $k = Get-Item -LiteralPath (ConvertTo-WcoPsKey $rk.Key) -ErrorAction SilentlyContinue
        if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            if ($n -eq '') { continue }
            $state = 'n/a'; $at = $null
            if ($rk.Scope) {
                $a = $approved["$($rk.Scope)|$n"]
                if ($a) { $state = $a.State; $at = $a.DisabledAt } else { $state = 'Absent' }
            }
            $out += [pscustomobject]@{ Source = $rk.Src; Name = $n; Command = [string]$k.GetValue($n); Approved = $state; DisabledAt = $at; Location = $rk.Key }
        }
    }
    # RunOnceEx：子键里的命令
    $rox = 'HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnceEx'
    Get-ChildItem -LiteralPath (ConvertTo-WcoPsKey $rox) -ErrorAction SilentlyContinue | ForEach-Object {
        $sub = $_
        foreach ($n in $sub.GetValueNames()) {
            $out += [pscustomobject]@{ Source = 'HKLM-RunOnceEx'; Name = "$($sub.PSChildName)\$n"; Command = [string]$sub.GetValue($n); Approved = 'n/a'; DisabledAt = $null; Location = $rox }
        }
    }
    foreach ($f in @(@{ Src = 'HKCU-StartupFolder'; Dir = [Environment]::GetFolderPath('Startup') }, @{ Src = 'HKLM-StartupFolder'; Dir = [Environment]::GetFolderPath('CommonStartup') })) {
        if (-not $f.Dir -or -not (Test-Path -LiteralPath $f.Dir)) { continue }
        Get-ChildItem -LiteralPath $f.Dir -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $a = $approved["$($f.Src)|$($_.Name)"]
            $state = if ($a) { $a.State } else { 'Absent' }
            $at = if ($a) { $a.DisabledAt } else { $null }
            $out += [pscustomobject]@{ Source = $f.Src; Name = $_.Name; Command = $_.FullName; Approved = $state; DisabledAt = $at; Location = $f.Dir }
        }
    }
    return $out
}

# ---------------------------------------------------------------- 计划任务
function Get-WcoScheduledTaskRaw {
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName)
    if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return $null }
    return Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
}

function Format-WcoTaskPath {
    param([string]$TaskPath)
    if (-not $TaskPath) { return '\' }
    $p = $TaskPath
    if (-not $p.StartsWith('\')) { $p = '\' + $p }
    if (-not $p.EndsWith('\')) { $p = $p + '\' }
    return $p
}

function Disable-WcoScheduledTask {
    <#
    .SYNOPSIS
        停用一个计划任务（不删除）。默认只演练，-Apply 才执行；需要管理员。回退 = Enable-ScheduledTask。
    .EXAMPLE
        Disable-WcoScheduledTask -TaskPath '\' -TaskName 'WpsUpdateTask_xxx' -Apply
    #>
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName, [switch]$Apply)
    $tp = Format-WcoTaskPath $TaskPath
    $r = [pscustomobject]@{ TaskPath = $tp; TaskName = $TaskName; Status = ''; Before = $null; Reason = '' }
    $t = Get-WcoScheduledTaskRaw -TaskPath $tp -TaskName $TaskName
    if (-not $t) { $r.Status = 'Skip'; $r.Reason = '任务不存在（注意 -TaskPath 要写全，例如 \Microsoft\Windows\XXX\）'; return $r }
    $r.Before = [string](Get-WcoProp $t 'State')
    if ($r.Before -eq 'Disabled') { $r.Status = 'Skip'; $r.Reason = '已经是停用状态'; return $r }
    if (-not $Apply) { $r.Status = 'DryRun'; $r.Reason = "将停用 $tp$TaskName"; return $r }
    if (-not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = '停用计划任务需要管理员权限'; return $r }
    try {
        Disable-ScheduledTask -TaskPath $tp -TaskName $TaskName -ErrorAction Stop | Out-Null
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message; return $r
    }
    $risk = if ($tp -like '\Microsoft\*') { 'HIGH' } else { 'LOW' }
    [void](Add-WcoChange -Kind scheduled-task -Target "$tp$TaskName" -Before $r.Before -After 'Disabled' -Undo "Enable-ScheduledTask -TaskPath $(ConvertTo-WcoPsLiteral $tp) -TaskName $(ConvertTo-WcoPsLiteral $TaskName)" -Risk $risk)
    $r.Status = 'Changed'
    return $r
}

function Remove-WcoScheduledTask {
    <#
    .SYNOPSIS
        删除一个第三方计划任务。先 Export-ScheduledTask 存 XML，回退 = 用 XML 重新注册。拒绝 \Microsoft\ 下的任务。
    #>
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName, [switch]$Apply)
    $tp = Format-WcoTaskPath $TaskPath
    $r = [pscustomobject]@{ TaskPath = $tp; TaskName = $TaskName; Status = ''; Reason = '' }
    if ($tp -like '\Microsoft\*') { $r.Status = 'Blocked'; $r.Reason = '\Microsoft\ 下的任务属于系统，禁止删除（需要时只能停用）'; return $r }
    $t = Get-WcoScheduledTaskRaw -TaskPath $tp -TaskName $TaskName
    if (-not $t) { $r.Status = 'Skip'; $r.Reason = '任务不存在'; return $r }
    if (-not $Apply) { $r.Status = 'DryRun'; $r.Reason = "将先导出 XML 再删除 $tp$TaskName"; return $r }
    if (-not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = '删除计划任务需要管理员权限'; return $r }
    $s = Get-WcoSession
    $xmlFile = Join-Path $s.Dir ('task_' + ($TaskName -replace '[^\w.-]', '_') + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.xml')
    try {
        $xml = Export-ScheduledTask -TaskPath $tp -TaskName $TaskName -ErrorAction Stop
        [IO.File]::WriteAllText($xmlFile, $xml, (New-Object Text.UnicodeEncoding($false, $true)))
        Unregister-ScheduledTask -TaskPath $tp -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message; return $r
    }
    $undo = "Register-ScheduledTask -TaskPath $(ConvertTo-WcoPsLiteral $tp) -TaskName $(ConvertTo-WcoPsLiteral $TaskName) -Xml (Get-Content -LiteralPath $(ConvertTo-WcoPsLiteral $xmlFile) -Raw)"
    [void](Add-WcoChange -Kind scheduled-task-delete -Target "$tp$TaskName" -Before "xml=$xmlFile" -After 'deleted' -Undo $undo -Risk MEDIUM -Note '以特定账户密码运行的任务重新注册时可能要求输入密码')
    $r.Status = 'Deleted'
    return $r
}

# ---------------------------------------------------------------- 已安装程序与卸载
function Get-WcoUninstallEntryRaw {
    <# 读三处 Uninstall 键的原始条目（单独成函数便于 Mock）。 #>
    $out = @()
    if (-not $script:IsWin) { return $out }
    $roots = @(
        @{ Scope = 'HKLM'; Key = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Scope = 'HKLM32'; Key = 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Scope = 'HKCU'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall' }
    )
    foreach ($root in $roots) {
        Get-ChildItem -LiteralPath (ConvertTo-WcoPsKey $root.Key) -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if ($p) {
                $p | Add-Member -NotePropertyName WcoScope -NotePropertyValue $root.Scope -Force
                $p | Add-Member -NotePropertyName WcoKey -NotePropertyValue "$($root.Key)\$($_.PSChildName)" -Force
                $out += $p
            }
        }
    }
    return $out
}

function Get-WcoInstalledProgram {
    <#
    .SYNOPSIS
        只读：列出已安装程序（HKLM、HKLM WOW6432Node、HKCU 的 Uninstall 项），可按 DisplayName 通配过滤。
    .DESCRIPTION
        输出 DisplayName、Publisher、DisplayVersion、InstallLocation、UninstallString、QuietUninstallString、
        WindowsInstaller、ProductCode、SystemComponent、EstimatedSizeMB、Scope、KeyPath，
        以及能定位到主程序时的签名（Signer / SignatureStatus）。-NoSignature 跳过签名读取（更快）。
        SystemComponent=1 的条目在"应用和功能"里不显示，也一并列出（Hidden=$true）。
    #>
    param([string]$Name = '*', [switch]$NoSignature)
    $out = @()
    foreach ($p in @(Get-WcoUninstallEntryRaw)) {
        $dn = [string](Get-WcoProp $p 'DisplayName')
        if (-not $dn) { continue }
        if ($dn -notlike $Name) { continue }
        $keyName = [string](Get-WcoProp $p 'PSChildName')
        if (-not $keyName) { $wk = [string](Get-WcoProp $p 'WcoKey'); if ($wk) { $keyName = Split-Path -Leaf $wk } }
        $isMsi = ([int](Get-WcoProp $p 'WindowsInstaller') -eq 1)
        $pc = $null
        if ($keyName -match '^\{[0-9A-Fa-f-]{36}\}$') { $pc = $keyName }
        $icon = [string](Get-WcoProp $p 'DisplayIcon')
        $loc = [string](Get-WcoProp $p 'InstallLocation')
        $mainExe = $null
        $cand = Resolve-WcoExecutablePath $icon
        if ($cand -and $cand -match '\.exe$' -and $cand -notmatch '(?i)\\(unins|uninst|uninstall)[^\\]*\.exe$') { $mainExe = $cand }
        $sig = $null
        if (-not $NoSignature -and $mainExe) { $sig = Get-WcoFileSigner -Path $mainExe }
        $size = Get-WcoProp $p 'EstimatedSize'
        $out += [pscustomobject]@{
            DisplayName          = $dn
            Publisher            = [string](Get-WcoProp $p 'Publisher')
            DisplayVersion       = [string](Get-WcoProp $p 'DisplayVersion')
            InstallLocation      = $loc
            UninstallString      = [string](Get-WcoProp $p 'UninstallString')
            QuietUninstallString = [string](Get-WcoProp $p 'QuietUninstallString')
            WindowsInstaller     = $isMsi
            ProductCode          = $pc
            SystemComponent      = ([int](Get-WcoProp $p 'SystemComponent') -eq 1)
            Hidden               = ([int](Get-WcoProp $p 'SystemComponent') -eq 1)
            EstimatedSizeMB      = if ($size) { [math]::Round([double]$size / 1024, 1) } else { $null }
            Scope                = [string](Get-WcoProp $p 'WcoScope')
            KeyPath              = [string](Get-WcoProp $p 'WcoKey')
            MainExe              = $mainExe
            Signer               = if ($sig) { $sig.Organization } else { $null }
            SignatureStatus      = if ($sig) { $sig.Status } else { $null }
        }
    }
    return $out
}

function Get-WcoUninstallCommand {
    <# 根据已安装条目生成卸载命令（不执行）。返回 FilePath / Arguments / Kind（msi|exe）或 Blocked 原因。 #>
    param([Parameter(Mandatory)]$Program)
    $guidRe = '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}'
    $us = [string](Get-WcoProp $Program 'UninstallString')
    $pc = [string](Get-WcoProp $Program 'ProductCode')
    if ((Get-WcoProp $Program 'WindowsInstaller') -and $pc) {
        return [pscustomobject]@{ Kind = 'msi'; FilePath = 'msiexec.exe'; Arguments = "/x $pc"; Blocked = '' }
    }
    if ($us -match '(?i)msiexec' -and $us -match $guidRe) {
        $g = [regex]::Match($us, $guidRe).Value
        return [pscustomobject]@{ Kind = 'msi'; FilePath = 'msiexec.exe'; Arguments = "/x $g"; Blocked = '' }
    }
    if (-not $us) { return [pscustomobject]@{ Kind = ''; FilePath = ''; Arguments = ''; Blocked = '没有 UninstallString（可能是附属组件，请卸载主程序）' } }
    if ($us -match '^\s*"?(https?:|www\.)') { return [pscustomobject]@{ Kind = ''; FilePath = ''; Arguments = ''; Blocked = "UninstallString 指向网页（$us），不是卸载程序，疑似卸载陷阱" } }
    $sp = Split-WcoCommandLine -CommandLine $us
    if (-not $sp -or -not $sp.FilePath) { return [pscustomobject]@{ Kind = ''; FilePath = ''; Arguments = ''; Blocked = "无法解析 UninstallString：$us" } }
    if (-not (Test-WcoFileExist $sp.FilePath)) {
        return [pscustomobject]@{ Kind = 'exe'; FilePath = $sp.FilePath; Arguments = $sp.Arguments; Blocked = "卸载程序文件不存在：$($sp.FilePath)（孤儿卸载项；改用 Find-WcoLeftover 找残留）" }
    }
    return [pscustomobject]@{ Kind = 'exe'; FilePath = $sp.FilePath; Arguments = $sp.Arguments; Blocked = '' }
}

function Invoke-WcoUninstall {
    <#
    .SYNOPSIS
        启动程序自己的卸载程序（交互式）。默认只演练（打印命令），-Apply 才启动。
    .DESCRIPTION
        MSI → msiexec.exe /x {ProductCode}（不加 /qn，用户能看到界面）；其他 → 原样运行 UninstallString（厂商卸载程序）。
        用户需要自己点完卸载向导，留意"保留数据/修复/推荐安装"等挽留与捆绑勾选。
        不默认使用 QuietUninstallString（静默会让用户看不到捆绑选项）。
        记入 changes.json（Kind=uninstall，不可自动回退）。返回 Status=UninstallerStarted ——这不等于已卸载，
        卸载窗口关闭后必须用 Get-WcoInstalledProgram 与 Find-WcoLeftover 复扫确认。
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')][string]$Name,
        [Parameter(Mandatory, ParameterSetName = 'ByCode')][string]$ProductCode,
        [switch]$Wait,
        [switch]$Apply
    )
    $target = if ($PSCmdlet.ParameterSetName -eq 'ByCode') { $ProductCode } else { $Name }
    $r = [pscustomobject]@{ Target = $target; Status = ''; Command = ''; Reason = ''; ProcessId = $null }
    $all = @(Get-WcoInstalledProgram -NoSignature)
    if ($PSCmdlet.ParameterSetName -eq 'ByCode') {
        $hits = @($all | Where-Object { $_.ProductCode -and $_.ProductCode -ieq $ProductCode })
    } else {
        $hits = @($all | Where-Object { $_.DisplayName -eq $Name })
    }
    if ($hits.Count -eq 0) { $r.Status = 'Skip'; $r.Reason = '已安装列表里找不到（DisplayName 要完全一致，或改用 -ProductCode）'; return $r }
    if ($hits.Count -gt 1) {
        $r.Status = 'Blocked'
        $r.Reason = "找到 $($hits.Count) 个同名条目，请改用 -ProductCode 指定：" + (($hits | ForEach-Object { "$($_.DisplayName) [$($_.Scope)] $($_.ProductCode)" }) -join '；')
        return $r
    }
    $p = $hits[0]
    if ($p.SystemComponent) { $r.Status = 'Blocked'; $r.Reason = '这是隐藏的系统组件/附属组件（SystemComponent=1），请卸载它所属的主程序'; return $r }
    $cmd = Get-WcoUninstallCommand -Program $p
    $r.Command = ("$($cmd.FilePath) $($cmd.Arguments)").Trim()
    if ($cmd.Blocked) { $r.Status = 'Blocked'; $r.Reason = $cmd.Blocked; return $r }
    if (-not $Apply) {
        $r.Status = 'DryRun'
        $r.Reason = '加 -Apply 才会启动卸载程序；向导里留意"保留数据/修复/推荐安装"等勾选'
        return $r
    }
    try {
        $sp = @{ FilePath = $cmd.FilePath; PassThru = $true; ErrorAction = 'Stop' }
        if ($cmd.Arguments) { $sp.ArgumentList = $cmd.Arguments }
        if ($Wait) { $sp.Wait = $true }
        $proc = Start-Process @sp
        if ($proc) { $r.ProcessId = $proc.Id }
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message; return $r
    }
    [void](Add-WcoChange -Kind uninstall -Target "$($p.DisplayName) $($p.DisplayVersion)".Trim() -Before "已安装（$($p.Scope)）" -After '已启动卸载程序' -Risk MEDIUM `
            -Note "卸载不可自动回退；如需恢复请重新安装（winget 或官网）。命令：$($r.Command)")
    $r.Status = 'UninstallerStarted'
    $r.Reason = '已启动卸载程序。卸载窗口关闭后请复扫：Get-WcoInstalledProgram -Name ''<名称>''；Find-WcoLeftover -Name ''<名称>'''
    return $r
}

# ---------------------------------------------------------------- 商店应用（Appx）
function Get-WcoAppxRaw {
    param([Parameter(Mandatory)][string]$Name, [switch]$AllUsers)
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) { return $null }
    $sp = @{ ErrorAction = 'SilentlyContinue' }
    if ($AllUsers) { $sp.AllUsers = $true }
    if ($Name -match '_') {
        return @(Get-AppxPackage @sp | Where-Object { $_.PackageFamilyName -like $Name -or $_.PackageFullName -like $Name })
    }
    return @(Get-AppxPackage -Name $Name @sp)
}

function Test-WcoProtectedAppx {
    <# 返回拒绝原因；可移除时返回空串。 #>
    param([Parameter(Mandatory)]$Package)
    if (Get-WcoProp $Package 'IsFramework') { return '框架包（被其他应用依赖）' }
    if (Get-WcoProp $Package 'NonRemovable') { return '系统标记为不可移除（NonRemovable）' }
    if ([string](Get-WcoProp $Package 'SignatureKind') -eq 'System') { return '系统签名包（SignatureKind=System）' }
    $n = [string](Get-WcoProp $Package 'Name')
    foreach ($pat in $script:WcoProtectedAppx) { if ($n -like $pat) { return "必需组件（$pat）" } }
    return ''
}

function Remove-WcoAppxPackage {
    <#
    .SYNOPSIS
        移除商店/预装应用（Appx/MSIX）。默认只演练，-Apply 才执行。-AllUsers / -Provisioned 需要管理员。
    .DESCRIPTION
        拒绝框架包、NonRemovable、SignatureKind=System 以及必需组件（商店、App Installer、WebView2、VCLibs、UI.Xaml、
        Windows 安全中心、ShellExperienceHost、StartMenuExperienceHost 等）。照片、计算器等可以移除。
        -Provisioned 同时从系统映像里去掉预配，使"新建的用户"不再自动获得；它不影响已有用户（官方语义）。
        回退不能自动完成：undo.ps1 写明从 Microsoft Store / winget 重新安装的方式。
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllUsers,
        [switch]$Provisioned,
        [switch]$Apply
    )
    $r = [pscustomobject]@{ Name = $Name; Status = ''; Packages = @(); Refused = @(); Reason = '' }
    if ($Name.Trim('*', ' ') -eq '') { $r.Status = 'Blocked'; $r.Reason = '名称不能只有通配符'; return $r }
    $pkgs = Get-WcoAppxRaw -Name $Name -AllUsers:$AllUsers
    if ($null -eq $pkgs) { $r.Status = 'Error'; $r.Reason = '当前环境没有 Get-AppxPackage（仅 Windows 10/11 可用）'; return $r }
    $pkgs = @($pkgs)
    if ($pkgs.Count -eq 0) { $r.Status = 'Skip'; $r.Reason = '没有匹配的应用包'; return $r }
    if ($Name.Contains('*') -and $pkgs.Count -gt 5) { $r.Status = 'Blocked'; $r.Reason = "通配符匹配到 $($pkgs.Count) 个包，范围过大；请写具体包名"; return $r }
    $ok = @()
    foreach ($p in $pkgs) {
        $why = Test-WcoProtectedAppx -Package $p
        if ($why) { $r.Refused += "$($p.Name)：$why" } else { $ok += $p }
    }
    $r.Packages = @($ok | ForEach-Object { $_.PackageFullName })
    if ($ok.Count -eq 0) { $r.Status = 'Blocked'; $r.Reason = '匹配到的包都在保护清单内'; return $r }
    if (-not $Apply) { $r.Status = 'DryRun'; $r.Reason = "将移除 $($ok.Count) 个包" + $(if ($Provisioned) { '，并去掉预配' } else { '' }); return $r }
    if (($AllUsers -or $Provisioned) -and -not (Test-WcoAdmin)) { $r.Status = 'Blocked'; $r.Reason = '-AllUsers / -Provisioned 需要管理员权限'; return $r }
    $errors = @()
    foreach ($p in $ok) {
        try {
            if ($AllUsers) { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop } else { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
            if ($Provisioned) {
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $p.Name } |
                    ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null }
            }
            $pfn = [string](Get-WcoProp $p 'PackageFamilyName')
            [void](Add-WcoChange -Kind appx -Target $p.PackageFullName -Before 'installed' -After $(if ($Provisioned) { 'removed+deprovisioned' } else { 'removed' }) -Risk MEDIUM `
                    -Note "需要时从 Microsoft Store 重新安装：ms-windows-store://pdp/?PFN=$pfn ；或 winget search `"$($p.Name)`" 后 winget install --id <ID> -s msstore")
        } catch {
            $errors += "$($p.Name)：$($_.Exception.Message)"
        }
    }
    if ($errors.Count -gt 0) { $r.Status = 'Error'; $r.Reason = $errors -join '；' } else { $r.Status = 'Removed' }
    return $r
}

# ---------------------------------------------------------------- 残留评分（思路参考 BCUninstaller 的置信度模型，代码自写）
function Get-WcoNameKey {
    <# 规范化名称：小写、去版本号/位数/括号内容/公司后缀、只保留字母数字与中日韩文字。 #>
    param([string]$Text)
    if (-not $Text) { return '' }
    $t = $Text.ToLower()
    $t = $t -replace '\(.*?\)|（.*?）|\[.*?\]', ' '
    $t = $t -replace '\b(x64|x86|amd64|arm64|64-bit|32-bit|64位|32位)\b', ' '
    $t = $t -replace '\bv?\d+(\.\d+)+\b', ' '
    $t = $t -replace '\b(co\.?,?\s*ltd\.?|inc\.?|llc|corporation|corp\.?|gmbh|limited|ltd\.?)\b', ' '
    $t = $t -replace '(有限公司|股份有限公司|有限责任公司)', ''
    $t = $t -replace '[^\p{L}\p{Nd}]', ''
    return $t
}

function Get-WcoEditDistance {
    param([string]$A, [string]$B)
    $n = $A.Length; $m = $B.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }
    $prev = New-Object int[] ($m + 1)
    $curr = New-Object int[] ($m + 1)
    for ($j = 0; $j -le $m; $j++) { $prev[$j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        $curr[0] = $i
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $curr[$j] = [math]::Min([math]::Min($prev[$j] + 1, $curr[$j - 1] + 1), $prev[$j - 1] + $cost)
        }
        $tmp = $prev; $prev = $curr; $curr = $tmp
    }
    return $prev[$m]
}

function Get-WcoNameMatch {
    <#
    比较两个名称：Exact / Fuzzy / None。规范化后相等 = Exact；任一方 ≤4 个字符时只认完全相等（"QQ""WPS""百度网盘"这类短名不做模糊匹配）；
    编辑距离 ≤1 = Exact；互相包含 = Fuzzy。
    #>
    param([string]$Candidate, [string]$Target)
    $a = Get-WcoNameKey $Candidate
    $b = Get-WcoNameKey $Target
    if (-not $a -or -not $b) { return 'None' }
    if ($a -eq $b) { return 'Exact' }
    if ([math]::Min($a.Length, $b.Length) -le 4) { return 'None' }
    if ((Get-WcoEditDistance $a $b) -le 1) { return 'Exact' }
    if ($a.Contains($b) -or $b.Contains($a)) { return 'Fuzzy' }
    return 'None'
}

function ConvertTo-WcoConfidence {
    param([double]$Score)
    if ($Score -lt 0) { return 'Bad' }
    if ($Score -lt 2) { return 'Questionable' }
    if ($Score -lt 5) { return 'Good' }
    return 'VeryGood'
}

function Test-WcoPathUnder {
    param([string]$Child, [string]$Parent)
    if (-not $Child -or -not $Parent) { return $false }
    $c = $Child.TrimEnd('\', '/') + '\'
    $p = $Parent.TrimEnd('\', '/') + '\'
    $c = $c.Replace('/', '\'); $p = $p.Replace('/', '\')
    return $c.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)
}

function Get-WcoLeftoverRoot {
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA)
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA 'Programs') }
    return @($roots | Where-Object { $_ } | Select-Object -Unique)
}

function Find-WcoLeftover {
    <#
    .SYNOPSIS
        只读：卸载后找残留（目录、注册表键、服务、计划任务），每条给分数与置信度。不删除任何东西。
    .DESCRIPTION
        评分思路参考 BCUninstaller（Apache-2.0）的残留置信度模型，代码为本仓库自写：
          +6 就是 InstallLocation，+4 位于 InstallLocation 之下；+3 名称精确匹配，+1 模糊匹配；+2 父目录是该发行商；+1 空目录/空键
          -7 仍被其他已安装程序引用（其 InstallLocation/卸载程序/图标在此目录下）；-4 名称同时精确匹配另一个已安装程序；
          -3 本身是发行商根目录（可能被同厂商其他软件共用）；-4 同发行商还有其他已安装程序；-2 含可执行文件；
          -10 程序仍在已安装列表里（先卸载再复扫）
        分级：<0 Bad，<2 Questionable，<5 Good，≥5 VeryGood。名称 ≤4 个字符不做模糊匹配；重解析点（junction 等）跳过。
        处理：只在用户确认后，目录走 Invoke-WcoRecycle、注册表走 Remove-WcoRegistryKey、服务走 Remove-WcoService、
        任务走 Remove-WcoScheduledTask；只有用户要求时才把 Good 及以上默认勾选，Bad 不建议处理。
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Publisher,
        [string]$InstallLocation,
        [string[]]$SearchRoot,
        [switch]$SkipSystem
    )
    $installed = @(Get-WcoInstalledProgram -NoSignature)
    $others = @($installed | Where-Object { $_.DisplayName -ne $Name })
    $stillInstalled = @($installed | Where-Object { $_.DisplayName -eq $Name }).Count -gt 0
    $pubKey = Get-WcoNameKey $Publisher
    $samePublisherCount = 0
    if ($pubKey) { $samePublisherCount = @($others | Where-Object { (Get-WcoNameKey $_.Publisher) -eq $pubKey }).Count }
    $otherRefs = @()
    foreach ($o in $others) {
        if ($o.InstallLocation) { $otherRefs += $o.InstallLocation }
        foreach ($s in @($o.UninstallString, $o.MainExe)) {
            $e = Resolve-WcoExecutablePath $s
            if ($e -and $e -notmatch '(?i)msiexec') { $otherRefs += (Split-Path -Parent $e) }
        }
    }
    $otherNames = @($others | ForEach-Object { $_.DisplayName })
    $loc = if ($InstallLocation) { $InstallLocation.Trim().Trim('"').TrimEnd('\') } else { '' }
    $results = New-Object System.Collections.ArrayList

    $score = {
        param([string]$CandName, [string]$CandPath, [bool]$ParentIsPublisher, [bool]$IsEmpty, [bool]$HasExe, [bool]$IsDir)
        $s = 0; $why = @()
        $locHit = $false
        if ($loc -and $CandPath) {
            if ($CandPath.TrimEnd('\') -ieq $loc) { $s += 6; $why += 'InstallLocation 指向此处'; $locHit = $true }
            elseif (Test-WcoPathUnder $CandPath $loc) { $s += 4; $why += '位于 InstallLocation 之下'; $locHit = $true }
        }
        $m = Get-WcoNameMatch $CandName $Name
        if ($m -eq 'Exact') { $s += 3; $why += '名称精确匹配' } elseif ($m -eq 'Fuzzy') { $s += 1; $why += '名称模糊匹配' }
        if (-not $locHit -and $m -eq 'None') { return $null }
        if ($ParentIsPublisher) { $s += 2; $why += '父目录是该发行商' }
        if ($IsEmpty) { $s += 1; $why += '空' }
        if ($pubKey -and (Get-WcoNameKey $CandName) -eq $pubKey) {
            $s -= 3; $why += '发行商根，可能共用'
            if ($samePublisherCount -gt 0) { $s -= 4; $why += "同发行商还有 $samePublisherCount 个已安装程序" }
        }
        if ($IsDir -and $CandPath) {
            foreach ($ref in $otherRefs) {
                if ((Test-WcoPathUnder $ref $CandPath)) { $s -= 7; $why += '仍被其他已安装程序引用'; break }
            }
        }
        foreach ($on in $otherNames) { if ((Get-WcoNameMatch $CandName $on) -eq 'Exact') { $s -= 4; $why += "名称也匹配已安装的「$on」"; break } }
        if ($HasExe -and -not $locHit) { $s -= 2; $why += '含可执行文件' }
        if ($stillInstalled) { $s -= 10; $why += '程序仍在已安装列表中，先卸载再复扫' }
        return [pscustomobject]@{ Score = $s; Reasons = ($why -join '；') }
    }

    # ---- 目录
    $roots = if ($SearchRoot) { $SearchRoot } else { Get-WcoLeftoverRoot }
    $dirCands = New-Object System.Collections.ArrayList
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            [void]$dirCands.Add(@{ Dir = $d; ParentPub = $false })
            if ($pubKey -and (Get-WcoNameKey $d.Name) -eq $pubKey) {
                foreach ($sd in @(Get-ChildItem -LiteralPath $d.FullName -Directory -Force -ErrorAction SilentlyContinue)) {
                    if ($sd.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                    [void]$dirCands.Add(@{ Dir = $sd; ParentPub = $true })
                }
            }
        }
    }
    if ($loc -and (Test-Path -LiteralPath $loc -PathType Container)) {
        $li = Get-Item -LiteralPath $loc -Force
        if (-not ($li.Attributes -band [IO.FileAttributes]::ReparsePoint)) { [void]$dirCands.Add(@{ Dir = $li; ParentPub = $false }) }
    }
    $seen = @{}
    foreach ($c in $dirCands) {
        $d = $c.Dir
        if ($seen.ContainsKey($d.FullName)) { continue }
        $seen[$d.FullName] = 1
        $children = @(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue)
        $hasExe = @($children | Where-Object { -not $_.PSIsContainer -and $_.Extension -in @('.exe', '.dll', '.sys') }).Count -gt 0
        $sc = & $score $d.Name $d.FullName $c.ParentPub ($children.Count -eq 0) $hasExe $true
        if (-not $sc) { continue }
        $m = Measure-WcoDirectory -Path $d.FullName
        [void]$results.Add([pscustomobject]@{
                Type = 'Directory'; Path = $d.FullName; Score = $sc.Score; Confidence = (ConvertTo-WcoConfidence $sc.Score)
                SizeMB = [math]::Round($m.Bytes / 1MB, 1); Reasons = $sc.Reasons
                Action = "Invoke-WcoRecycle -Path $(ConvertTo-WcoPsLiteral $d.FullName)"
            })
    }

    if ($script:IsWin -and -not $SkipSystem) {
        # ---- 注册表（只看 SOFTWARE 下一级与发行商下一级）
        foreach ($hive in @('HKCU\Software', 'HKLM\Software', 'HKLM\Software\WOW6432Node')) {
            foreach ($k in @(Get-ChildItem -LiteralPath (ConvertTo-WcoPsKey $hive) -ErrorAction SilentlyContinue)) {
                $kn = $k.PSChildName
                $list = @(@{ Key = $k; ParentPub = $false })
                if ($pubKey -and (Get-WcoNameKey $kn) -eq $pubKey) {
                    foreach ($sk in @(Get-ChildItem -LiteralPath $k.PSPath -ErrorAction SilentlyContinue)) { $list += @{ Key = $sk; ParentPub = $true } }
                }
                foreach ($e in $list) {
                    $nk = ConvertTo-WcoNativeKey $e.Key.Name
                    $empty = ($e.Key.SubKeyCount -eq 0 -and $e.Key.ValueCount -eq 0)
                    $sc = & $score $e.Key.PSChildName '' $e.ParentPub $empty $false $false
                    if (-not $sc) { continue }
                    $prot = Test-WcoProtectedRegistryKey -Key $nk
                    $s2 = $sc.Score; $rs = $sc.Reasons
                    if ($prot) { $s2 -= 10; $rs = "$rs；$prot" }
                    [void]$results.Add([pscustomobject]@{
                            Type = 'RegistryKey'; Path = $nk; Score = $s2; Confidence = (ConvertTo-WcoConfidence $s2); SizeMB = $null; Reasons = $rs
                            Action = "Remove-WcoRegistryKey -Path $(ConvertTo-WcoPsLiteral $nk)"
                        })
                }
            }
        }
        # ---- 服务
        foreach ($svc in @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue)) {
            $exe = Resolve-WcoExecutablePath ([string]$svc.PathName)
            if (-not $exe) { continue }
            $s = 0; $why = @()
            if ($loc -and (Test-WcoPathUnder $exe $loc)) { $s += 6; $why += '程序文件在 InstallLocation 之下' }
            else {
                $m = Get-WcoNameMatch $svc.Name $Name
                $m2 = Get-WcoNameMatch (Split-Path -Leaf (Split-Path -Parent $exe)) $Name
                if ($m -eq 'Exact' -or $m2 -eq 'Exact') { $s += 3; $why += '服务名/所在目录精确匹配' } else { continue }
            }
            if ($stillInstalled) { $s -= 10; $why += '程序仍在已安装列表中' }
            [void]$results.Add([pscustomobject]@{
                    Type = 'Service'; Path = $svc.Name; Score = $s; Confidence = (ConvertTo-WcoConfidence $s); SizeMB = $null; Reasons = (($why + "ImagePath=$($svc.PathName)") -join '；')
                    Action = "Set-WcoServiceStartType -Name $(ConvertTo-WcoPsLiteral $svc.Name) -StartType disabled，重启观察后 Remove-WcoService -Name $(ConvertTo-WcoPsLiteral $svc.Name)"
                })
        }
        # ---- 计划任务
        if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
            foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
                $exes = @($t.Actions | ForEach-Object { Get-WcoProp $_ 'Execute' } | Where-Object { $_ })
                $s = 0; $why = @()
                $hit = $false
                foreach ($x in $exes) { if ($loc -and (Test-WcoPathUnder ([Environment]::ExpandEnvironmentVariables($x.Trim('"'))) $loc)) { $hit = $true } }
                if ($hit) { $s += 5; $why += '任务动作指向 InstallLocation' }
                else {
                    $m = Get-WcoNameMatch $t.TaskName $Name
                    if ($m -eq 'Exact') { $s += 3; $why += '任务名精确匹配' } elseif ($m -eq 'Fuzzy') { $s += 1; $why += '任务名模糊匹配' } else { continue }
                }
                if ($stillInstalled) { $s -= 10; $why += '程序仍在已安装列表中' }
                [void]$results.Add([pscustomobject]@{
                        Type = 'ScheduledTask'; Path = "$($t.TaskPath)$($t.TaskName)"; Score = $s; Confidence = (ConvertTo-WcoConfidence $s); SizeMB = $null
                        Reasons = (($why + "动作=$($exes -join ' | ')") -join '；')
                        Action = "Remove-WcoScheduledTask -TaskPath $(ConvertTo-WcoPsLiteral $t.TaskPath) -TaskName $(ConvertTo-WcoPsLiteral $t.TaskName)"
                    })
            }
        }
    }
    return @($results | Sort-Object Score -Descending)
}

# ---------------------------------------------------------------- 只读审计辅助
function Get-WcoWmiSubscription {
    <#
    只读：列出 root\subscription 下的 WMI 永久事件订阅（__EventFilter、CommandLineEventConsumer、
    ActiveScriptEventConsumer、__FilterToConsumerBinding）。返回 Status：OK / AccessDenied / Failed / Unsupported，
    查询失败时绝不报"干净"。系统自带的 SCM Event Log Filter/Consumer 标为 KnownDefault。
    #>
    $r = [pscustomobject]@{ Status = 'OK'; Message = ''; Items = @() }
    if (-not $script:IsWin) { $r.Status = 'Unsupported'; $r.Message = '仅 Windows'; return $r }
    $classes = @('__EventFilter', 'CommandLineEventConsumer', 'ActiveScriptEventConsumer', '__FilterToConsumerBinding')
    $items = @()
    foreach ($cls in $classes) {
        try {
            $objs = @(Get-CimInstance -Namespace 'root\subscription' -ClassName $cls -ErrorAction Stop)
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match '(?i)denied|拒绝') { $r.Status = 'AccessDenied'; $r.Message = '需管理员，未检查' } else { $r.Status = 'Failed'; $r.Message = "查询 $cls 失败：$msg" }
            return $r
        }
        foreach ($o in $objs) {
            $name = [string](Get-WcoProp $o 'Name')
            $detail = switch ($cls) {
                '__EventFilter' { [string](Get-WcoProp $o 'Query') }
                'CommandLineEventConsumer' { ([string](Get-WcoProp $o 'CommandLineTemplate') + ' ' + [string](Get-WcoProp $o 'ExecutablePath')).Trim() }
                'ActiveScriptEventConsumer' {
                    $txt = [string](Get-WcoProp $o 'ScriptText')
                    if ($txt.Length -gt 120) { $txt = $txt.Substring(0, 120) + '…' }
                    ("[$(Get-WcoProp $o 'ScriptingEngine')] " + [string](Get-WcoProp $o 'ScriptFileName') + ' ' + $txt).Trim()
                }
                '__FilterToConsumerBinding' { "$(Get-WcoProp $o 'Filter') → $(Get-WcoProp $o 'Consumer')" }
            }
            if (-not $name -and $cls -eq '__FilterToConsumerBinding') { $name = '(binding)' }
            $known = ($name -in @('SCM Event Log Filter', 'SCM Event Log Consumer', 'BVTFilter')) -or ($detail -match 'SCM Event Log (Filter|Consumer)')
            $items += [pscustomobject]@{ Class = $cls; Name = $name; Detail = $detail; KnownDefault = $known }
        }
    }
    $r.Items = $items
    return $r
}

function Get-WcoShortcutArgument {
    <#
    只读：检查桌面、开始菜单、任务栏固定的 .lnk 参数，以及桌面 .url 网址图标。
    浏览器快捷方式带网址参数、或用 cmd/wscript 等间接拉起网址的，标 Flag=待核实（PWA 的 --app= 也会被列出，需人工判断）。
    #>
    $out = @()
    if (-not $script:IsWin) { return $out }
    $dirs = @(
        [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('StartMenu'), [Environment]::GetFolderPath('CommonStartMenu'),
        (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    try { $shell = New-Object -ComObject WScript.Shell } catch { return $out }
    $browser = '(?i)\\(chrome|msedge|firefox|iexplore|360se|360chrome|2345explorer|qqbrowser|sogouexplorer|ucbrowser|liebao|maxthon|brave|opera)\.exe$'
    $indirect = '(?i)\\(cmd|wscript|cscript|mshta|rundll32|powershell|explorer)\.exe$'
    $urlArg = '(?i)https?://|www\.|\.(com|cn|net|html?)\b'
    foreach ($d in $dirs) {
        foreach ($f in @(Get-ChildItem -LiteralPath $d -Recurse -Force -Include '*.lnk', '*.url' -ErrorAction SilentlyContinue)) {
            if ($f.Extension -ieq '.url') {
                if ($d -match '(?i)desktop') {
                    $u = (Select-String -LiteralPath $f.FullName -Pattern '^URL=(.*)$' -ErrorAction SilentlyContinue | Select-Object -First 1)
                    $out += [pscustomobject]@{ Path = $f.FullName; Target = ''; Arguments = $(if ($u) { $u.Matches[0].Groups[1].Value } else { '' }); Flag = '桌面网址图标' }
                }
                continue
            }
            try { $lnk = $shell.CreateShortcut($f.FullName) } catch { continue }
            $tgt = [string]$lnk.TargetPath; $arg = [string]$lnk.Arguments
            if (-not $arg) { continue }
            if (($tgt -match $browser -and $arg -match $urlArg) -or ($tgt -match $indirect -and $arg -match $urlArg)) {
                $out += [pscustomobject]@{ Path = $f.FullName; Target = $tgt; Arguments = $arg; Flag = '待核实' }
            }
        }
    }
    return $out
}

function Get-WcoShellExtension {
    <#
    只读：列出右键菜单处理程序与图标覆盖。处理程序键名不是 GUID 时读它的 (default) 得到 CLSID；
    CLSID 依次在 HKCU\Software\Classes\CLSID、HKLM\Software\Classes\CLSID、HKLM\Software\WOW6432Node\Classes\CLSID 解析；
    以实现 DLL 的 Authenticode 签名区分 Microsoft / 第三方，不按名称猜"良性"。
    -BloatPattern 传入 catalog 中的关键词（匹配 DLL 路径或名称）时，命中项 Category=Bloat。
    #>
    param([string[]]$BloatPattern = @())
    $out = @()
    if (-not $script:IsWin) { return $out }
    $locs = @()
    foreach ($cls in @('HKLM\Software\Classes', 'HKCU\Software\Classes', 'HKLM\Software\WOW6432Node\Classes')) {
        foreach ($t in @('*', 'AllFilesystemObjects', 'Folder', 'Directory', 'Directory\Background', 'Drive')) {
            $locs += @{ Loc = "$cls\$t\shellex\ContextMenuHandlers"; Kind = 'ContextMenu' }
        }
    }
    $locs += @{ Loc = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers'; Kind = 'IconOverlay' }
    $locs += @{ Loc = 'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers'; Kind = 'IconOverlay' }
    $sigCache = @{}
    foreach ($l in $locs) {
        foreach ($k in @(Get-ChildItem -LiteralPath (ConvertTo-WcoPsKey $l.Loc) -ErrorAction SilentlyContinue)) {
            $handler = $k.PSChildName
            $clsid = if ($handler -match '^\{[0-9A-Fa-f-]{36}\}$') { $handler } else { [string]$k.GetValue('') }
            $name = $null; $impl = $null
            if ($clsid -match '^\{[0-9A-Fa-f-]{36}\}$') {
                foreach ($base in @('HKCU\Software\Classes\CLSID', 'HKLM\Software\Classes\CLSID', 'HKLM\Software\WOW6432Node\Classes\CLSID')) {
                    $ck = Get-Item -LiteralPath (ConvertTo-WcoPsKey "$base\$clsid") -ErrorAction SilentlyContinue
                    if (-not $ck) { continue }
                    $name = [string]$ck.GetValue('')
                    foreach ($srv in @('InprocServer32', 'LocalServer32')) {
                        $sk = Get-Item -LiteralPath (ConvertTo-WcoPsKey "$base\$clsid\$srv") -ErrorAction SilentlyContinue
                        if ($sk) { $impl = [Environment]::ExpandEnvironmentVariables([string]$sk.GetValue('')); break }
                    }
                    break
                }
            }
            $implPath = Resolve-WcoExecutablePath $impl
            if ($implPath -and -not [IO.Path]::IsPathRooted($implPath) -and $env:SystemRoot) { $implPath = Join-Path $env:SystemRoot "System32\$implPath" }
            $sig = $null
            if ($implPath) {
                if (-not $sigCache.ContainsKey($implPath)) { $sigCache[$implPath] = Get-WcoFileSigner -Path $implPath }
                $sig = $sigCache[$implPath]
            }
            $cat = 'Unknown'
            if ($sig -and $sig.IsMicrosoft) { $cat = 'Microsoft' } elseif ($sig -and $sig.Status -eq 'Valid') { $cat = 'ThirdParty' }
            foreach ($b in $BloatPattern) {
                if (-not $b) { continue }
                $esc = [regex]::Escape($b)
                if ("$implPath" -match $esc -or "$name" -match $esc -or "$handler" -match $esc -or ($sig -and "$($sig.Organization)" -match $esc)) { $cat = 'Bloat'; break }
            }
            $out += [pscustomobject]@{
                Kind = $l.Kind; Location = $l.Loc; Handler = $handler; CLSID = $clsid; Name = $name; Impl = $implPath
                Signer = $(if ($sig) { $sig.Organization } else { $null }); SignatureStatus = $(if ($sig) { $sig.Status } else { 'NoImpl' }); Category = $cat
            }
        }
    }
    return $out
}

function Get-WcoBloatwareCatalog {
    <# 读取 data/bloatware-catalog.json（默认按模块位置找）。 #>
    param([string]$Path = (Join-Path $PSScriptRoot '..\..\data\bloatware-catalog.json'))
    if (-not (Test-Path -LiteralPath $Path)) { throw "找不到 catalog：$Path" }
    $json = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).ProviderPath, [Text.Encoding]::UTF8)
    return ($json | ConvertFrom-Json)
}

Export-ModuleMember -Function Test-WcoAdmin, Start-WcoSession, Get-WcoSession, Import-WcoSession, Add-WcoChange, Export-WcoUndo,
    Measure-WcoDirectory, Get-WcoRecycleBinPolicy, Get-WcoItemSizeMB, Invoke-WcoRecycle,
    Set-WcoServiceStartType, Remove-WcoService, Set-WcoRegistryValue, Remove-WcoRegistryKey, Test-WcoProtectedRegistryKey,
    ConvertTo-WcoStartupApprovedData, ConvertFrom-WcoStartupApprovedData, Get-WcoStartupApproved, Set-WcoStartupApproved, Get-WcoStartupItem,
    Disable-WcoScheduledTask, Remove-WcoScheduledTask,
    Get-WcoInstalledProgram, Invoke-WcoUninstall, Remove-WcoAppxPackage, Find-WcoLeftover, Get-WcoNameMatch,
    Get-WcoFileSigner, Get-WcoWmiSubscription, Get-WcoShortcutArgument, Get-WcoShellExtension, Get-WcoBloatwareCatalog
