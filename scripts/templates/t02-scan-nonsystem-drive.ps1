# 模板 2：scan-nonsystem-drive（从 references/scan-scripts.md 抽出，v2.1.2）
# 用法见 references/scan-scripts.md 第 2 节。
# v2.1.2：体积改用 Measure-WcoDirectory（不进 junction/符号链接，不重复计数）。
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Measure-NonSystemDrive {
    param([string]$DriveLetter = "D")
    $root = "${DriveLetter}:\"
    Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $m = Measure-WcoDirectory -Path $_.FullName
        [PSCustomObject]@{
            Name      = $_.Name
            SizeMB    = [math]::Round($m.Bytes / 1MB, 0)
            FullPath  = $_.FullName
            Hidden    = if ($_.Attributes -match 'Hidden') { 'Y' } else { 'N' }
            LastWrite = $_.LastWriteTime.ToString('yyyy-MM-dd')
        }
    } | Sort-Object SizeMB -Descending
}
