# 模板 25：inventory-programs（只读，v2.1）
# 盘点已安装程序（HKLM、HKLM\WOW6432Node、HKCU 卸载项）和非框架、非系统的商店应用（Appx），
# 以及正在运行的进程、服务、计划任务、内核驱动的名称，逐项对照 data/bloatware-catalog.json。
# 置信度：签名者 / 发行主体命中 = 高；进程 / 服务 / 计划任务 / 驱动 / Appx 命中 = 中；
#         只有显示名相似 = 低（疑似，需人工确认；≤4 个字符的名称不做模糊匹配）。
#         目录里 confidence=low 的家族，命中一律按"低"报告（需实机确认）。
# 目录里没有、发行主体又不是 Microsoft 的程序列为"未知第三方"，不给任何处置建议。
# 全程只读：不卸载、不结束进程、不改注册表/服务/任务。唯一的写操作是 -OutFile（只写到 %TEMP%\wco\ 下）。
# 用法：
#   powershell -ExecutionPolicy Bypass -File t25-inventory-programs.ps1
#   .\t25-inventory-programs.ps1 -Json                       # 输出 JSON（便于前后对比"卸了又回来"）
#   .\t25-inventory-programs.ps1 -OutFile inventory.txt      # 同时把报告写到 %TEMP%\wco\inventory.txt
#   .\t25-inventory-programs.ps1 -NoSignature                # 跳过 Authenticode 读取（更快，但没有"高"级签名证据）

[CmdletBinding()]
param(
    [string]$CatalogPath,
    [switch]$Json,
    [string]$OutFile,
    [switch]$NoSignature
)

$ErrorActionPreference = 'Continue'
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

$script:Lines = New-Object System.Collections.Generic.List[string]
function Write-Line {
    param([string]$Text, [string]$Color)
    $script:Lines.Add($Text)
    if ($Json) { return }
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Get-ListProp {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return @() }
    $p = $Obj.PSObject.Properties[$Name]
    if (-not $p -or $null -eq $p.Value) { return @() }
    return @($p.Value | Where-Object { $_ } | ForEach-Object { [string]$_ })
}

function Get-StrProp {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return '' }
    $p = $Obj.PSObject.Properties[$Name]
    if (-not $p -or $null -eq $p.Value) { return '' }
    return [string]$p.Value
}

function Test-IdMatch {
    # 标识可含通配符 * ?；不含时按完全相等（不区分大小写）
    param([string]$Value, [string[]]$Patterns)
    if (-not $Value) { return $null }
    foreach ($pat in $Patterns) {
        if (-not $pat) { continue }
        if ($pat.Contains('*') -or $pat.Contains('?')) { if ($Value -like $pat) { return $pat } }
        elseif ($Value -eq $pat) { return $pat }
    }
    return $null
}

function Test-OrgMatch {
    # 签名者 / 发行主体：规范化后完全一致（Get-WcoNameMatch = Exact）才算命中
    param([string]$Value, [string[]]$Targets)
    if (-not $Value) { return $null }
    foreach ($t in $Targets) {
        if (-not $t) { continue }
        if ((Get-WcoNameMatch -Candidate $Value -Target $t) -eq 'Exact') { return $t }
    }
    return $null
}

function Test-MicrosoftName {
    param([string]$Text)
    return ($Text -match '^\s*(CN=)?Microsoft( Corporation| Corp\.?|\s|,|$)')
}

function Get-ExeBaseName {
    param([string]$Path)
    if (-not $Path) { return '' }
    $leaf = ($Path -split '[\\/]')[-1]
    return ($leaf -replace '(?i)\.(exe|sys|dll)$', '')
}

function Get-ExeFromCommandLine {
    # 从 PathName / Execute 里取出可执行文件路径（只做字符串解析，不执行）
    param([string]$CommandLine)
    if (-not $CommandLine) { return '' }
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    $c = $c -replace '^\\\?\?\\', ''
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        if ($end -gt 1) { return $c.Substring(1, $end - 1) }
        return ''
    }
    $m = [regex]::Match($c, '^(.+?\.(exe|sys|dll))(?=[\s,]|$)', 'IgnoreCase')
    if ($m.Success) {
        $p = $m.Groups[1].Value
        if ($p -match '^(?i)\\SystemRoot\\') { $p = $p -replace '^(?i)\\SystemRoot', $env:SystemRoot }
        return $p
    }
    return ($c -split '\s+')[0]
}

function Test-UnderPath {
    param([string]$Child, [string]$Parent)
    if (-not $Child -or -not $Parent) { return $false }
    $c = $Child.Replace('/', '\').TrimEnd('\') + '\'
    $p = $Parent.Replace('/', '\').Trim('"').TrimEnd('\') + '\'
    if ($p.Length -le 4) { return $false }   # 不把 C:\ 这类根目录当作安装目录
    return $c.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)
}

$script:SigCache = @{}
function Get-CachedSigner {
    param([string]$Path)
    if ($NoSignature -or -not $Path) { return $null }
    $k = $Path.ToLowerInvariant()
    if (-not $script:SigCache.ContainsKey($k)) { $script:SigCache[$k] = Get-WcoFileSigner -Path $Path }
    return $script:SigCache[$k]
}

function ConvertTo-PsQuoted {
    param([string]$Text)
    return "'" + ([string]$Text).Replace("'", "''") + "'"
}

$rank = @{ '高' = 3; '中' = 2; '低' = 1 }
# 目录名里过于宽泛、不适合作名称比对的末级目录
$genericLeaf = @('360', 'Tencent', 'Kingsoft', 'Baidu', 'Programs', 'Desktop', 'office6', 'Total Security', 'Foxit Software', 'KSafe', 'Thunder')

# === 载入目录 ===
try {
    $cat = if ($CatalogPath) { Get-WcoBloatwareCatalog -Path $CatalogPath } else { Get-WcoBloatwareCatalog }
} catch {
    Write-Host "无法读取 data/bloatware-catalog.json：$($_.Exception.Message)" -ForegroundColor Red
    return
}
$families = @()
foreach ($f in @($cat.families)) {
    if ($null -eq $f) { continue }
    $nameTargets = @()
    foreach ($part in ((Get-StrProp $f 'name') -split '\s*/\s*')) { if ($part.Trim()) { $nameTargets += $part.Trim() } }
    foreach ($d in (Get-ListProp $f 'dirs')) {
        $leaf = ($d -split '[\\/]')[-1]
        if ($leaf -and $leaf -notmatch '%' -and $leaf -notin $genericLeaf) { $nameTargets += $leaf }
    }
    $families += [pscustomobject]@{
        Id          = Get-StrProp $f 'id'
        Name        = Get-StrProp $f 'name'
        Risk        = Get-StrProp $f 'risk'
        Confidence  = Get-StrProp $f 'confidence'
        Notes       = Get-StrProp $f 'uninstall_notes'
        Orgs        = @(@(Get-ListProp $f 'publishers') + @(Get-ListProp $f 'signers') | Select-Object -Unique)
        Processes   = @(Get-ListProp $f 'processes' | ForEach-Object { $_ -replace '(?i)\.exe$', '' })
        Services    = @(Get-ListProp $f 'services')
        Tasks       = @(Get-ListProp $f 'tasks')
        Drivers     = @(Get-ListProp $f 'drivers' | ForEach-Object { $_ -replace '(?i)\.sys$', '' })
        Appx        = @(Get-ListProp $f 'appx')
        NameTargets = @($nameTargets | Select-Object -Unique)
    }
}
$famById = @{}
foreach ($fam in $families) { $famById[$fam.Id] = $fam }
$catalogSource = "data/bloatware-catalog.json（$($families.Count) 个家族，核对日期 $($cat.verified_at)）"

# === 采集（只读）===
$programs = @(Get-WcoInstalledProgram -NoSignature:$NoSignature)

$appxAll = @()
if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    try { $appxAll = @(Get-AppxPackage -ErrorAction SilentlyContinue) } catch { $appxAll = @() }
}
$appx = @($appxAll | Where-Object {
        (Get-StrProp $_ 'IsFramework') -ne 'True' -and
        (Get-StrProp $_ 'NonRemovable') -ne 'True' -and
        (Get-StrProp $_ 'SignatureKind') -ne 'System'
    })

$procs = @()
foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
    $path = ''
    try { $path = [string]$p.Path } catch { $path = '' }
    $procs += [pscustomobject]@{ Name = $p.ProcessName; Path = $path }
}
$procs = @($procs | Sort-Object Name, Path -Unique)

$services = @()
$drivers = @()
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
    $services = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, State, StartMode, PathName)
    $drivers = @(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, State, PathName)
}
$tasks = @()
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })
}

# === 证据收集 ===
# 每条命中行以 "家族|对象" 为键
$rows = [ordered]@{}
function Add-Evidence {
    param($Fam, [string]$Key, [string]$Level, [string]$Text, $Program, $Package)
    if (-not $rows.Contains($Key)) {
        $rows[$Key] = [pscustomobject]@{
            FamilyId = $Fam.Id; Family = $Fam.Name; Risk = $Fam.Risk; CatalogConfidence = $Fam.Confidence
            Level = $Level; Evidence = New-Object System.Collections.Generic.List[string]
            Program = $Program; Package = $Package
        }
    }
    $r = $rows[$Key]
    if ($rank[$Level] -gt $rank[$r.Level]) { $r.Level = $Level }
    if (-not $r.Evidence.Contains($Text)) { $r.Evidence.Add($Text) }
}

function Find-OwnerProgram {
    param([string]$Path)
    if (-not $Path) { return $null }
    foreach ($pg in $programs) {
        if ($pg.InstallLocation -and (Test-UnderPath $Path $pg.InstallLocation)) { return $pg }
    }
    return $null
}

function Add-RuntimeEvidence {
    # 进程 / 服务 / 任务 / 驱动的命中：能定位到所属安装项就挂到该项下，否则单列
    param($Fam, [string]$ExePath, [string]$Level, [string]$Text)
    $owner = Find-OwnerProgram $ExePath
    if ($owner) {
        Add-Evidence -Fam $Fam -Key "$($Fam.Id)|$($owner.KeyPath)" -Level $Level -Text $Text -Program $owner
    } else {
        Add-Evidence -Fam $Fam -Key "$($Fam.Id)|runtime" -Level $Level -Text $Text
    }
}

# 1) 已安装程序
foreach ($pg in $programs) {
    if ((Test-MicrosoftName $pg.Publisher) -or ((Test-MicrosoftName $pg.Signer) -and $pg.SignatureStatus -eq 'Valid')) { continue }
    $installLeaf = if ($pg.InstallLocation) { ($pg.InstallLocation.Trim('"').TrimEnd('\') -split '\\')[-1] } else { '' }
    foreach ($fam in $families) {
        $key = "$($fam.Id)|$($pg.KeyPath)"
        if ($fam.Orgs.Count -gt 0) {
            $m = Test-OrgMatch $pg.Signer $fam.Orgs
            if ($m) { Add-Evidence -Fam $fam -Key $key -Level '高' -Text "签名者 = $($pg.Signer)（$($pg.SignatureStatus)）" -Program $pg }
            $m = Test-OrgMatch $pg.Publisher $fam.Orgs
            if ($m) { Add-Evidence -Fam $fam -Key $key -Level '高' -Text "发行主体 = $($pg.Publisher)" -Program $pg }
        }
        if ($pg.MainExe -and $fam.Processes.Count -gt 0) {
            $m = Test-IdMatch (Get-ExeBaseName $pg.MainExe) $fam.Processes
            if ($m) { Add-Evidence -Fam $fam -Key $key -Level '中' -Text "主程序 = $($pg.MainExe)" -Program $pg }
        }
        foreach ($t in $fam.NameTargets) {
            $nm = Get-WcoNameMatch -Candidate $pg.DisplayName -Target $t
            if ($nm -eq 'None' -and $installLeaf) { $nm = Get-WcoNameMatch -Candidate $installLeaf -Target $t }
            if ($nm -ne 'None') {
                Add-Evidence -Fam $fam -Key $key -Level '低' -Text "名称相似（$nm）：$($pg.DisplayName) ≈ $t" -Program $pg
                break
            }
        }
    }
}

# 2) 商店应用（Appx）
foreach ($pk in $appx) {
    $pkName = Get-StrProp $pk 'Name'
    foreach ($fam in $families) {
        if ($fam.Appx.Count -eq 0) { continue }
        $m = Test-IdMatch $pkName $fam.Appx
        if ($m) { Add-Evidence -Fam $fam -Key "$($fam.Id)|appx:$(Get-StrProp $pk 'PackageFullName')" -Level '中' -Text "商店应用 = $pkName" -Package $pk }
    }
}

# 3) 正在运行的进程
foreach ($pr in $procs) {
    foreach ($fam in $families) {
        if ($fam.Processes.Count -eq 0) { continue }
        if (-not (Test-IdMatch $pr.Name $fam.Processes)) { continue }
        $sig = Get-CachedSigner $pr.Path
        if ($sig -and $sig.IsMicrosoft) { continue }   # 与系统文件同名的微软签名进程：不是它
        $level = '中'
        $text = "进程 $($pr.Name)（$($pr.Path)）"
        if ($sig -and $sig.Organization -and (Test-OrgMatch $sig.Organization $fam.Orgs)) { $level = '高'; $text += " 签名者 = $($sig.Organization)" }
        Add-RuntimeEvidence -Fam $fam -ExePath $pr.Path -Level $level -Text $text
    }
}

# 4) 服务
foreach ($sv in $services) {
    $exe = Get-ExeFromCommandLine ([string]$sv.PathName)
    $base = Get-ExeBaseName $exe
    foreach ($fam in $families) {
        $byName = ($fam.Services.Count -gt 0) -and (Test-IdMatch ([string]$sv.Name) $fam.Services)
        $byExe = ($fam.Processes.Count -gt 0) -and $base -and (Test-IdMatch $base $fam.Processes)
        if (-not $byName -and -not $byExe) { continue }
        $sig = Get-CachedSigner $exe
        if ($sig -and $sig.IsMicrosoft) { continue }
        $level = '中'
        $text = "服务 $($sv.Name)（$($sv.DisplayName)，$($sv.State)/$($sv.StartMode)）程序: $exe"
        if ($sig -and $sig.Organization -and (Test-OrgMatch $sig.Organization $fam.Orgs)) { $level = '高'; $text += " 签名者 = $($sig.Organization)" }
        Add-RuntimeEvidence -Fam $fam -ExePath $exe -Level $level -Text $text
    }
}

# 5) 计划任务（跳过 \Microsoft\ 下的任务）
foreach ($tk in $tasks) {
    $full = "$($tk.TaskPath)$($tk.TaskName)"
    $execs = @()
    foreach ($a in @($tk.Actions)) { $e = Get-StrProp $a 'Execute'; if ($e) { $execs += (Get-ExeFromCommandLine $e) } }
    foreach ($fam in $families) {
        $byName = ($fam.Tasks.Count -gt 0) -and ((Test-IdMatch ([string]$tk.TaskName) $fam.Tasks) -or (Test-IdMatch $full $fam.Tasks))
        $exeHit = $null
        if ($fam.Processes.Count -gt 0) { foreach ($e in $execs) { if (Test-IdMatch (Get-ExeBaseName $e) $fam.Processes) { $exeHit = $e; break } } }
        if (-not $byName -and -not $exeHit) { continue }
        $exe = if ($exeHit) { $exeHit } elseif ($execs.Count -gt 0) { $execs[0] } else { '' }
        Add-RuntimeEvidence -Fam $fam -ExePath $exe -Level '中' -Text "计划任务 $full（$($tk.State)）动作: $($execs -join '; ')"
    }
}

# 6) 内核驱动
foreach ($dv in $drivers) {
    $file = Get-ExeFromCommandLine ([string]$dv.PathName)
    $fileBase = Get-ExeBaseName $file
    foreach ($fam in $families) {
        if ($fam.Drivers.Count -eq 0) { continue }
        if (-not ((Test-IdMatch ([string]$dv.Name) $fam.Drivers) -or ($fileBase -and (Test-IdMatch $fileBase $fam.Drivers)))) { continue }
        Add-RuntimeEvidence -Fam $fam -ExePath $file -Level '中' -Text "驱动 $($dv.Name)（$($dv.State)）文件: $file"
    }
}

# === 整理命中行 ===
$hits = @()
foreach ($r in $rows.Values) {
    $fam = $famById[$r.FamilyId]
    $level = $r.Level
    if ($r.CatalogConfidence -eq 'low') { $level = '低' }
    $levelText = switch ($level) { '高' { '高' } '中' { '中' } default { '低（疑似，需人工确认）' } }
    if ($r.CatalogConfidence -eq 'low') { $levelText += '［目录条目置信度低，需实机确认］' }

    $displayName = ''; $publisher = ''; $hasUs = $false; $pc = ''; $scope = ''; $hidden = $false; $next = ''
    if ($r.Program) {
        $pg = $r.Program
        $displayName = $pg.DisplayName; $publisher = $pg.Publisher; $scope = $pg.Scope; $hidden = [bool]$pg.Hidden
        $hasUs = [bool]$pg.UninstallString
        if ($pg.ProductCode) { $pc = $pg.ProductCode }
        if ($pc) {
            $cmd = "Invoke-WcoUninstall -ProductCode $(ConvertTo-PsQuoted $pc)"
        } elseif ($hasUs) {
            $cmd = "Invoke-WcoUninstall -Name $(ConvertTo-PsQuoted $displayName)"
        } else {
            $cmd = ''
        }
        $leftover = "Find-WcoLeftover -Name $(ConvertTo-PsQuoted $displayName)"
        if ($publisher) { $leftover += " -Publisher $(ConvertTo-PsQuoted $publisher)" }
        if ($cmd) {
            $next = "$cmd（先演练，用户确认后再加 -Apply）→ 卸载向导里留意保留/修复/推荐安装勾选 → 重启后 $leftover"
        } else {
            $next = "没有 UninstallString（附属组件或隐藏项）：先卸载它所属的主程序，重启后 $leftover"
        }
    } elseif ($r.Package) {
        $pkName = Get-StrProp $r.Package 'Name'
        $displayName = "$pkName（商店应用）"; $publisher = Get-StrProp $r.Package 'Publisher'; $scope = 'Appx'
        $next = "Remove-WcoAppxPackage -Name $(ConvertTo-PsQuoted $pkName)（先演练，用户确认后再加 -Apply）→ 重启后 Find-WcoLeftover -Name $(ConvertTo-PsQuoted $pkName) 复扫"
    } else {
        $displayName = '（未找到对应的卸载项）'
        $next = "只在运行态发现：先用 T11 / T18 / T24 定位来源（可能是卸载残留或随其他软件安装）；处理后重启，再 Find-WcoLeftover -Name $(ConvertTo-PsQuoted $fam.Name)"
    }
    if ($level -eq '低') { $next = "先人工核对签名者和安装目录，确认属于该家族再处理；$next" }
    if ($fam.Risk -eq 'oem') { $next = "默认保留，只关推送/推广；用户坚持卸载时才：$next" }

    $hits += [pscustomobject]@{
        Family             = $fam.Name
        FamilyId           = $fam.Id
        Risk               = $fam.Risk
        Level              = $level
        LevelText          = $levelText
        Evidence           = @($r.Evidence)
        DisplayName        = $displayName
        Publisher          = $publisher
        Scope              = $scope
        Hidden             = $hidden
        HasUninstallString = $hasUs
        ProductCode        = $pc
        NextStep           = $next
        Notes              = $fam.Notes
    }
}
$hits = @($hits | Sort-Object @{ E = { $rank[$_.Level] }; Descending = $true }, Family, DisplayName)

# === 未知第三方（目录里没有、发行主体不是 Microsoft；只列出，不建议任何动作）===
$hitKeys = @{}
foreach ($r in $rows.Values) {
    if ($r.Program) { $hitKeys[$r.Program.KeyPath] = $true }
    if ($r.Package) { $hitKeys['appx:' + (Get-StrProp $r.Package 'PackageFullName')] = $true }
}
$unknown = @()
foreach ($pg in $programs) {
    if ($hitKeys.ContainsKey($pg.KeyPath)) { continue }
    if ((Test-MicrosoftName $pg.Publisher) -or ((Test-MicrosoftName $pg.Signer) -and $pg.SignatureStatus -eq 'Valid')) { continue }
    $unknown += [pscustomobject]@{
        DisplayName = $pg.DisplayName; Publisher = $pg.Publisher; Version = $pg.DisplayVersion; Scope = $pg.Scope
        Hidden = [bool]$pg.Hidden; Signer = $pg.Signer; InstallLocation = $pg.InstallLocation
    }
}
foreach ($pk in $appx) {
    $pub = Get-StrProp $pk 'Publisher'
    if (Test-MicrosoftName $pub) { continue }
    if ($hitKeys.ContainsKey('appx:' + (Get-StrProp $pk 'PackageFullName'))) { continue }
    $unknown += [pscustomobject]@{
        DisplayName = "$(Get-StrProp $pk 'Name')（商店应用）"; Publisher = $pub; Version = Get-StrProp $pk 'Version'; Scope = 'Appx'
        Hidden = $false; Signer = ''; InstallLocation = Get-StrProp $pk 'InstallLocation'
    }
}
$unknown = @($unknown | Sort-Object Publisher, DisplayName)

# === 输出 ===
Write-Line "特征来源：$catalogSource"
Write-Line "已盘点：已安装程序 $($programs.Count) 项、商店应用 $($appx.Count) 个、进程 $($procs.Count) 个、服务 $($services.Count) 个、第三方计划任务 $($tasks.Count) 个、驱动 $($drivers.Count) 个$(if ($NoSignature) { '（已跳过签名读取）' })"
Write-Line ''
Write-Line "== 目录命中（$($hits.Count) 项）=="
if ($hits.Count -eq 0) {
    Write-Line '未发现与目录匹配的程序、商店应用、进程、服务、任务或驱动。'
}
foreach ($h in $hits) {
    $color = switch ($h.Level) { '高' { 'Red' } '中' { 'Yellow' } default { 'Gray' } }
    Write-Line "[$($h.LevelText)] $($h.Family) —— $($h.DisplayName)" $color
    foreach ($e in $h.Evidence) { Write-Line "    证据: $e" }
    if ($h.Publisher) { Write-Line "    发行主体: $($h.Publisher)$(if ($h.Scope) { "  [$($h.Scope)]" })$(if ($h.Hidden) { '  （隐藏项，"应用和功能"里看不到）' })" }
    if ($h.Scope -ne 'Appx' -and $h.DisplayName -ne '（未找到对应的卸载项）') {
        Write-Line "    UninstallString: $(if ($h.HasUninstallString) { '有' } else { '无' })    MSI ProductCode: $(if ($h.ProductCode) { $h.ProductCode } else { '无' })"
    }
    if ($h.Notes) { Write-Line "    说明: $($h.Notes)" }
    Write-Line "    下一步: $($h.NextStep)"
}
Write-Line ''
Write-Line "== 未知第三方（目录里没有，非 Microsoft 发行；仅供核对，不建议任何动作）：$($unknown.Count) 项 =="
foreach ($u in $unknown) {
    $pub = if ($u.Publisher) { $u.Publisher } else { '（无发行主体）' }
    Write-Line "  $($u.DisplayName) $($u.Version) | $pub$(if ($u.Scope) { " | $($u.Scope)" })$(if ($u.Hidden) { ' | 隐藏项' })"
}
Write-Line ''
Write-Line '以上只是识别结果，没有做任何修改。所有处置都要用户逐项确认；卸载命令默认只演练（-Apply 才执行），卸载后重启并用 Find-WcoLeftover 复扫。'

$result = [pscustomobject]@{
    GeneratedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    CatalogSource = $catalogSource
    Counts        = [pscustomobject]@{ Programs = $programs.Count; Appx = $appx.Count; Processes = $procs.Count; Services = $services.Count; Tasks = $tasks.Count; Drivers = $drivers.Count; Hits = $hits.Count; Unknown = $unknown.Count }
    Hits          = $hits
    Unknown       = $unknown
}
$jsonText = $null
if ($Json) {
    $jsonText = $result | ConvertTo-Json -Depth 6
    $jsonText
}

if ($OutFile) {
    $tempRoot = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
    $outDir = Join-Path $tempRoot 'wco'
    $target = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $outDir (Split-Path -Leaf $OutFile) }
    $full = [IO.Path]::GetFullPath($target)
    $dirFull = [IO.Path]::GetFullPath($outDir).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($dirFull, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "-OutFile 只能写到 $outDir 下，已忽略：$OutFile" -ForegroundColor Yellow
    } else {
        if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        $content = if ($Json) { $jsonText } else { $script:Lines -join [Environment]::NewLine }
        $content | Out-File -LiteralPath $full -Encoding utf8
        Write-Host "报告已写入：$full"
    }
}
