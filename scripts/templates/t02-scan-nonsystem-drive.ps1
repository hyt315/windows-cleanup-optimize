# 模板 2：scan-nonsystem-drive（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 2 节。

function Measure-NonSystemDrive {
    param([string]$DriveLetter = "D")
    $root = "${DriveLetter}:\"
    Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } |
                 Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }
        [PSCustomObject]@{
            Name      = $_.Name
            SizeMB    = [math]::Round($size / 1MB, 0)
            FullPath  = $_.FullName
            Hidden    = if ($_.Attributes -match 'Hidden') { 'Y' } else { 'N' }
            LastWrite = $_.LastWriteTime.ToString('yyyy-MM-dd')
        }
    } | Sort-Object SizeMB -Descending
}
