# 模板 3：detect-roaming-leftovers（从 references/scan-scripts.md 抽出，v2.1.2）
# 用法见 references/scan-scripts.md 第 3 节。只读：只列出"疑似残留"，不删除任何东西。
# v2.1.2：判定改用公共模块 Get-WcoInstalledIndex + Get-WcoResidualStatus（与 T4、full_scan 同一套规则）；
#         旧版双向子串匹配会把 Go 当成 Google 的一部分、把 QQ 当成 QQMusic；体积改用 Measure-WcoDirectory。
#         名称对不上只算"疑似残留"（🟡），不是可删结论。
param([double]$MinSizeMB = 0)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# 步骤 1：已安装程序 + 开始菜单快捷方式名 + 运行中进程
$startMenuNames = @()
foreach ($sm in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs")) {
    if ($sm -and (Test-Path -LiteralPath $sm)) {
        $startMenuNames += @(Get-ChildItem -LiteralPath $sm -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
    }
}
$index = Get-WcoInstalledIndex -ExtraName $startMenuNames
$installedLower = @($index.Keys.Keys)   # 兼容旧变量名：规范化后的已安装名称
$runningPaths = @(Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Where-Object { $_ })

# 步骤 2：逐个比对 Roaming 一级目录
$cache = @{}
$roamingResults = @(Get-ChildItem -LiteralPath $env:APPDATA -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $st = Get-WcoResidualStatus -Name $_.Name -Path $_.FullName -Index $index -RunningPath $runningPaths
    $m = Measure-WcoDirectory -Path $_.FullName -Cache $cache
    [PSCustomObject]@{
        Name      = $_.Name
        SizeMB    = [math]::Round($m.Bytes / 1MB, 2)
        FullPath  = $_.FullName
        LastWrite = $_.LastWriteTime.ToString("yyyy-MM")
        Status    = $st.Status
        Level     = $st.Level
        Reason    = $st.Reason
    }
})

# 输出分类结果
Write-Host "=== 🟡 疑似残留（只是筛选结果，不是可删结论；核对后再处置）==="
$roamingResults | Where-Object { $_.Status -eq 'Suspect' -and $_.SizeMB -gt $MinSizeMB } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB, LastWrite -AutoSize
Write-Host '核对要点：目录最近修改时间、是否有对应进程/服务/计划任务、是否为公司名目录。卸载后的残留优先用 Find-WcoLeftover 打分。'

Write-Host "`n=== ✅ 正在使用的软件（不要动）==="
$roamingResults | Where-Object { $_.Status -eq 'Installed' } |
    Sort-Object SizeMB -Descending | Format-Table Name, SizeMB, Reason -AutoSize
