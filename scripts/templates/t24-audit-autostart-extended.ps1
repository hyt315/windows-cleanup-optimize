# 模板 24：audit-autostart-extended（v2.1，纯只读）
# 用法：
#   .\t24-audit-autostart-extended.ps1                                   # 只在屏幕输出
#   .\t24-audit-autostart-extended.ps1 -OutFile "$env:TEMP\wco\t24.txt"  # 另存报告（只允许写到 %TEMP%\wco 下）
# 覆盖 16 类自启/持久化位置，详见 references/scan-scripts.md 第 24 节。
# 本模板不修改任何注册表、任务、驱动或文件；每段独立 try/catch，权限不足写"需管理员，未检查"，绝不写"干净"。
# 判读：IFEO、Winlogon、LSA、驱动类发现属于 HIGH，只报告，交给用户和安全软件判断。
param(
    [string]$OutFile
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

if ($env:OS -ne 'Windows_NT') {
    Write-Host '本模板仅支持 Windows。'
    return
}

$script:Lines = New-Object System.Collections.Generic.List[string]
$script:Findings = New-Object System.Collections.Generic.List[object]
$script:SectionState = [ordered]@{}
$script:IsAdmin = Test-WcoAdmin
$script:SignerCache = @{}

# ---------------------------------------------------------------- 输出与记录
function Write-Report {
    param([string]$Text = '', [string]$Color = '')
    $script:Lines.Add($Text)
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Add-Finding {
    <# Level：关注 / 信息 / 未检查 #>
    param([string]$Section, [ValidateSet('关注', '信息', '未检查')][string]$Level, [string]$Item, [string]$Detail)
    $script:Findings.Add([pscustomobject]@{ Section = $Section; Level = $Level; Item = $Item; Detail = $Detail })
    $color = ''
    if ($Level -eq '关注') { $color = 'Red' } elseif ($Level -eq '未检查') { $color = 'Yellow' }
    $line = "  [$Level] $Item"
    if ($Detail) { $line = "$line | $Detail" }
    Write-Report $line $color
}

function Set-SectionState {
    param([string]$Section, [string]$State)
    $script:SectionState[$Section] = $State
}

function Complete-Section {
    <# 根据本段的发现决定段落状态（未显式设置时）。 #>
    param([string]$Section, [string]$EmptyText = '未发现异常项')
    if ($script:SectionState.Contains($Section)) { return }
    $mine = @($script:Findings | Where-Object { $_.Section -eq $Section })
    if (@($mine | Where-Object { $_.Level -eq '未检查' }).Count -gt 0) { Set-SectionState $Section '部分未检查'; return }
    if (@($mine | Where-Object { $_.Level -eq '关注' }).Count -gt 0) { Set-SectionState $Section '有关注项'; return }
    if ($mine.Count -eq 0) { Write-Report "  （$EmptyText）" }
    Set-SectionState $Section '已检查'
}

function Test-AccessDenied {
    param($ErrorRecord)
    if ($null -eq $ErrorRecord) { return $false }
    $ex = $ErrorRecord
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $ex = $ErrorRecord.Exception }
    while ($ex) {
        if ($ex -is [System.UnauthorizedAccessException] -or $ex -is [System.Security.SecurityException]) { return $true }
        if ($ex.Message -match '(?i)denied|拒绝|0x80070005') { return $true }
        $ex = $ex.InnerException
    }
    return $false
}

function Write-SectionError {
    param([string]$Section, $ErrorRecord, [string]$What)
    if (Test-AccessDenied $ErrorRecord) {
        Add-Finding $Section '未检查' $What '需管理员，未检查'
        Set-SectionState $Section '需管理员，未检查'
    } else {
        $msg = [string]$ErrorRecord
        Add-Finding $Section '未检查' $What "查询失败：$msg"
        Set-SectionState $Section "查询失败（不代表干净）"
    }
}

# ---------------------------------------------------------------- 只读注册表
function Get-RegKeySafe {
    <# 返回 Status：OK / Absent / Denied / Error，以及 Key（RegistryKey）。只读。 #>
    param([Parameter(Mandatory)][string]$Path)
    $r = [pscustomobject]@{ Status = 'Absent'; Key = $null; Message = '' }
    try {
        $r.Key = Get-Item -LiteralPath $Path -ErrorAction Stop
        $r.Status = 'OK'
    } catch [System.Management.Automation.ItemNotFoundException] {
        $r.Status = 'Absent'
    } catch {
        if (Test-AccessDenied $_) { $r.Status = 'Denied' } else { $r.Status = 'Error'; $r.Message = [string]$_ }
    }
    return $r
}

function Get-RegRawValue {
    <# 读值时不展开环境变量，保留原文。 #>
    param($Key, [string]$Name)
    if ($null -eq $Key) { return $null }
    return $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}

function ConvertTo-ValueText {
    param($Value)
    if ($null -eq $Value) { return '(未设置)' }
    if ($Value -is [array]) { return (@($Value | ForEach-Object { [string]$_ }) -join ' | ') }
    return [string]$Value
}

# ---------------------------------------------------------------- 路径与签名
function Resolve-TargetPath {
    <# 从命令行里取出可执行文件 / DLL / SYS 路径（去引号、去参数、展开环境变量、处理 \??\ 与 \SystemRoot\）。 #>
    param([string]$CommandLine)
    if (-not $CommandLine) { return $null }
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    $c = $c -replace '^\\\?\?\\', ''
    $c = $c -replace '^(?i)\\SystemRoot\\', ($env:SystemRoot + '\')
    $p = $null
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -gt 1) { $p = $c.Substring(1, $end - 1) }
    } else {
        $m = [regex]::Match($c, '^(.+?\.(exe|dll|sys|com|cpl|ocx|scr|bat|cmd|vbs|js|ps1|lnk))(?=[\s,"]|$)', 'IgnoreCase')
        if ($m.Success) { $p = $m.Groups[1].Value } else { $p = ($c -split '\s+')[0] }
    }
    if (-not $p) { return $null }
    if ($p -match '^(?i)system32\\') { $p = Join-Path $env:SystemRoot $p }
    if ($p -notmatch '\\' -and $p -match '\.') {
        $sys = Join-Path (Join-Path $env:SystemRoot 'System32') $p
        if (Test-Path -LiteralPath $sys -PathType Leaf) { $p = $sys }
    }
    return $p
}

function Get-SignerCached {
    param([string]$Path)
    if (-not $Path) { return (Get-WcoFileSigner -Path '') }
    $k = $Path.ToLowerInvariant()
    if (-not $script:SignerCache.ContainsKey($k)) { $script:SignerCache[$k] = Get-WcoFileSigner -Path $Path }
    return $script:SignerCache[$k]
}

function Get-SignerText {
    param($Signer)
    if ($null -eq $Signer) { return '签名：未知' }
    if ($Signer.Status -eq 'FileNotFound') { return '文件不存在' }
    if ($Signer.Status -eq 'Valid') { return "签名：$($Signer.Organization)" }
    if ($Signer.Status -eq 'NotSigned') { return '未签名' }
    return "签名状态：$($Signer.Status)"
}

function Test-SignerSuspicious {
    <# 文件不存在 / 未签名 / 签名无效 → 需关注。 #>
    param($Signer)
    if ($null -eq $Signer) { return $false }
    return ($Signer.Status -in @('FileNotFound', 'NotSigned', 'HashMismatch', 'NotTrusted', 'UnknownError', 'Incompatible'))
}

function Get-CommandSigner {
    <# 对 rundll32 / regsvr32 / msiexec 等系统宿主，改为检查参数里的 DLL。 #>
    param([string]$CommandLine)
    $exe = Resolve-TargetPath $CommandLine
    $target = $exe
    if ($exe -and ($exe -match '(?i)\\(rundll32|regsvr32|cmd|wscript|cscript|mshta|powershell|msiexec)\.exe$')) {
        $m = [regex]::Match([Environment]::ExpandEnvironmentVariables($CommandLine), '(?i)("?)([a-z]:\\[^"]+?\.(dll|ocx|exe|vbs|js|ps1|hta))\1')
        if ($m.Success -and $m.Groups[2].Value -ne $exe) { $target = $m.Groups[2].Value }
    }
    return [pscustomobject]@{ Path = $target; Signer = (Get-SignerCached $target) }
}

# ================================================================ 1. 登录启动位置
$sec = '1 登录启动位置'
Write-Report "=== $sec（Run / RunOnce / RunOnceEx / WOW6432Node / Policies / 启动文件夹 + StartupApproved）==="
try {
    $probe = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx'
    )
    foreach ($p in $probe) {
        $k = Get-RegKeySafe $p
        if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查' }
        elseif ($k.Status -eq 'Error') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)" }
    }
    $items = @(Get-WcoStartupItem)
    # 模块未覆盖的 HKCU RunOnceEx（子键里的命令）
    $hkcuRox = Get-RegKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx'
    if ($hkcuRox.Status -eq 'OK') {
        foreach ($sub in @(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx' -ErrorAction SilentlyContinue)) {
            foreach ($n in $sub.GetValueNames()) {
                $items += [pscustomobject]@{ Source = 'HKCU-RunOnceEx'; Name = "$($sub.PSChildName)\$n"; Command = [string]$sub.GetValue($n); Approved = 'n/a'; DisabledAt = $null; Location = 'HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnceEx' }
            }
        }
    } elseif ($hkcuRox.Status -eq 'Denied') {
        Add-Finding $sec '未检查' 'HKCU RunOnceEx' '需管理员，未检查'
    }
    foreach ($it in $items) {
        $stateText = switch ($it.Approved) {
            'Enabled' { '启用' }
            'Disabled' { '已禁用' }
            'Absent' { '启用（无 StartupApproved 记录，默认启用）' }
            'Unknown' { '未知状态字节' }
            default { '无开关（该位置不受 StartupApproved 控制）' }
        }
        if ($it.Approved -eq 'Disabled' -and $it.DisabledAt) { $stateText = "$stateText（$($it.DisabledAt.ToString('yyyy-MM-dd HH:mm'))）" }
        $cs = Get-CommandSigner $it.Command
        $level = '信息'
        if ($it.Approved -ne 'Disabled' -and (Test-SignerSuspicious $cs.Signer)) { $level = '关注' }
        if ($it.Source -like '*Policies*') { $level = '关注' }
        Add-Finding $sec $level "[$($it.Source)] $($it.Name)" "$stateText | $($it.Command) | $(Get-SignerText $cs.Signer)"
    }
    Write-Report "  共 $($items.Count) 项（Policies\Explorer\Run 用户在任务管理器里关不掉，出现即标关注）"
} catch {
    Write-SectionError $sec $_ '登录启动位置'
}
Complete-Section $sec

# ================================================================ 2. Winlogon Shell / Userinit
$sec = '2 Winlogon'
Write-Report ''
Write-Report "=== $sec（Shell / Userinit 与默认值对比）==="
try {
    $wlKeys = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; Label = 'HKLM' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Winlogon'; Label = 'HKLM-WOW6432Node' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'; Label = 'HKCU' }
    )
    $sysUserinit = (Join-Path $env:SystemRoot 'system32\userinit.exe').ToLowerInvariant()
    foreach ($w in $wlKeys) {
        $k = Get-RegKeySafe $w.Path
        if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' "$($w.Label) Winlogon" '需管理员，未检查'; continue }
        if ($k.Status -eq 'Error') { Add-Finding $sec '未检查' "$($w.Label) Winlogon" "查询失败：$($k.Message)"; continue }
        if ($k.Status -ne 'OK') { continue }
        $shell = Get-RegRawValue $k.Key 'Shell'
        if ($null -ne $shell) {
            $norm = ([string]$shell).Trim().Trim('"').ToLowerInvariant()
            if ($norm -in @('explorer.exe', (Join-Path $env:SystemRoot 'explorer.exe').ToLowerInvariant())) {
                Write-Report "  $($w.Label) Shell = $shell（默认）"
            } else {
                Add-Finding $sec '关注' "$($w.Label) Shell 偏离默认" "当前：$shell | 默认：explorer.exe"
            }
        } elseif ($w.Label -eq 'HKLM') {
            Add-Finding $sec '关注' 'HKLM Shell 缺失' '默认应为 explorer.exe'
        }
        $ui = Get-RegRawValue $k.Key 'Userinit'
        if ($null -ne $ui) {
            $parts = @(([Environment]::ExpandEnvironmentVariables([string]$ui)) -split ',' | ForEach-Object { $_.Trim().Trim('"').ToLowerInvariant() } | Where-Object { $_ })
            $ok = ($parts.Count -eq 1 -and ($parts[0] -eq $sysUserinit -or $parts[0] -eq 'userinit.exe'))
            if ($ok) {
                Write-Report "  $($w.Label) Userinit = $ui（默认）"
            } else {
                Add-Finding $sec '关注' "$($w.Label) Userinit 偏离默认" "当前：$ui | 默认：C:\Windows\system32\userinit.exe,"
            }
        } elseif ($w.Label -eq 'HKLM') {
            Add-Finding $sec '关注' 'HKLM Userinit 缺失' '默认应为 C:\Windows\system32\userinit.exe,'
        }
    }
} catch {
    Write-SectionError $sec $_ 'Winlogon'
}
Complete-Section $sec '与默认值一致'

# ================================================================ 3. IFEO / SilentProcessExit
$sec = '3 IFEO'
Write-Report ''
Write-Report "=== $sec（映像劫持 Debugger / GlobalFlag 静默退出监控 / SilentProcessExit MonitorProcess）==="
try {
    foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options')) {
        $rk = Get-RegKeySafe $root
        if ($rk.Status -eq 'Denied') { Add-Finding $sec '未检查' $root '需管理员，未检查'; continue }
        if ($rk.Status -ne 'OK') { continue }
        $errs = $null
        $subs = @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue -ErrorVariable errs)
        if ($errs -and @($errs | Where-Object { Test-AccessDenied $_ }).Count -gt 0) { Add-Finding $sec '未检查' "$root 部分子键" '需管理员，未检查' }
        foreach ($s in $subs) {
            $dbg = $s.GetValue('Debugger', $null)
            if ($null -ne $dbg -and [string]$dbg -ne '') { Add-Finding $sec '关注' "Debugger: $($s.PSChildName)" "$dbg" }
            $gf = $s.GetValue('GlobalFlag', $null)
            if ($null -ne $gf) {
                $gfn = 0
                try { $gfn = [int64]$gf } catch { $gfn = 0 }
                if (($gfn -band 0x200) -ne 0) { Add-Finding $sec '关注' "GlobalFlag 含 0x200（静默退出监控）: $($s.PSChildName)" ('0x{0:X}' -f $gfn) }
            }
        }
    }
    $spe = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit'
    $sk = Get-RegKeySafe $spe
    if ($sk.Status -eq 'Denied') { Add-Finding $sec '未检查' $spe '需管理员，未检查' }
    elseif ($sk.Status -eq 'OK') {
        foreach ($s in @(Get-ChildItem -LiteralPath $spe -ErrorAction SilentlyContinue)) {
            $mp = $s.GetValue('MonitorProcess', $null)
            if ($null -ne $mp -and [string]$mp -ne '') { Add-Finding $sec '关注' "SilentProcessExit: $($s.PSChildName)" "MonitorProcess = $mp" }
        }
    }
} catch {
    Write-SectionError $sec $_ 'IFEO'
}
Complete-Section $sec '没有 Debugger / MonitorProcess'

# ================================================================ 4. AppInit_DLLs
$sec = '4 AppInit_DLLs'
Write-Report ''
Write-Report "=== $sec（64 位与 32 位视图）==="
try {
    foreach ($p in @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows')) {
        $k = Get-RegKeySafe $p
        if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查'; continue }
        if ($k.Status -eq 'Error') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)"; continue }
        if ($k.Status -ne 'OK') { continue }
        $view = '64 位'
        if ($p -match 'WOW6432Node') { $view = '32 位' }
        $dlls = [string](Get-RegRawValue $k.Key 'AppInit_DLLs')
        $load = Get-RegRawValue $k.Key 'LoadAppInit_DLLs'
        $loadText = ConvertTo-ValueText $load
        if ($dlls.Trim()) {
            $lvl = '信息'
            if ("$load" -eq '1') { $lvl = '关注' }
            Add-Finding $sec $lvl "$view AppInit_DLLs" "$dlls | LoadAppInit_DLLs = $loadText"
        } else {
            Write-Report "  $view AppInit_DLLs 为空 | LoadAppInit_DLLs = $loadText"
        }
    }
} catch {
    Write-SectionError $sec $_ 'AppInit_DLLs'
}
Complete-Section $sec 'AppInit_DLLs 为空'

# ================================================================ 5. 文件关联打开命令
$sec = '5 文件关联'
Write-Report ''
Write-Report "=== $sec（exefile / batfile / cmdfile / comfile / htmlfile 的 shell\open\command）==="
try {
    $assoc = @('exefile', 'batfile', 'cmdfile', 'comfile', 'htmlfile')
    foreach ($a in $assoc) {
        foreach ($hive in @(@{ Root = 'HKLM:\SOFTWARE\Classes'; Label = 'HKLM' }, @{ Root = 'HKCU:\Software\Classes'; Label = 'HKCU' })) {
            $p = "$($hive.Root)\$a\shell\open\command"
            $k = Get-RegKeySafe $p
            if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' "$($hive.Label) $a" '需管理员，未检查'; continue }
            if ($k.Status -eq 'Error') { Add-Finding $sec '未检查' "$($hive.Label) $a" "查询失败：$($k.Message)"; continue }
            if ($k.Status -ne 'OK') { continue }
            $v = [string](Get-RegRawValue $k.Key '')
            $de = Get-RegRawValue $k.Key 'DelegateExecute'
            if ($hive.Label -eq 'HKCU') {
                Add-Finding $sec '关注' "HKCU 覆盖了 $a 打开命令" "$v（用户级覆盖优先于系统默认）"
                continue
            }
            $norm = ($v -replace '\s+', ' ').Trim()
            if ($a -eq 'htmlfile') {
                if ($norm -match '(?i)^"?[^"]*\\(iexplore|msedge)\.exe"?\s*(%1|"%1")?' -or $norm -eq '') {
                    Write-Report "  $a = $v（系统浏览器，正常）"
                } else {
                    Add-Finding $sec '关注' "$a 打开命令非默认" "当前：$v | 默认：iexplore.exe/msedge.exe %1"
                }
            } elseif ($norm -eq '"%1" %*') {
                Write-Report "  $a = $v（默认）"
            } else {
                Add-Finding $sec '关注' "$a 打开命令偏离默认" "当前：$v | 默认：`"%1`" %*"
            }
            if ($null -ne $de -and [string]$de -ne '') { Add-Finding $sec '关注' "$a 设置了 DelegateExecute" "$de" }
        }
    }
} catch {
    Write-SectionError $sec $_ '文件关联'
}
Complete-Section $sec '与默认一致'

# ================================================================ 6. Active Setup
$sec = '6 Active Setup'
Write-Report ''
Write-Report "=== $sec（HKLM Installed Components 的 StubPath，只列非微软）==="
try {
    $asCount = 0
    foreach ($root in @('HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components')) {
        $rk = Get-RegKeySafe $root
        if ($rk.Status -eq 'Denied') { Add-Finding $sec '未检查' $root '需管理员，未检查'; continue }
        if ($rk.Status -ne 'OK') { continue }
        foreach ($s in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $stub = [string]$s.GetValue('StubPath', $null)
            if (-not $stub.Trim()) { continue }
            $asCount++
            $cs = Get-CommandSigner $stub
            if ($cs.Signer.IsMicrosoft) { continue }
            $name = [string]$s.GetValue('', $null)
            if (-not $name) { $name = $s.PSChildName }
            $lvl = '信息'
            if (Test-SignerSuspicious $cs.Signer) { $lvl = '关注' }
            Add-Finding $sec $lvl "$name $($s.PSChildName)" "$stub | $(Get-SignerText $cs.Signer)"
        }
    }
    Write-Report "  含 StubPath 的组件共 $asCount 个（微软签名的未列出）"
} catch {
    Write-SectionError $sec $_ 'Active Setup'
}
Complete-Section $sec '没有非微软 StubPath'

# ================================================================ 7. BootExecute
$sec = '7 BootExecute'
Write-Report ''
Write-Report "=== $sec（默认 autocheck autochk *）==="
try {
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $k = Get-RegKeySafe $p
    if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查' }
    elseif ($k.Status -ne 'OK') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)" }
    else {
        foreach ($vn in @('BootExecute', 'BootExecuteNoPnpSync', 'SetupExecute', 'Execute', 'S0InitialCommand')) {
            $v = Get-RegRawValue $k.Key $vn
            if ($null -eq $v) { continue }
            $entries = @(@($v) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
            foreach ($e in $entries) {
                if ($vn -eq 'BootExecute' -and (($e -replace '\s+', ' ') -ieq 'autocheck autochk *')) {
                    Write-Report "  $vn = $e（默认）"
                } else {
                    Add-Finding $sec '关注' "$vn 非默认项" $e
                }
            }
        }
    }
} catch {
    Write-SectionError $sec $_ 'BootExecute'
}
Complete-Section $sec '与默认一致'

# ================================================================ 8. LSA 包
$sec = '8 LSA 包'
Write-Report ''
Write-Report "=== $sec（Security / Authentication / Notification Packages）==="
try {
    $known = @{
        'Security Packages'       = @('', '""', 'kerberos', 'msv1_0', 'schannel', 'wdigest', 'tspkg', 'pku2u', 'cloudap', 'negoexts', 'livessp', 'credssp', 'negotiate')
        'Authentication Packages' = @('msv1_0')
        'Notification Packages'   = @('scecli', 'rassfm')
    }
    foreach ($p in @('HKLM:\SYSTEM\CurrentControlSet\Control\Lsa', 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig')) {
        $k = Get-RegKeySafe $p
        if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查'; continue }
        if ($k.Status -eq 'Error') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)"; continue }
        if ($k.Status -ne 'OK') { continue }
        foreach ($vn in $known.Keys) {
            $v = Get-RegRawValue $k.Key $vn
            if ($null -eq $v) { continue }
            $vals = @(@($v) | ForEach-Object { ([string]$_).Trim() })
            Write-Report "  $($p -replace '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\', '') $vn = $($vals -join ', ')"
            foreach ($x in $vals) {
                if ($x.ToLowerInvariant() -notin $known[$vn]) {
                    $dll = Join-Path (Join-Path $env:SystemRoot 'System32') ($x + '.dll')
                    Add-Finding $sec '关注' "$vn 未知包：$x" "$(Get-SignerText (Get-SignerCached $dll))（$dll）"
                }
            }
        }
    }
} catch {
    Write-SectionError $sec $_ 'LSA'
}
Complete-Section $sec '均为已知默认包'

# ================================================================ 9. 打印监视器
$sec = '9 打印监视器'
Write-Report ''
Write-Report "=== $sec（Print\Monitors 的 Driver 不在默认集合中的）==="
try {
    $defaultMon = @('localspl.dll', 'tcpmon.dll', 'usbmon.dll', 'wsdmon.dll', 'apmon.dll', 'appmon.dll', 'fxsmon.dll', 'mspmon.dll')
    $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors'
    $rk = Get-RegKeySafe $root
    if ($rk.Status -eq 'Denied') { Add-Finding $sec '未检查' $root '需管理员，未检查' }
    elseif ($rk.Status -ne 'OK') { Add-Finding $sec '未检查' $root "查询失败：$($rk.Message)" }
    else {
        foreach ($s in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $drv = [string]$s.GetValue('Driver', $null)
            if (-not $drv) { continue }
            if ((Split-Path $drv -Leaf).ToLowerInvariant() -in $defaultMon) { continue }
            $path = $drv
            if ($drv -notmatch '\\') { $path = Join-Path (Join-Path $env:SystemRoot 'System32') $drv }
            $sg = Get-SignerCached $path
            $lvl = '关注'
            if ($sg.IsMicrosoft) { $lvl = '信息' }
            Add-Finding $sec $lvl "$($s.PSChildName)" "Driver = $drv | $(Get-SignerText $sg)"
        }
    }
} catch {
    Write-SectionError $sec $_ '打印监视器'
}
Complete-Section $sec '只有默认监视器'

# ================================================================ 10. Winsock 目录
$sec = '10 Winsock'
Write-Report ''
Write-Report "=== $sec（netsh winsock show catalog 中不在 %SystemRoot% 下的提供程序）==="
try {
    $out = @(& netsh.exe winsock show catalog 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $txt = ($out | ForEach-Object { [string]$_ }) -join ' '
        if ($txt -match '(?i)denied|拒绝|elevat|提升') { Add-Finding $sec '未检查' 'netsh winsock' '需管理员，未检查'; Set-SectionState $sec '需管理员，未检查' }
        else { Add-Finding $sec '未检查' 'netsh winsock' "查询失败（退出码 $LASTEXITCODE）"; Set-SectionState $sec '查询失败（不代表干净）' }
    } else {
        $desc = ''
        $paths = @{}
        foreach ($line in $out) {
            $l = [string]$line
            $md = [regex]::Match($l, '^\s*(Description|描述)\s*[:：]\s*(.+)$', 'IgnoreCase')
            if ($md.Success) { $desc = $md.Groups[2].Value.Trim(); continue }
            $mp = [regex]::Match($l, '^\s*(Provider Path|提供程序路径)\s*[:：]\s*(.+)$', 'IgnoreCase')
            if ($mp.Success) {
                $raw = $mp.Groups[2].Value.Trim()
                if (-not $paths.ContainsKey($raw)) { $paths[$raw] = $desc }
            }
        }
        if ($paths.Count -eq 0) {
            Add-Finding $sec '未检查' 'netsh winsock' '输出中没有解析到"Provider Path/提供程序路径"（可能是其他语言系统），未检查'
        }
        foreach ($raw in $paths.Keys) {
            $exp = [Environment]::ExpandEnvironmentVariables($raw)
            if ($exp.StartsWith($env:SystemRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $sg = Get-SignerCached $exp
            Add-Finding $sec '关注' "非系统目录提供程序：$($paths[$raw])" "$raw | $(Get-SignerText $sg)"
        }
        Write-Report "  提供程序路径共 $($paths.Count) 个（去重）"
    }
} catch {
    Write-SectionError $sec $_ 'Winsock'
}
Complete-Section $sec '所有提供程序都在 %SystemRoot% 下'

# ================================================================ 11. 计划任务
$sec = '11 计划任务'
Write-Report ''
Write-Report "=== $sec（非 \Microsoft\ 任务，按上次运行时间倒序；以及疑似隐藏任务）==="
$allTasks = @()
try {
    $allTasks = @(Get-ScheduledTask -ErrorAction Stop)
    $rows = @()
    foreach ($t in @($allTasks | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
        $last = $null
        try {
            $info = Get-ScheduledTaskInfo -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop
            if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $last = $info.LastRunTime }
        } catch { $last = $null }
        $acts = @()
        foreach ($a in @($t.Actions)) {
            if ($null -eq $a) { continue }
            $exe = [string](Get-WcoProp $a 'Execute')
            if ($exe) { $acts += ("$exe " + [string](Get-WcoProp $a 'Arguments')).Trim() }
            else { $acts += "COM: $([string](Get-WcoProp $a 'ClassId'))" }
        }
        $trs = @()
        foreach ($tr in @($t.Triggers)) {
            if ($null -eq $tr) { continue }
            $cn = [string]$tr.CimClass.CimClassName
            $trs += ($cn -replace '^MSFT_Task', '' -replace 'Trigger$', '')
        }
        $rows += [pscustomobject]@{ Task = $t; LastRun = $last; Actions = ($acts -join ' ; '); Triggers = (($trs | Select-Object -Unique) -join ',') }
    }
    $rows = @($rows | Sort-Object -Property @{ Expression = { if ($_.LastRun) { $_.LastRun } else { [datetime]::MinValue } }; Descending = $true })
    foreach ($r in $rows) {
        $lastText = '从未'
        if ($r.LastRun) { $lastText = $r.LastRun.ToString('yyyy-MM-dd HH:mm') }
        $trText = $r.Triggers
        if (-not $trText) { $trText = '无触发器' }
        $lvl = '信息'
        if ($r.Task.State -ne 'Disabled' -and $r.Triggers -match 'Logon|Boot|Idle|SessionStateChange') { $lvl = '关注' }
        Add-Finding $sec $lvl "$($r.Task.TaskPath)$($r.Task.TaskName)" "状态：$($r.Task.State) | 触发：$trText | 上次：$lastText | 执行：$($r.Actions)"
    }
    Write-Report "  非微软任务共 $($rows.Count) 个（登录/开机/空闲/会话切换触发且未禁用的标关注）"
} catch {
    Write-SectionError $sec $_ 'Get-ScheduledTask'
}
try {
    $tree = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree'
    $tk = Get-RegKeySafe $tree
    if ($tk.Status -eq 'Denied') {
        Add-Finding $sec '未检查' '疑似隐藏任务（TaskCache\Tree）' '需管理员，未检查'
    } elseif ($tk.Status -ne 'OK') {
        Add-Finding $sec '未检查' '疑似隐藏任务（TaskCache\Tree）' "查询失败：$($tk.Message)"
    } else {
        $seen = @{}
        foreach ($t in $allTasks) { $seen[("$($t.TaskPath)$($t.TaskName)").ToLowerInvariant()] = $true }
        $errs = $null
        $keys = @(Get-ChildItem -LiteralPath $tree -Recurse -ErrorAction SilentlyContinue -ErrorVariable errs)
        if ($errs -and @($errs | Where-Object { Test-AccessDenied $_ }).Count -gt 0) {
            Add-Finding $sec '未检查' 'TaskCache\Tree 部分子键' '需管理员/SYSTEM，未检查'
        }
        $hidden = 0
        foreach ($k in $keys) {
            if ($null -eq $k.GetValue('Id', $null)) { continue }
            $idx = $k.Name.IndexOf('\Tree\', [StringComparison]::OrdinalIgnoreCase)
            if ($idx -lt 0) { continue }
            $rel = $k.Name.Substring($idx + 5)
            $noSd = ($null -eq $k.GetValue('SD', $null))
            if ($noSd) {
                $hidden++
                Add-Finding $sec '关注' "疑似隐藏任务（SD 值缺失）：$rel" '任务安全描述符被删除是隐藏任务的典型手法'
            } elseif ($allTasks.Count -gt 0 -and -not $seen.ContainsKey($rel.ToLowerInvariant())) {
                $hidden++
                if ($script:IsAdmin) {
                    Add-Finding $sec '关注' "疑似隐藏任务：$rel" '注册表里有，Get-ScheduledTask 看不到'
                } else {
                    Add-Finding $sec '信息' "疑似隐藏任务：$rel" '注册表里有，Get-ScheduledTask 看不到（非管理员会话，可能只是没有权限查看；需管理员/SYSTEM 复核）'
                }
            }
        }
        Write-Report "  TaskCache\Tree 中的任务 $(@($keys | Where-Object { $null -ne $_.GetValue('Id', $null) }).Count) 个，疑似隐藏 $hidden 个"
    }
} catch {
    Write-SectionError $sec $_ '疑似隐藏任务'
}
Complete-Section $sec '没有非微软任务'

# ================================================================ 12. WMI 事件订阅
$sec = '12 WMI 订阅'
Write-Report ''
Write-Report "=== $sec（root\subscription：__EventFilter / CommandLine / ActiveScript 消费者 / 绑定）==="
try {
    $wmi = Get-WcoWmiSubscription
    if ($wmi.Status -eq 'AccessDenied') {
        Add-Finding $sec '未检查' 'root\subscription' '需管理员，未检查'
        Set-SectionState $sec '需管理员，未检查'
    } elseif ($wmi.Status -ne 'OK') {
        Add-Finding $sec '未检查' 'root\subscription' "查询失败：$($wmi.Message)（不代表干净）"
        Set-SectionState $sec '查询失败（不代表干净）'
    } else {
        foreach ($i in @($wmi.Items)) {
            if ($i.KnownDefault) { Write-Report "  [系统默认] $($i.Class) $($i.Name)"; continue }
            $lvl = '关注'
            if ($i.Class -eq '__EventFilter') { $lvl = '信息' }
            Add-Finding $sec $lvl "$($i.Class): $($i.Name)" $i.Detail
        }
    }
} catch {
    Write-SectionError $sec $_ 'WMI 订阅'
}
Complete-Section $sec '查询成功，没有第三方 WMI 订阅'

# ================================================================ 13. 非微软驱动
$sec = '13 驱动'
Write-Report ''
Write-Report "=== $sec（运行中的内核/文件系统筛选驱动，非微软签名的）==="
try {
    $drivers = @(Get-CimInstance -ClassName Win32_SystemDriver -Filter "State='Running'" -ErrorAction Stop)
    $nonMs = 0
    foreach ($d in $drivers) {
        $path = Resolve-TargetPath ([string]$d.PathName)
        $sg = Get-SignerCached $path
        if ($sg.IsMicrosoft) { continue }
        $nonMs++
        $lvl = '信息'
        if ($sg.Status -ne 'Valid') { $lvl = '关注' }
        Add-Finding $sec $lvl "$($d.Name)（$($d.ServiceType)）" "$path | $(Get-SignerText $sg)"
    }
    Write-Report "  运行中驱动 $($drivers.Count) 个，非微软签名 $nonMs 个（未签名/签名无效/文件缺失的标关注）"
} catch {
    Write-SectionError $sec $_ 'Win32_SystemDriver'
}
Complete-Section $sec '运行中的驱动均为微软签名'

# ================================================================ 14. Win11 重新启动应用
$sec = '14 RestartApps'
Write-Report ''
Write-Report "=== $sec（设置 › 账户 › 登录选项 › 自动保存可重启的应用）==="
try {
    $p = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $k = Get-RegKeySafe $p
    if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查' }
    elseif ($k.Status -eq 'Error') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)" }
    else {
        $v = $null
        if ($k.Status -eq 'OK') { $v = Get-RegRawValue $k.Key 'RestartApps' }
        if ("$v" -eq '1') { Add-Finding $sec '信息' 'RestartApps = 1（开启）' '登录后会自动重新打开上次未关闭的应用' }
        elseif ($null -eq $v) { Write-Report '  RestartApps 未设置（关闭，系统默认）' }
        else { Write-Report "  RestartApps = $v（关闭）" }
    }
} catch {
    Write-SectionError $sec $_ 'RestartApps'
}
Complete-Section $sec '未开启'

# ================================================================ 15. Edge 启动加速 / 后台运行策略
$sec = '15 Edge 策略'
Write-Report ''
Write-Report "=== $sec（Policies\Microsoft\Edge：StartupBoostEnabled / BackgroundModeEnabled）==="
try {
    foreach ($p in @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'HKCU:\SOFTWARE\Policies\Microsoft\Edge')) {
        $k = Get-RegKeySafe $p
        $hive = $p.Substring(0, 4)
        if ($k.Status -eq 'Denied') { Add-Finding $sec '未检查' $p '需管理员，未检查'; continue }
        if ($k.Status -eq 'Error') { Add-Finding $sec '未检查' $p "查询失败：$($k.Message)"; continue }
        foreach ($vn in @('StartupBoostEnabled', 'BackgroundModeEnabled')) {
            $v = $null
            if ($k.Status -eq 'OK') { $v = Get-RegRawValue $k.Key $vn }
            if ($null -eq $v) { Write-Report "  $hive $vn 未配置策略（由 Edge 设置决定）" }
            elseif ("$v" -eq '1') { Add-Finding $sec '信息' "$hive $vn = 1（策略强制开启）" '用户在 Edge 设置里关不掉' }
            else { Write-Report "  $hive $vn = $v（策略关闭）" }
        }
    }
} catch {
    Write-SectionError $sec $_ 'Edge 策略'
}
Complete-Section $sec '没有强制开启的策略'

# ================================================================ 16. 商店应用 StartupTask（尽力而为）
$sec = '16 商店应用 StartupTask'
Write-Report ''
Write-Report "=== $sec（尽力而为：读当前用户包的 AppxManifest.xml 中 windows.startupTask）==="
try {
    $pkgs = @(Get-AppxPackage -ErrorAction Stop)
    $stateMap = @{ 0 = '已禁用'; 1 = '已禁用（用户）'; 2 = '启用'; 3 = '已禁用（策略）'; 4 = '启用（策略）' }
    $n = 0
    foreach ($pkg in $pkgs) {
        if (-not $pkg.InstallLocation) { continue }
        $mf = Join-Path $pkg.InstallLocation 'AppxManifest.xml'
        if (-not (Test-Path -LiteralPath $mf -PathType Leaf)) { continue }
        $raw = $null
        try { $raw = [IO.File]::ReadAllText($mf) } catch { continue }
        if ($raw -notmatch '(?i)windows\.startupTask') { continue }
        $xml = $null
        try { $xml = [xml]$raw } catch { continue }
        foreach ($node in @($xml.SelectNodes("//*[local-name()='StartupTask']"))) {
            $taskId = $node.GetAttribute('TaskId')
            $enabledAttr = $node.GetAttribute('Enabled')
            $dn = $node.GetAttribute('DisplayName')
            $ext = $node.ParentNode
            $exe = ''
            if ($ext) { $exe = $ext.GetAttribute('Executable') }
            $state = "未设置（清单默认 Enabled=$enabledAttr）"
            $sp = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($pkg.PackageFamilyName)\$taskId"
            $sk = Get-RegKeySafe $sp
            if ($sk.Status -eq 'OK') {
                $sv = $sk.Key.GetValue('State', $null)
                if ($null -ne $sv) {
                    $svi = [int]$sv
                    if ($stateMap.ContainsKey($svi)) { $state = $stateMap[$svi] } else { $state = "State=$svi" }
                }
            }
            $n++
            Add-Finding $sec '信息' "$($pkg.Name) / $taskId" "状态：$state | $dn | $exe"
        }
    }
    Write-Report "  共 $n 个 StartupTask（尽力而为：仅当前用户，状态以 设置 › 应用 › 启动 为准）"
} catch {
    Write-SectionError $sec $_ 'Get-AppxPackage（PowerShell 7 下可能需在 Windows PowerShell 5.1 中运行）'
}
Complete-Section $sec '没有声明 StartupTask 的商店应用'

# ================================================================ 汇总
Write-Report ''
Write-Report '=== 汇总 ==='
$adminText = '否（部分 HKLM/任务/驱动检查可能不完整）'
if ($script:IsAdmin) { $adminText = '是' }
Write-Report "管理员会话：$adminText"
$attention = @($script:Findings | Where-Object { $_.Level -eq '关注' })
$infoCount = @($script:Findings | Where-Object { $_.Level -eq '信息' }).Count
$unchecked = @($script:Findings | Where-Object { $_.Level -eq '未检查' })
Write-Report ("关注 {0} 项 | 信息 {1} 项 | 未检查 {2} 处" -f $attention.Count, $infoCount, $unchecked.Count)
foreach ($s in $script:SectionState.Keys) {
    $c = @($script:Findings | Where-Object { $_.Section -eq $s -and $_.Level -eq '关注' }).Count
    Write-Report ("  {0,-22} {1}（关注 {2}）" -f $s, $script:SectionState[$s], $c)
}
if ($attention.Count -gt 0) {
    Write-Report ''
    Write-Report '需要关注的项（只报告，不自动修改；IFEO / Winlogon / LSA / 驱动类属 HIGH，交给用户和安全软件判断）：' 'Red'
    foreach ($f in $attention) { Write-Report "  [$($f.Section)] $($f.Item) | $($f.Detail)" 'Red' }
}
if ($unchecked.Count -gt 0) {
    Write-Report ''
    Write-Report '未检查的位置（不代表干净，建议以管理员身份重跑）：' 'Yellow'
    foreach ($f in $unchecked) { Write-Report "  [$($f.Section)] $($f.Item) | $($f.Detail)" 'Yellow' }
}

# ================================================================ 可选：保存报告（仅限 %TEMP%\wco）
if ($OutFile) {
    $allowed = [IO.Path]::GetFullPath((Join-Path $env:TEMP 'wco'))
    $full = [IO.Path]::GetFullPath($OutFile)
    if (-not $full.StartsWith($allowed.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "拒绝写入：-OutFile 只允许 $allowed 下的路径" -ForegroundColor Yellow
    } else {
        $dir = Split-Path $full -Parent
        if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
        $script:Lines | Out-File -FilePath $full -Encoding UTF8
        Write-Host "报告已保存：$full"
    }
}
