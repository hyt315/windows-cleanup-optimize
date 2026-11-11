# 模板 14：show-power-visual（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 14 节。
# v2.1：纯只读报告——显示当前电源计划、可用计划、视觉效果设置、休眠状态。
#       不再自动切换电源计划、复制"卓越性能"计划或添加 Defender 排除；需要改动时由用户自行执行文末打印的命令。

if (-not (Get-Command powercfg -ErrorAction SilentlyContinue)) {
    '当前环境没有 powercfg（仅 Windows 可用）'
    return
}

# 当前电源计划
Write-Host '=== 当前电源计划 ==='
powercfg /getactivescheme

# 可用电源计划列表
Write-Host "`n=== 可用电源计划 ==="
powercfg /list

# 视觉效果（系统属性 › 高级 › 性能 › 视觉效果）
Write-Host "`n=== 视觉效果 ==="
$vfx = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name VisualFXSetting -ErrorAction SilentlyContinue
$vfxText = @{ 0 = '让 Windows 选择（默认）'; 1 = '调整为最佳外观'; 2 = '调整为最佳性能'; 3 = '自定义' }
if ($vfx -and $null -ne $vfx.VisualFXSetting) {
    $v = [int]$vfx.VisualFXSetting
    "视觉效果: $(if ($vfxText.ContainsKey($v)) { $vfxText[$v] } else { "未知值 $v" })"
} else {
    '视觉效果: 让 Windows 选择（默认，未设置 VisualFXSetting）'
}
$tp = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name EnableTransparency -ErrorAction SilentlyContinue
if ($tp -and $null -ne $tp.EnableTransparency) { "透明效果: $(if ([int]$tp.EnableTransparency -eq 1) { '开' } else { '关' })" }

# 休眠 / 快速启动
Write-Host "`n=== 休眠与快速启动 ==="
$pw = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue
if ($pw -and $pw.PSObject.Properties['HibernateEnabled']) {
    "休眠: $(if ([int]$pw.HibernateEnabled -eq 1) { '已启用' } else { '已关闭' })"
} else {
    '休眠: 未读到 HibernateEnabled（以下 powercfg /a 的结果为准）'
}
$hf = Join-Path $env:SystemDrive 'hiberfil.sys'
$hfItem = Get-Item -LiteralPath $hf -Force -ErrorAction SilentlyContinue
if ($hfItem) { "hiberfil.sys: $([math]::Round($hfItem.Length / 1GB, 2)) GB" }
$fs = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -ErrorAction SilentlyContinue
if ($fs -and $null -ne $fs.HiberbootEnabled) { "快速启动: $(if ([int]$fs.HiberbootEnabled -eq 1) { '已启用' } else { '已关闭' })" }
powercfg /a

# TRIM 检查（只读查询；DisableDeleteNotify = 0 表示 TRIM 已启用）
Write-Host "`n=== TRIM ==="
fsutil behavior query DisableDeleteNotify

# Defender 排除列表（只读；非管理员会话可能看不到内容）
Write-Host "`n=== Defender 排除路径（只读）==="
if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
    $ex = @(Get-MpPreference -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ExclusionPath -ErrorAction SilentlyContinue)
    if ($ex.Count -gt 0) { $ex } else { '无排除路径，或需要管理员权限才能查看' }
} else {
    '未找到 Get-MpPreference（Defender 模块不可用）'
}

# 可选命令（仅打印，不执行）
Write-Host "`n=== 可选命令（本脚本不会执行；如需改动请自行在管理员 PowerShell 中运行）==="
Write-Host '建议：多数电脑保持"平衡"(Balanced) 计划即可，它是微软推荐的默认选项，按负载自动升降频；高性能/卓越性能主要增加功耗和发热。'
@(
    '# 切回"平衡"（推荐默认）',
    'powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e',
    '# 切换到"高性能"',
    'powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c',
    '# 显示隐藏的"卓越性能"计划（会新增一个计划）',
    'powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61',
    '# 关闭休眠（删除 hiberfil.sys，同时关闭快速启动）/ 重新开启',
    'powercfg /hibernate off',
    'powercfg /hibernate on',
    '# 视觉效果：打开系统设置界面手动调整',
    'SystemPropertiesPerformance.exe'
) | ForEach-Object { "    $_" }
Write-Host '不建议为提速而添加 Defender 排除路径（会降低防护）；确有需要请在 Windows 安全中心界面里针对具体目录添加。'
