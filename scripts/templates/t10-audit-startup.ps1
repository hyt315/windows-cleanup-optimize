# 模板 10：audit-startup（从 references/scan-scripts.md 抽出，v2.1）
# 用法见 references/scan-scripts.md 第 10 节。只读：不改任何启动项。
# v2.1：显示 StartupApproved 状态（首字节 02/06 = 启用，03/07 = 已禁用；没有值 = 默认启用），
#       覆盖 Run / RunOnce / WOW6432Node / "启动"文件夹；计划任务按上次运行时间倒序（最近的在前）。
#       Winlogon、IFEO、AppInit、Active Setup、WMI 订阅、驱动等扩展位置见模板 24（t24-audit-autostart-extended.ps1）。
param(
    [string]$TaskPath = '\*',      # 例：'\Microsoft\Windows\*' 只看某个文件夹；默认全部
    [int]$Top = 30,
    [switch]$IncludeMicrosoftTasks
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Format-ApprovedState {
    param($Item)
    switch ($Item.Approved) {
        'Enabled'  { return '启用' }
        'Disabled' { if ($Item.DisabledAt) { return "已禁用（$($Item.DisabledAt.ToString('yyyy-MM-dd HH:mm'))）" } else { return '已禁用' } }
        'Absent'   { return '启用（无开关记录，默认启用）' }
        'Unknown'  { return '未知（值无法识别，按启用处理）' }
        default    { return '无开关（运行一次后自动删除）' }
    }
}

# === Run / RunOnce / WOW6432Node / 启动文件夹（含 StartupApproved 状态）===
$sources = @('HKCU-Run', 'HKLM-Run', 'HKLM-Run32', 'HKCU-RunOnce', 'HKLM-RunOnce', 'HKLM-RunOnce32', 'HKCU-StartupFolder', 'HKLM-StartupFolder')
$items = @(Get-WcoStartupItem | Where-Object { $sources -contains $_.Source })
Write-Host '=== 登录自启（Run / RunOnce / WOW6432Node / 启动文件夹）==='
if ($items.Count -gt 0) {
    $items | Sort-Object @{ E = { [array]::IndexOf($sources, $_.Source) } }, Name | ForEach-Object {
        "自启: [$($_.Source)] $($_.Name) = $($_.Command) | 状态: $(Format-ApprovedState $_)"
    }
    $off = @($items | Where-Object { $_.Approved -eq 'Disabled' }).Count
    "合计 $($items.Count) 项，其中已在任务管理器/设置里禁用 $off 项（已禁用的不算活跃自启）"
} else {
    '未发现登录自启项'
}
Write-Host '提示：关闭 Run 键 / 启动文件夹项用 Set-WcoStartupApproved -Enabled $false（默认演练，-Apply 才执行，可撤销）。'
Write-Host '扩展自启位置（Winlogon、IFEO、AppInit、Active Setup、Policies\Explorer\Run、RunOnceEx、WMI 订阅、驱动等）请运行 t24-audit-autostart-extended.ps1。'

# === 计划任务（未禁用，按上次运行时间倒序）===
Write-Host "`n=== 计划任务（未禁用，按最近运行排序，前 $Top 项）==="
if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
    $tasks = @(Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' })
    if (-not $IncludeMicrosoftTasks) { $tasks = @($tasks | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }) }
    $rows = foreach ($t in $tasks) {
        $info = $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
        $last = $null
        if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -ge 2000) { $last = [datetime]$info.LastRunTime }   # 从未运行时系统返回 1999-11-30
        $exec = @($t.Actions | ForEach-Object { if ($_.PSObject.Properties['Execute'] -and $_.Execute) { "$($_.Execute) $($_.Arguments)".Trim() } }) -join '; '
        [pscustomobject]@{ Task = "$($t.TaskPath)$($t.TaskName)"; State = $t.State; LastRun = $last; Action = $exec }
    }
    $rows = @($rows | Sort-Object @{ E = { if ($_.LastRun) { $_.LastRun } else { [datetime]::MinValue } }; Descending = $true } | Select-Object -First $Top)
    if ($rows.Count -gt 0) {
        $rows | ForEach-Object {
            "任务: $($_.Task) | 状态: $($_.State) | 上次: $(if ($_.LastRun) { $_.LastRun.ToString('yyyy-MM-dd HH:mm') } else { '从未' }) | 动作: $($_.Action)"
        }
    } else {
        '未发现符合条件的计划任务'
    }
    if (-not $IncludeMicrosoftTasks) { Write-Host '（已略过 \Microsoft\ 下的系统任务；加 -IncludeMicrosoftTasks 显示全部）' }
} else {
    '当前环境没有 Get-ScheduledTask（需要 Windows 8 / Server 2012 及以上）'
}
