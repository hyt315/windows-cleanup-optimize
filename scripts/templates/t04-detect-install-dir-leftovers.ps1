# 模板 4：detect-install-dir-leftovers（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 4 节。只读：只列出"疑似残留"，不删除任何东西。
# v2.1.2：判定改用公共模块 Get-WcoInstalledIndex + Get-WcoResidualStatus，与 T3、full_scan 同一套规则。
# v2.1：自带已安装程序清单（不再依赖先跑模板 3 留下的 $installedLower），真正输出结果；
#       名称 ≤4 个字符时只认完全相等（QQ、WPS、Git 这类短名不做模糊匹配）；结果标"疑似残留"，需人工核对后再处置。
param(
    [string[]]$Base = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", 'D:\Program Files', 'D:\Program Files (x86)', "$env:LOCALAPPDATA\Programs"),
    [double]$MinSizeMB = 0
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# 步骤 1：已安装程序 + 开始菜单快捷方式名 + 运行中进程（与 T3、full_scan 共用 Get-WcoInstalledIndex）
$startMenuNames = @()
foreach ($sm in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs")) {
    if ($sm -and (Test-Path -LiteralPath $sm)) {
        $startMenuNames += @(Get-ChildItem -LiteralPath $sm -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
    }
}
$index = Get-WcoInstalledIndex -ExtraName $startMenuNames
$installedLower = @($index.Keys.Keys)   # 兼容旧变量名：规范化后的已安装名称
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
        # 安装目录 / 运行中进程 / 名称比对，规则见 Get-WcoResidualStatus（≤4 个字符只认完全相等）
        $st = Get-WcoResidualStatus -Name $dir.Name -Path $dir.FullName -Index $index -RunningPath $runningPaths
        if ($st.Status -eq 'Installed') { return }
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
