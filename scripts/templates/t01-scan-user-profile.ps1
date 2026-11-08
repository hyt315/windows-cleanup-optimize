# 模板 1：scan-user-profile（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 1 节。

function Scan-Directory {
    param([string]$Path, [int]$TopN = 20)
    Get-ChildItem $Path -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        # 排除 ReparsePoint 重解析点（防 OneDrive/iCloud 随选占位符水合雪崩与软链接循环）
        $size = (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } |
                 Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }
        [PSCustomObject]@{
            Name    = $_.Name
            SizeMB  = [math]::Round($size / 1MB, 2)
            FullPath = $_.FullName
        }
    } | Sort-Object SizeMB -Descending | Select-Object -First $TopN
}
