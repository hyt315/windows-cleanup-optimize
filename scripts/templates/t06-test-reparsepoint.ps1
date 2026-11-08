# 模板 6：test-reparsepoint（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 6 节。

function Test-ReparsePoint {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    if ($item.Attributes -match 'ReparsePoint') {
        # 注意：$item.Target 仅 PowerShell 6+ 存在，PS 5.1 下取不到目标。
        # 如需显示 junction 目标，用: cmd /c dir /AL "<父目录>" 查看
        Write-Host "[JUNCTION] $Path"
        return $true
    }
    return $false
}
