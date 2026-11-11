# 模板 4：detect-install-dir-leftovers（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 4 节。只读：只列出"疑似残留"，不删除任何东西。
# v2.1：自带已安装程序清单（不再依赖先跑模板 3 留下的 $installedLower），真正输出结果；
#       名称 ≤4 个字符时只认完全相等（QQ、WPS、Git 这类短名不做模糊匹配）；结果标"疑似残留"，需人工核对后再处置。
param(
    [string[]]$Base = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", 'D:\Program Files', 'D:\Program Files (x86)', "$env:LOCALAPPDATA\Programs"),
    [double]$MinSizeMB = 0
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function ConvertTo-NameKey {
    # 与 Get-WcoNameMatch 相同思路的简化规范化：小写，只保留字母、数字与中日韩文字
    param([string]$Text)
    if (-not $Text) { return '' }
    return ($Text.ToLower() -replace '[^\p{L}\p{Nd}]', '')
}

# 步骤 1：收集已安装应用匹配词（Uninstall 注册表 DisplayName / Publisher / 安装目录名 + 开始菜单快捷方式名）
$programs = @(Get-WcoInstalledProgram -NoSignature)
$installedLower = @()
$installLocations = @()
foreach ($p in $programs) {
    $installedLower += $p.DisplayName
    if ($p.Publisher) { $installedLower += $p.Publisher }
    if ($p.InstallLocation) {
        $loc = $p.InstallLocation.Trim().Trim('"').TrimEnd('\')
        if ($loc) { $installLocations += $loc; $installedLower += (Split-Path -Leaf $loc) }
    }
}
foreach ($sm in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs")) {
    if (Test-Path -LiteralPath $sm) {
        Get-ChildItem -LiteralPath $sm -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object { $installedLower += $_.BaseName }
    }
}
$installedKeys = @($installedLower | ForEach-Object { ConvertTo-NameKey $_ } | Where-Object { $_ } | Select-Object -Unique)
$runningPaths = @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Where-Object { $_ })

$knownSys = @('common files','windows nt','internet explorer','windows defender','windows defender advanced threat protection',
              'microsoft shared','windows media player','windows photo viewer','windows portable devices','windows mail',
              'windows sidebar','windows security','reference assemblies','msbuild','dotnet','windows kits','windowsapps',
              'modifiablewindowsapps','windows powershell','windowspowershell','microsoft.net','uninstall information',
              'microsoft update health tools','windows multimedia platform','package cache')  # 系统/共享目录，跳过

# 步骤 2：扫描安装目录一级 vs 匹配词，无匹配即"疑似残留"
$results = @()
foreach ($pb in ($Base | Where-Object { $_ } | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $pb)) { continue }
    Get-ChildItem -LiteralPath $pb -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $dir = $_
        if ($knownSys -contains $dir.Name.ToLower()) { return }
        if ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) { return }   # junction：已迁走的目录，不在这里判断
        $prefix = $dir.FullName.TrimEnd('\') + '\'
        # 有已安装程序的 InstallLocation 落在该目录内（或就是该目录） → 在用
        foreach ($loc in $installLocations) {
            if ($loc -eq $dir.FullName.TrimEnd('\') -or $loc.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return }
        }
        # 有正在运行的进程来自该目录 → 在用
        foreach ($rp in $runningPaths) { if ($rp.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return } }
        # 名称比对：≤4 个字符只认完全相等，更长的允许互相包含
        $key = ConvertTo-NameKey $dir.Name
        if (-not $key) { return }
        $match = $null
        foreach ($k in $installedKeys) {
            if ($k -eq $key) { $match = $k; break }
            if ([math]::Min($k.Length, $key.Length) -le 4) { continue }
            if ($k.Contains($key) -or $key.Contains($k)) { $match = $k; break }
        }
        if ($match) { return }
        $m = Measure-WcoDirectory -Path $dir.FullName
        $sizeMB = [math]::Round($m.Bytes / 1MB, 1)
        if ($sizeMB -lt $MinSizeMB) { return }
        $results += [pscustomobject]@{
            SizeMB    = $sizeMB
            Name      = $dir.Name
            Path      = $dir.FullName
            LastWrite = $dir.LastWriteTime.ToString('yyyy-MM-dd')
            Status    = '疑似残留'
            Note      = $(if ($m.ReparseSkipped -gt 0) { "含 $($m.ReparseSkipped) 个链接未计入" } elseif ($m.Errors -gt 0) { "$($m.Errors) 处无权读取" } else { '' })
        }
    }
}

# 输出: 大小 | 目录名 | 路径 | 最后写入时间 | 状态
if ($results.Count -gt 0) {
    Write-Host "=== 安装目录疑似残留（共 $($results.Count) 个；只是筛选结果，不是可删结论）==="
    $results | Sort-Object SizeMB -Descending | Format-Table SizeMB, Name, Path, LastWrite, Status, Note -AutoSize -Wrap
    Write-Host '核对要点：目录内部最近修改时间是否超过 6 个月、是否有对应进程/服务/计划任务、是否是公司名目录（内部可能装着别的在用软件）。'
    Write-Host '确认后再用模板 7（t07-safe-recycle.ps1）移入回收站；默认只演练。'
} else {
    '未发现安装目录疑似残留'
}
