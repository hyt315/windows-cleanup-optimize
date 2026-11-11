# 模板 23：audit-browser-hijack（只读，v2.0）
# 排查浏览器主页/搜索/新标签页被策略锁定、强制安装扩展、Native Messaging、快捷方式网址参数、
# 代理、hosts、DNS、近期新增根证书。全程只读：不修改注册表、文件、证书或网络设置。
# 用法：powershell -ExecutionPolicy Bypass -File t23-audit-browser-hijack.ps1 [-OutFile report.txt]
#   -OutFile 仅接受文件名，报告写入 %TEMP%\wco\ 下（唯一的写操作）。

[CmdletBinding()]
param(
    [string]$OutFile
)

$ErrorActionPreference = 'Continue'
$script:Lines = New-Object System.Collections.Generic.List[string]
$script:Attention = New-Object System.Collections.Generic.List[string]
$script:Counts = [ordered]@{}

function Write-Line {
    param([string]$Text, [string]$Color)
    $script:Lines.Add($Text)
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Add-Count {
    param([string]$Section, [int]$N = 1)
    if (-not $script:Counts.Contains($Section)) { $script:Counts[$Section] = 0 }
    $script:Counts[$Section] = $script:Counts[$Section] + $N
}

function Add-Attention {
    param([string]$Text)
    $script:Attention.Add($Text)
}

function Open-RegKey {
    <# 只读打开注册表项。返回 @{ State = 'ok'|'missing'|'denied'|'error'; Key; Error } #>
    param([string]$Path)
    $r = @{ State = 'missing'; Key = $null; Error = '' }
    try {
        $hive = $null
        $sub = $null
        if ($Path -match '^HKLM:\\(.*)$') { $hive = [Microsoft.Win32.Registry]::LocalMachine; $sub = $Matches[1] }
        elseif ($Path -match '^HKCU:\\(.*)$') { $hive = [Microsoft.Win32.Registry]::CurrentUser; $sub = $Matches[1] }
        else { $r.State = 'error'; $r.Error = "不支持的路径：$Path"; return $r }
        $k = $hive.OpenSubKey($sub, $false)
        if ($null -eq $k) { $r.State = 'missing' } else { $r.State = 'ok'; $r.Key = $k }
    } catch [System.Security.SecurityException] {
        $r.State = 'denied'
    } catch [System.UnauthorizedAccessException] {
        $r.State = 'denied'
    } catch {
        $r.State = 'error'; $r.Error = $_.Exception.Message
    }
    return $r
}

function Format-RegValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [array]) { return ($Value -join '; ') }
    $s = [string]$Value
    if ($s.Length -gt 300) { $s = $s.Substring(0, 300) + '…(已截断)' }
    return $s
}

function Get-RegSubKeyValueList {
    <# 读取子项（如 RestoreOnStartupURLs / ExtensionInstallForcelist）下全部值 #>
    param($ParentKey, [string]$SubName)
    $out = @()
    $sk = $ParentKey.OpenSubKey($SubName, $false)
    if ($null -eq $sk) { return $null }
    try {
        foreach ($n in $sk.GetValueNames()) {
            $out += ("{0} = {1}" -f $n, (Format-RegValue $sk.GetValue($n)))
        }
    } finally { $sk.Close() }
    return , $out
}

Write-Line "=== 浏览器劫持只读排查（t23）==="
Write-Line ("时间：{0}  计算机：{1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME)

# === 1. Chrome / Edge 策略 ===
$sec = 'Chrome/Edge 策略'
Write-Line "`n=== 1. Chrome / Edge 组策略（主页 / 启动页 / 新标签页 / 搜索 / 扩展）==="
$policyRoots = @(
    @{ Name = 'Chrome(HKLM)'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome' },
    @{ Name = 'Chrome(HKCU)'; Path = 'HKCU:\SOFTWARE\Policies\Google\Chrome' },
    @{ Name = 'Edge(HKLM)'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' },
    @{ Name = 'Edge(HKCU)'; Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge' }
)
$policyValues = @('HomepageLocation', 'HomepageIsNewTabPage', 'RestoreOnStartup', 'NewTabPageLocation',
    'DefaultSearchProviderEnabled', 'DefaultSearchProviderSearchURL', 'DefaultSearchProviderName', 'ExtensionSettings')
$attentionValues = @('HomepageLocation', 'NewTabPageLocation', 'DefaultSearchProviderSearchURL', 'DefaultSearchProviderName', 'ExtensionSettings')
Add-Count $sec 0
foreach ($root in $policyRoots) {
    try {
        $o = Open-RegKey $root.Path
        if ($o.State -eq 'missing') { Write-Line ("  [{0}] 未设置" -f $root.Name); continue }
        if ($o.State -eq 'denied') { Write-Line ("  [{0}] 需管理员，未检查" -f $root.Name) -Color Yellow; continue }
        if ($o.State -ne 'ok') { Write-Line ("  [{0}] 读取失败：{1}" -f $root.Name, $o.Error) -Color Yellow; continue }
        $k = $o.Key
        try {
            Write-Line ("  [{0}] {1}" -f $root.Name, $root.Path)
            $names = @($k.GetValueNames())
            foreach ($v in $policyValues) {
                if ($names -contains $v) {
                    $val = Format-RegValue $k.GetValue($v)
                    Write-Line ("    {0} = {1}" -f $v, $val) -Color Yellow
                    Add-Count $sec
                    if ($attentionValues -contains $v) { Add-Attention ("{0} 策略 {1} = {2}" -f $root.Name, $v, $val) }
                } else {
                    Write-Line ("    {0}：未设置" -f $v)
                }
            }
            foreach ($subName in @('RestoreOnStartupURLs', 'ExtensionInstallForcelist')) {
                try {
                    $items = Get-RegSubKeyValueList -ParentKey $k -SubName $subName
                    if ($null -eq $items) { Write-Line ("    {0}：未设置" -f $subName); continue }
                    if ($items.Count -eq 0) { Write-Line ("    {0}：子项存在但为空" -f $subName); continue }
                    Write-Line ("    {0}：" -f $subName) -Color Yellow
                    foreach ($i in $items) {
                        Write-Line ("      {0}" -f $i) -Color Yellow
                        Add-Count $sec
                        Add-Attention ("{0} 策略 {1}：{2}" -f $root.Name, $subName, $i)
                    }
                } catch [System.Security.SecurityException] {
                    Write-Line ("    {0}：需管理员，未检查" -f $subName) -Color Yellow
                } catch {
                    Write-Line ("    {0}：读取失败：{1}" -f $subName, $_.Exception.Message) -Color Yellow
                }
            }
        } finally { $k.Close() }
    } catch {
        Write-Line ("  [{0}] 读取失败：{1}" -f $root.Name, $_.Exception.Message) -Color Yellow
    }
}

# === 2. Firefox 策略 ===
$sec = 'Firefox 策略'
Write-Line "`n=== 2. Firefox 企业策略 ==="
Add-Count $sec 0
try {
    $o = Open-RegKey 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox'
    if ($o.State -eq 'missing') { Write-Line "  注册表策略 HKLM\SOFTWARE\Policies\Mozilla\Firefox：未设置" }
    elseif ($o.State -eq 'denied') { Write-Line "  注册表策略：需管理员，未检查" -Color Yellow }
    elseif ($o.State -ne 'ok') { Write-Line ("  注册表策略读取失败：{0}" -f $o.Error) -Color Yellow }
    else {
        try {
            $vn = @($o.Key.GetValueNames())
            $sn = @($o.Key.GetSubKeyNames())
            Write-Line ("  注册表策略存在：{0} 个值，{1} 个子项" -f $vn.Count, $sn.Count) -Color Yellow
            foreach ($n in $vn) { Write-Line ("    {0} = {1}" -f $n, (Format-RegValue $o.Key.GetValue($n))) }
            foreach ($n in $sn) { Write-Line ("    [子项] {0}" -f $n) }
            Add-Count $sec
            Add-Attention 'Firefox 注册表企业策略存在，需人工确认来源'
        } finally { $o.Key.Close() }
    }
} catch {
    Write-Line ("  注册表策略读取失败：{0}" -f $_.Exception.Message) -Color Yellow
}
try {
    $ffDirs = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ } | Select-Object -Unique
    $foundPj = $false
    foreach ($pf in $ffDirs) {
        $pj = Join-Path $pf 'Mozilla Firefox\distribution\policies.json'
        if (Test-Path -LiteralPath $pj) {
            $fi = Get-Item -LiteralPath $pj -ErrorAction SilentlyContinue
            Write-Line ("  policies.json 存在：{0}（修改时间 {1}）" -f $pj, $fi.LastWriteTime) -Color Yellow
            Add-Count $sec
            Add-Attention ("Firefox policies.json 存在：{0}" -f $pj)
            $foundPj = $true
        }
    }
    if (-not $foundPj) { Write-Line "  distribution\policies.json：未设置" }
} catch {
    Write-Line ("  policies.json 检查失败：{0}" -f $_.Exception.Message) -Color Yellow
}

# === 3. Native Messaging Hosts ===
$sec = 'Native Messaging'
Write-Line "`n=== 3. Native Messaging 主机（扩展可调用的本地程序，多为正常软件，仅列出）==="
Add-Count $sec 0
$nmRoots = @(
    'HKCU:\SOFTWARE\Google\Chrome\NativeMessagingHosts',
    'HKLM:\SOFTWARE\Google\Chrome\NativeMessagingHosts',
    'HKCU:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts',
    'HKLM:\SOFTWARE\Microsoft\Edge\NativeMessagingHosts'
)
foreach ($p in $nmRoots) {
    try {
        $o = Open-RegKey $p
        if ($o.State -eq 'missing') { Write-Line ("  {0}：未设置" -f $p); continue }
        if ($o.State -eq 'denied') { Write-Line ("  {0}：需管理员，未检查" -f $p) -Color Yellow; continue }
        if ($o.State -ne 'ok') { Write-Line ("  {0}：读取失败：{1}" -f $p, $o.Error) -Color Yellow; continue }
        try {
            $hosts = @($o.Key.GetSubKeyNames())
            if ($hosts.Count -eq 0) { Write-Line ("  {0}：无" -f $p); continue }
            Write-Line ("  {0}：" -f $p)
            foreach ($h in $hosts) {
                $manifest = ''
                try {
                    $hk = $o.Key.OpenSubKey($h, $false)
                    if ($hk) { $manifest = Format-RegValue $hk.GetValue(''); $hk.Close() }
                } catch { $manifest = '（读取失败）' }
                if (-not $manifest) { $manifest = '（未设置清单路径）' }
                $exists = ''
                if ($manifest -and (Test-Path -LiteralPath $manifest -ErrorAction SilentlyContinue)) { $exists = '' } else { $exists = '  [清单文件不存在]' }
                Write-Line ("    {0} -> {1}{2}" -f $h, $manifest, $exists)
                Add-Count $sec
            }
        } finally { $o.Key.Close() }
    } catch {
        Write-Line ("  {0}：读取失败：{1}" -f $p, $_.Exception.Message) -Color Yellow
    }
}

# === 4. 浏览器快捷方式参数 ===
$sec = '快捷方式网址参数'
Write-Line "`n=== 4. 浏览器快捷方式 (.lnk) 网址参数（桌面 / 开始菜单 / 任务栏固定）==="
Add-Count $sec 0
try {
    $lnkDirs = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('StartMenu'),
        [Environment]::GetFolderPath('CommonStartMenu'),
        (Join-Path ([string]$env:APPDATA) 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch { $shell = $null }
    if ($null -eq $shell) {
        Write-Line "  无法创建 WScript.Shell（非 Windows 或 COM 不可用），未检查" -Color Yellow
    } else {
        $browserExe = '(?i)\\(chrome|msedge|firefox|360se|360chrome|qqbrowser)\.exe$'
        $lnkHit = 0
        foreach ($d in $lnkDirs) {
            foreach ($f in @(Get-ChildItem -LiteralPath $d -Recurse -Force -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
                try {
                    $lnk = $shell.CreateShortcut($f.FullName)
                    if ($lnk.TargetPath -match $browserExe -and $lnk.Arguments -match '(?i)https?://') {
                        Write-Line ("  [待核实] {0}`n      目标：{1}`n      参数：{2}" -f $f.FullName, $lnk.TargetPath, $lnk.Arguments) -Color Red
                        Add-Count $sec
                        Add-Attention ("快捷方式带网址参数：{0} -> {1}" -f $f.FullName, $lnk.Arguments)
                        $lnkHit++
                    }
                } catch {
                    Write-Line ("  读取失败：{0}" -f $f.FullName) -Color Yellow
                }
            }
        }
        if ($lnkHit -eq 0) { Write-Line "  （未发现浏览器快捷方式带 http/https 参数）" }
    }
} catch {
    Write-Line ("  快捷方式检查失败：{0}" -f $_.Exception.Message) -Color Yellow
}

# === 5. 代理 ===
$sec = '代理'
Write-Line "`n=== 5. 代理设置（WinINet / 策略 / WinHTTP）==="
Add-Count $sec 0
$proxyKeys = @(
    @{ Name = 'WinINet(HKCU)'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' },
    @{ Name = 'WinINet 策略(HKLM)'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings' },
    @{ Name = 'WinINet 策略(HKCU)'; Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings' }
)
foreach ($pk in $proxyKeys) {
    try {
        $o = Open-RegKey $pk.Path
        if ($o.State -eq 'missing') { Write-Line ("  [{0}] 未设置" -f $pk.Name); continue }
        if ($o.State -eq 'denied') { Write-Line ("  [{0}] 需管理员，未检查" -f $pk.Name) -Color Yellow; continue }
        if ($o.State -ne 'ok') { Write-Line ("  [{0}] 读取失败：{1}" -f $pk.Name, $o.Error) -Color Yellow; continue }
        try {
            $names = @($o.Key.GetValueNames())
            Write-Line ("  [{0}]" -f $pk.Name)
            foreach ($v in @('ProxyEnable', 'ProxyServer', 'ProxyOverride', 'AutoConfigURL')) {
                if ($names -contains $v) {
                    $val = Format-RegValue $o.Key.GetValue($v)
                    Write-Line ("    {0} = {1}" -f $v, $val)
                    $isOn = ($v -eq 'ProxyEnable' -and $val -eq '1') -or ($v -eq 'AutoConfigURL' -and $val)
                    if ($isOn) {
                        Add-Count $sec
                        Add-Attention ("{0} {1} = {2}" -f $pk.Name, $v, $val)
                    }
                } else {
                    Write-Line ("    {0}：未设置" -f $v)
                }
            }
        } finally { $o.Key.Close() }
    } catch {
        Write-Line ("  [{0}] 读取失败：{1}" -f $pk.Name, $_.Exception.Message) -Color Yellow
    }
}
try {
    if (Get-Command netsh.exe -ErrorAction SilentlyContinue) {
        $wh = @(& netsh.exe winhttp show proxy 2>&1 | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
        Write-Line "  [WinHTTP] netsh winhttp show proxy："
        foreach ($l in $wh) { Write-Line ("    {0}" -f $l.Trim()) }
        $whText = $wh -join ' '
        if ($whText -match '(?i)proxy server\(s\)\s*:' -or $whText -match '代理服务器\s*[:：]') {
            Add-Count $sec
            Add-Attention 'WinHTTP 设置了代理服务器（netsh winhttp show proxy），需人工确认'
        }
    } else {
        Write-Line "  [WinHTTP] netsh 不可用，未检查" -Color Yellow
    }
} catch {
    Write-Line ("  [WinHTTP] 读取失败：{0}" -f $_.Exception.Message) -Color Yellow
}

# === 6. hosts ===
$sec = 'hosts'
Write-Line "`n=== 6. hosts 文件有效条目 ==="
Add-Count $sec 0
try {
    $hostsPath = Join-Path ([string]$env:SystemRoot) 'System32\drivers\etc\hosts'
    if (-not (Test-Path -LiteralPath $hostsPath)) {
        Write-Line ("  {0}：未找到" -f $hostsPath) -Color Yellow
    } else {
        $entries = @(Get-Content -LiteralPath $hostsPath -ErrorAction Stop | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
        if ($entries.Count -eq 0) {
            Write-Line "  （无有效条目，仅注释或空行）"
        } else {
            foreach ($e in $entries) {
                Write-Line ("  {0}" -f $e) -Color Yellow
                Add-Count $sec
            }
            Add-Attention ("hosts 文件有 {0} 条有效条目，需人工确认" -f $entries.Count)
        }
    }
} catch [System.UnauthorizedAccessException] {
    Write-Line "  hosts：需管理员，未检查" -Color Yellow
} catch {
    Write-Line ("  hosts 读取失败：{0}" -f $_.Exception.Message) -Color Yellow
}

# === 7. DNS ===
$sec = 'DNS'
Write-Line "`n=== 7. 各网卡 IPv4 DNS 服务器 ==="
Add-Count $sec 0
try {
    if (Get-Command Get-DnsClientServerAddress -ErrorAction SilentlyContinue) {
        $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ServerAddresses -and $_.ServerAddresses.Count -gt 0 })
        if ($dns.Count -eq 0) { Write-Line "  （没有网卡配置 IPv4 DNS）" }
        foreach ($a in $dns) {
            Write-Line ("  {0}：{1}" -f $a.InterfaceAlias, ($a.ServerAddresses -join ', '))
            Add-Count $sec
        }
    } else {
        Write-Line "  Get-DnsClientServerAddress 不可用（系统缺少 DnsClient 模块），未检查" -Color Yellow
    }
} catch {
    Write-Line ("  DNS 读取失败：{0}" -f $_.Exception.Message) -Color Yellow
}

# === 8. 近期新增根证书 ===
$sec = '近期根证书'
Write-Line "`n=== 8. 近 180 天内生效的受信任根证书 ==="
Add-Count $sec 0
$since = (Get-Date).AddDays(-180)
foreach ($store in @('Cert:\LocalMachine\Root', 'Cert:\CurrentUser\Root')) {
    try {
        if (-not (Test-Path -LiteralPath $store -ErrorAction SilentlyContinue)) {
            Write-Line ("  {0}：证书存储不可用，未检查" -f $store) -Color Yellow
            continue
        }
        $recent = @(Get-ChildItem -LiteralPath $store -ErrorAction Stop | Where-Object { $_.NotBefore -ge $since } | Sort-Object NotBefore -Descending)
        if ($recent.Count -eq 0) { Write-Line ("  {0}：无" -f $store); continue }
        Write-Line ("  {0}：" -f $store)
        foreach ($c in $recent) {
            Write-Line ("    [近期新增，需人工确认] Subject：{0}" -f $c.Subject) -Color Yellow
            Write-Line ("      Issuer：{0}  NotBefore：{1}  Thumbprint：{2}" -f $c.Issuer, $c.NotBefore.ToString('yyyy-MM-dd'), $c.Thumbprint)
            Add-Count $sec
            Add-Attention ("根证书近期新增，需人工确认：{0}（{1}）" -f $c.Subject, $c.Thumbprint)
        }
    } catch [System.UnauthorizedAccessException] {
        Write-Line ("  {0}：需管理员，未检查" -f $store) -Color Yellow
    } catch {
        Write-Line ("  {0}：读取失败：{1}" -f $store, $_.Exception.Message) -Color Yellow
    }
}

# === 汇总 ===
Write-Line "`n=== 汇总 ==="
foreach ($k in $script:Counts.Keys) {
    Write-Line ("  {0}：{1} 项" -f $k, $script:Counts[$k])
}
if ($script:Attention.Count -eq 0) {
    Write-Line "  需关注：无（未发现需人工确认的项目）" -Color Green
} else {
    Write-Line ("  需关注：{0} 项（以下仅为待人工确认，不代表恶意）" -f $script:Attention.Count) -Color Yellow
    foreach ($a in $script:Attention) { Write-Line ("    - {0}" -f $a) -Color Yellow }
}
Write-Line "  本脚本只读，未做任何修改。"

# === 可选：写出报告（仅限 %TEMP%\wco）===
if ($OutFile) {
    try {
        $leaf = Split-Path -Path $OutFile -Leaf
        if (-not $leaf -or $leaf -ne $OutFile) {
            Write-Host "  -OutFile 只接受文件名（不含路径），报告将写入 %TEMP%\wco\" -ForegroundColor Yellow
        }
        $wcoDir = Join-Path ([System.IO.Path]::GetTempPath()) 'wco'
        if (-not (Test-Path -LiteralPath $wcoDir)) { [void][System.IO.Directory]::CreateDirectory($wcoDir) }
        $target = Join-Path $wcoDir $leaf
        $script:Lines | Out-File -LiteralPath $target -Encoding UTF8
        Write-Host ("  报告已写入：{0}" -f $target) -ForegroundColor Green
    } catch {
        Write-Host ("  报告写入失败：{0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}
