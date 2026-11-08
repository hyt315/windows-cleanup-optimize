# 模板 21：query-compactos（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 21 节。

# 1. 查询系统当前 CompactOS 压缩状态（纯只读）
function Query-CompactOS {
    Write-Host "=== CompactOS 状态查询 ===" -ForegroundColor Cyan
    compact.exe /compactos:query
}

# 2. 安全启用 CompactOS 无损压缩（可安全释放 2.0GB ~ 4.5GB C 盘空间，不影响系统启动速度）
# 须以管理员身份运行并在用户明确授权后执行
function Enable-CompactOS {
    Write-Host "=== 正在启用 CompactOS 核心系统文件无损压缩（耗时约 3-10 分钟）===" -ForegroundColor Yellow
    compact.exe /compactos:always
}

# 3. 恢复/回退为未压缩状态
function Disable-CompactOS {
    Write-Host "=== 正在恢复 CompactOS 状态 ===" -ForegroundColor Yellow
    compact.exe /compactos:never
}
