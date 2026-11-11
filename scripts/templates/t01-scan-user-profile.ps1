# 模板 1：scan-user-profile（从 references/scan-scripts.md 抽出，v2.1.2）
# 用法见 references/scan-scripts.md 第 1 节。
# v2.1.2：体积改用 Measure-WcoDirectory（不进 junction/符号链接/云占位符，5.1 下也不会把迁到 D 盘的数据重复算进 C 盘）。
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Measure-Directory {
    param([string]$Path, [int]$TopN = 20)
    $cache = @{}
    Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $m = Measure-WcoDirectory -Path $_.FullName -Cache $cache
        [PSCustomObject]@{
            Name     = $_.Name
            SizeMB   = [math]::Round($m.Bytes / 1MB, 2)
            FullPath = $_.FullName
            Note     = $(if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) { '链接，未计入' } elseif ($m.ReparseSkipped -gt 0) { "含 $($m.ReparseSkipped) 个链接未计入" } else { '' })
        }
    } | Sort-Object SizeMB -Descending | Select-Object -First $TopN
}
