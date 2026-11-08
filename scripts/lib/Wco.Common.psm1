<#
.SYNOPSIS
    windows-cleanup-optimize 公共模块（v2.0）：权限检测、回收站预检、变更留痕与一键回退。
.DESCRIPTION
    所有写操作函数默认只演练（打印"将会做什么"），传 -Apply 才真正执行。
    每次真正执行都写入会话目录下的 changes.json，并可用 Export-WcoUndo 生成 undo.ps1。
    兼容 Windows PowerShell 5.1 与 PowerShell 7。文件以 UTF-8 BOM 保存（5.1 读中文必需）。
#>

Set-StrictMode -Version 2

$script:WcoSession = $null

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
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'reg') -Force | Out-Null
    $script:WcoSession = [pscustomobject]@{ Dir = $dir; Ledger = (Join-Path $dir 'changes.json'); Changes = New-Object System.Collections.ArrayList }
    return $script:WcoSession
}

function Get-WcoSession {
    if (-not $script:WcoSession) { [void](Start-WcoSession) }
    return $script:WcoSession
}

function Add-WcoChange {
    <# 记录一条已执行的变更。Undo 为可直接执行的 PowerShell 命令文本；无法自动回退时写 $null 并在 Note 里说明。 #>
    param(
        [Parameter(Mandatory)][ValidateSet('recycle', 'service', 'registry', 'scheduled-task', 'ifeo', 'other')][string]$Kind,
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
    $s.Changes | ConvertTo-Json -Depth 4 | Set-Content -Path $s.Ledger -Encoding UTF8
    return $entry
}

function Export-WcoUndo {
    <# 按与执行相反的顺序生成 undo.ps1。回收站类变更提示从回收站还原（无法脚本化精确还原）。 #>
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
        $lines += ''
    }
    # 带 BOM，保证 Windows PowerShell 5.1 正确读取中文注释
    [IO.File]::WriteAllText($path, ($lines -join "`r`n"), (New-Object Text.UTF8Encoding($true)))
    return $path
}

# ---------------------------------------------------------------- 回收站预检
function Get-WcoRecycleBinPolicy {
    <#
    返回目标路径所在卷的回收站策略：是否有回收站、是否"不移入回收站直接删除"、容量上限（MB）。
    依据：HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\{GUID}
          下的 NukeOnDelete 与 MaxCapacity（单位 MB）。读不到时 Known=$false，调用方应按"不安全"处理。
    #>
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $result = [pscustomobject]@{ Path = $full; HasRecycleBin = $false; NukeOnDelete = $null; MaxCapacityMB = $null; Known = $false; Reason = '' }
    if ($full.StartsWith('\\')) { $result.Reason = '网络路径没有回收站'; return $result }
    $root = [IO.Path]::GetPathRoot($full)
    $drive = New-Object IO.DriveInfo($root)
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { $result.Reason = "卷类型为 $($drive.DriveType)，没有回收站"; return $result }
    $result.HasRecycleBin = $true
    try {
        $letter = $root.TrimEnd('\')
        $vol = Get-CimInstance Win32_Volume -Filter "DriveLetter='$letter'" -ErrorAction Stop
        $guid = ([regex]::Match($vol.DeviceID, '\{[0-9A-Fa-f-]+\}')).Value
        $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\$guid"
        if ($guid -and (Test-Path $key)) {
            $p = Get-ItemProperty $key
            $result.NukeOnDelete = [bool]($p.PSObject.Properties['NukeOnDelete'] -and $p.NukeOnDelete -eq 1)
            if ($p.PSObject.Properties['MaxCapacity']) { $result.MaxCapacityMB = [int64]$p.MaxCapacity }
            $result.Known = $true
        } else {
            $result.Reason = '未找到该卷的回收站策略键（可能从未在资源管理器里打开过回收站属性）'
        }
    } catch {
        $result.Reason = "读取回收站策略失败：$($_.Exception.Message)"
    }
    return $result
}

function Get-WcoItemSizeMB {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer) { return [math]::Round($item.Length / 1MB, 2) }
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
            Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { 0 } else { [math]::Round($sum / 1MB, 2) }
}

function Invoke-WcoRecycle {
    <#
    .SYNOPSIS
        把文件或目录移入回收站（模板 7 的 v2.0 实现）。默认只演练，-Apply 才执行。
    .DESCRIPTION
        执行前依次检查：路径存在 → 不是 junction/符号链接（是则拒绝，交给模板 6）→ 所在卷有回收站
        → 回收站未设为"直接删除" → 体积不超过回收站上限（超过时 Windows 会直接永久删除）。
        任何一项不满足都返回 Status=Blocked，不执行，由 AI 呈报给用户决定。
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
    if ($pol.NukeOnDelete) { $r.Status = 'Blocked'; $r.Reason = '该卷回收站设为"不移入回收站，直接删除"'; return $r }
    if ($pol.Known -and $pol.MaxCapacityMB -and $r.SizeMB -gt $pol.MaxCapacityMB) {
        $r.Status = 'Blocked'; $r.Reason = "体积 $($r.SizeMB) MB 超过回收站上限 $($pol.MaxCapacityMB) MB，Windows 会直接永久删除"; return $r
    }
    if (-not $pol.Known) { $r.Reason = "回收站上限未知（$($pol.Reason)）；大于 1 GB 的项请先让用户确认" }
    if (-not $pol.Known -and $r.SizeMB -gt 1024) { $r.Status = 'Blocked'; return $r }
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
    } catch [IO.IOException] {
        $r.Status = 'Locked'; $r.Reason = "文件被占用，已跳过：$($_.Exception.Message)"
    } catch {
        $r.Status = 'Error'; $r.Reason = $_.Exception.Message
    }
    return $r
}

# ---------------------------------------------------------------- 服务
function Set-WcoServiceStartType {
    <# 修改服务启动类型前先记下原值（含"自动(延迟启动)"），回退时恢复原值而不是一律 auto。默认只演练。 #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('auto', 'delayed-auto', 'demand', 'disabled')][string]$StartType,
        [ValidateSet('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')][string]$Risk = 'MEDIUM',
        [switch]$Apply
    )
    $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $svc) { return [pscustomobject]@{ Name = $Name; Status = 'Skip'; Reason = '服务不存在' } }
    $before = switch ($svc.StartMode) { 'Auto' { if ($svc.DelayedAutoStart) { 'delayed-auto' } else { 'auto' } } 'Manual' { 'demand' } 'Disabled' { 'disabled' } default { $svc.StartMode.ToLower() } }
    if (-not $Apply) { return [pscustomobject]@{ Name = $Name; Status = 'DryRun'; Before = $before; After = $StartType } }
    & sc.exe config $Name start= $StartType | Out-Null
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Name = $Name; Status = 'Error'; Reason = "sc.exe 返回 $LASTEXITCODE" } }
    [void](Add-WcoChange -Kind service -Target $Name -Before $before -After $StartType -Undo "sc.exe config $Name start= $before" -Risk $Risk)
    return [pscustomobject]@{ Name = $Name; Status = 'Changed'; Before = $before; After = $StartType }
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
    $psKey = 'Registry::' + $Key
    $old = $null
    if (Test-Path $psKey) { $old = (Get-ItemProperty $psKey -Name $Name -ErrorAction SilentlyContinue).$Name }
    if (-not $Apply) { return [pscustomobject]@{ Key = $Key; Name = $Name; Status = 'DryRun'; Before = $old; After = $Value } }
    $s = Get-WcoSession
    $undo = $null
    if (Test-Path $psKey) {
        $bak = Join-Path $s.Dir ('reg\' + ([guid]::NewGuid().ToString('N')) + '.reg')
        & reg.exe export $Key $bak /y | Out-Null
        $undo = "reg.exe import `"$bak`""
        if ($null -eq $old) { $undo = "Remove-ItemProperty -LiteralPath '$psKey' -Name '$Name' -ErrorAction SilentlyContinue" }
    } else {
        New-Item -Path $psKey -Force | Out-Null
        $undo = "Remove-Item -LiteralPath '$psKey' -Recurse -ErrorAction SilentlyContinue"
    }
    New-ItemProperty -LiteralPath $psKey -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    [void](Add-WcoChange -Kind $Kind -Target "$Key\$Name" -Before "$old" -After "$Value" -Undo $undo -Risk $Risk)
    return [pscustomobject]@{ Key = $Key; Name = $Name; Status = 'Changed'; Before = $old; After = $Value }
}

Export-ModuleMember -Function Test-WcoAdmin, Start-WcoSession, Get-WcoSession, Add-WcoChange, Export-WcoUndo,
    Get-WcoRecycleBinPolicy, Get-WcoItemSizeMB, Invoke-WcoRecycle, Set-WcoServiceStartType, Set-WcoRegistryValue
