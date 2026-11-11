# 模板 5：detect-updater-leftovers（v2.0 由伪代码改为可运行的只读脚本；v2.1.2 体积改用 Measure-WcoDirectory）
# 用法见 references/scan-scripts.md 第 5 节。只读：不删除、不移动任何文件。
param(
    [int]$AppDataMinMB = 5,
    [int]$ProgramMinMB = 20,
    [int]$DownloadMinMB = 50
)

Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Get-SizeMB([string]$Path) {
    # v2.1.2：改用 Measure-WcoDirectory（5.1 下 Get-ChildItem -Recurse 会钻进 junction 重复计数）
    $m = Measure-WcoDirectory -Path $Path
    [math]::Round($m.Bytes / 1MB, 1)
}

$rows = @()

# A. AppData 下 update/updater 类目录（主战场）
foreach ($base in @($env:LOCALAPPDATA, $env:APPDATA)) {
    Get-ChildItem $base -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'update|updater|patch|installer|pending' } |
        ForEach-Object {
            $mb = Get-SizeMB $_.FullName
            if ($mb -ge $AppDataMinMB) {
                $rows += [pscustomobject]@{ Area = 'AppData'; Path = $_.FullName; SizeMB = $mb; LastWrite = $_.LastWriteTime }
            }
        }
}

# B. 各软件安装目录下的 Update/updater/pending 子目录
$progBases = @("$env:LOCALAPPDATA\Programs", $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }
foreach ($pb in $progBases) {
    Get-ChildItem $pb -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($sub in @('Update', 'updater', 'pending', 'updateTemp')) {
            $updDir = Join-Path $_.FullName $sub
            if (Test-Path $updDir) {
                $mb = Get-SizeMB $updDir
                if ($mb -ge $ProgramMinMB) {
                    $rows += [pscustomobject]@{ Area = 'Program'; Path = $updDir; SizeMB = $mb; LastWrite = (Get-Item $updDir -Force).LastWriteTime }
                }
            }
        }
    }
}

# C. 系统级更新缓存（只读统计；Installer 与 Package Cache 属第四档，不可删）
foreach ($sys in @(
        "$env:windir\SoftwareDistribution\Download",
        "$env:windir\SoftwareDistribution\DeliveryOptimization",
        "$env:windir\Installer",
        'C:\NVIDIA', 'C:\AMD', 'C:\Intel',
        "$env:ProgramData\Package Cache")) {
    if (Test-Path $sys) {
        $rows += [pscustomobject]@{ Area = 'System(只读)'; Path = $sys; SizeMB = (Get-SizeMB $sys); LastWrite = (Get-Item $sys -Force).LastWriteTime }
    }
}

# D. Downloads 中的大安装包
$dl = Join-Path $env:USERPROFILE 'Downloads'
if (Test-Path $dl) {
    Get-ChildItem $dl -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.exe', '.msi', '.zip', '.iso' -and $_.Length -ge ($DownloadMinMB * 1MB) } |
        ForEach-Object {
            $rows += [pscustomobject]@{ Area = 'Downloads'; Path = $_.FullName; SizeMB = [math]::Round($_.Length / 1MB, 1); LastWrite = $_.LastWriteTime }
        }
}

$rows | Sort-Object SizeMB -Descending | Format-Table -AutoSize

# "已装完残留" vs "等待安装"：比较安装包与主程序的版本号
#   (Get-Item "<pending>\installer.exe").VersionInfo.ProductVersion
#   (Get-Item "<Programs>\AppName\AppName.exe").VersionInfo.ProductVersion
#   相等 → 已装完，纯残留；不等或读不到 → 按"待安装"处理，先让用户重启该软件完成更新。
