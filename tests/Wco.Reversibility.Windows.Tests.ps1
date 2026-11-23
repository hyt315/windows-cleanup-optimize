# Windows 写操作闭环测试（v2.2.1）：演练 → 执行 → 生成 undo.ps1 → 用 Windows PowerShell 5.1 运行 undo → 对比原状。
# 会真的改注册表、服务、计划任务，所以只在一次性环境里跑：需要 Windows、管理员，并且显式设置 WCO_CI_APPLY=1。
# GitHub Actions 的 Windows runner 满足这三条；开发者在自己电脑上运行 Invoke-Pester 时这些用例自动跳过。
# 所有测试对象都用 wco-ci- 前缀，只建只删自己的东西。

BeforeDiscovery {
    $script:canApply = ($env:OS -eq 'Windows_NT') -and ($env:WCO_CI_APPLY -eq '1') -and
        ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1') -Force
    $script:root = Join-Path ([IO.Path]::GetTempPath()) ('wco-ci-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:root | Out-Null
    function script:Export-KeyText([string]$Key) {
        $f = Join-Path $script:root ('snap_' + [guid]::NewGuid().ToString('N') + '.reg')
        & reg.exe export $Key $f /y 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return '<absent>' }
        return ((Get-Content -LiteralPath $f -Raw) -replace '\r', '')
    }
    function script:Invoke-Undo([string]$Path) {
        # 用 Windows PowerShell 5.1 跑，顺带证明生成的 undo.ps1 在 5.1 下可用
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $out }
    }
    function script:New-Session { Start-WcoSession -Root $script:root }
}

AfterAll {
    foreach ($k in 'HKCU\Software\wco-ci-vendor', 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wco-ci-dummy.exe') {
        & reg.exe delete $k /f 2>&1 | Out-Null
    }
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'wco-ci-run' -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Name 'wco-ci-run' -ErrorAction SilentlyContinue
    foreach ($s in 'wco-ci-svc', 'wco-ci-svc-del') { & sc.exe delete $s 2>&1 | Out-Null }
    foreach ($t in 'wco-ci-task', 'wco-ci-task-del') { Unregister-ScheduledTask -TaskPath '\' -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $script:root -Recurse -Force -ErrorAction SilentlyContinue
}

Describe '注册表值（含新建键）闭环' -Skip:(-not $script:canApply) {
    It '改已有值、在新子键里加值 → undo 后整棵键与原来逐字相同；undo 可重复运行' {
        & reg.exe add 'HKCU\Software\wco-ci-vendor\App' /v Level /t REG_DWORD /d 5 /f | Out-Null
        & reg.exe add 'HKCU\Software\wco-ci-vendor\App' /v 中文值 /t REG_SZ /d '原值 带空格' /f | Out-Null
        $before = Export-KeyText 'HKCU\Software\wco-ci-vendor'
        New-Session | Out-Null
        (Set-WcoRegistryValue -Key 'HKCU\Software\wco-ci-vendor\App' -Name Level -Value 0).Status | Should -Be 'DryRun'
        Export-KeyText 'HKCU\Software\wco-ci-vendor' | Should -Be $before
        (Set-WcoRegistryValue -Key 'HKCU\Software\wco-ci-vendor\App' -Name Level -Value 0 -Apply).Status | Should -Be 'Changed'
        (Set-WcoRegistryValue -Key 'HKCU\Software\wco-ci-vendor\App\New\Deep' -Name X -Value 1 -Apply).Status | Should -Be 'Changed'
        Export-KeyText 'HKCU\Software\wco-ci-vendor' | Should -Not -Be $before
        $u = Export-WcoUndo
        (Invoke-Undo $u).Code | Should -Be 0
        Export-KeyText 'HKCU\Software\wco-ci-vendor' | Should -Be $before
        (Invoke-Undo $u).Code | Should -Be 0
        Export-KeyText 'HKCU\Software\wco-ci-vendor' | Should -Be $before
    }
}

Describe 'IFEO 闭环（HKLM，需要管理员）' -Skip:(-not $script:canApply) {
    It '给不存在的 exe 加 Debugger → undo 后整键消失' {
        $k = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wco-ci-dummy.exe'
        Export-KeyText $k | Should -Be '<absent>'
        New-Session | Out-Null
        (Set-WcoRegistryValue -Key $k -Name Debugger -Value "$env:SystemRoot\System32\systray.exe" -Type String -Kind ifeo -Apply).Status | Should -Be 'Changed'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        Export-KeyText $k | Should -Be '<absent>'
    }
}

Describe '注册表整键删除闭环' -Skip:(-not $script:canApply) {
    It '删除产品子键 → undo 后与原来逐字相同' {
        & reg.exe add 'HKCU\Software\wco-ci-vendor\Leftover\Sub' /v Path /t REG_EXPAND_SZ /d '%LOCALAPPDATA%\x' /f | Out-Null
        & reg.exe add 'HKCU\Software\wco-ci-vendor\Leftover' /v Bin /t REG_BINARY /d 0102AB /f | Out-Null
        $before = Export-KeyText 'HKCU\Software\wco-ci-vendor\Leftover'
        New-Session | Out-Null
        (Remove-WcoRegistryKey -Path 'HKCU\Software\wco-ci-vendor\Leftover' -Apply).Status | Should -Be 'Deleted'
        Export-KeyText 'HKCU\Software\wco-ci-vendor\Leftover' | Should -Be '<absent>'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        Export-KeyText 'HKCU\Software\wco-ci-vendor\Leftover' | Should -Be $before
    }
}

Describe '服务闭环' -Skip:(-not $script:canApply) {
    BeforeAll {
        # 复制一个可执行文件到临时目录当服务程序：不在 Windows 目录、也没有微软签名，才能走到删除流程。服务从不启动。
        $script:svcExe = Join-Path $script:root 'wco ci svc.exe'
        Copy-Item "$env:SystemRoot\System32\sort.exe" $script:svcExe
    }
    It '<Start> → disabled → undo 后恢复成 <Start>（含延迟启动）' -ForEach @(@{ Start = 'demand' }, @{ Start = 'delayed-auto' }) {
        & sc.exe delete wco-ci-svc 2>&1 | Out-Null
        & sc.exe create wco-ci-svc binPath= "`"$script:svcExe`"" start= $Start | Out-Null
        $LASTEXITCODE | Should -Be 0
        New-Session | Out-Null
        (Set-WcoServiceStartType -Name 'wco-ci-svc' -StartType disabled -Apply).Status | Should -Be 'Changed'
        (Get-CimInstance Win32_Service -Filter "Name='wco-ci-svc'").StartMode | Should -Be 'Disabled'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        $svc = Get-CimInstance Win32_Service -Filter "Name='wco-ci-svc'"
        if ($Start -eq 'demand') { $svc.StartMode | Should -Be 'Manual' } else { $svc.StartMode | Should -Be 'Auto'; $svc.DelayedAutoStart | Should -BeTrue }
    }
    It '删除已停用的第三方服务 → undo 导回注册表项（重启后服务恢复）' {
        & sc.exe create wco-ci-svc-del binPath= "`"$script:svcExe`"" start= disabled | Out-Null
        $before = Export-KeyText 'HKLM\SYSTEM\CurrentControlSet\Services\wco-ci-svc-del'
        New-Session | Out-Null
        (Remove-WcoService -Name 'wco-ci-svc-del').Status | Should -Be 'DryRun'
        (Remove-WcoService -Name 'wco-ci-svc-del' -Apply).Status | Should -Be 'Deleted'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        # SCM 要到重启才重新加载导回的服务；这里核对注册表定义已完整恢复
        Export-KeyText 'HKLM\SYSTEM\CurrentControlSet\Services\wco-ci-svc-del' | Should -Be $before
    }
}

Describe '计划任务闭环' -Skip:(-not $script:canApply) {
    BeforeAll {
        function script:New-CiTask([string]$Name) {
            $a = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\cmd.exe" -Argument '/c exit 0'
            $t = New-ScheduledTaskTrigger -Once -At (Get-Date).AddYears(5)
            Register-ScheduledTask -TaskPath '\' -TaskName $Name -Action $a -Trigger $t -Force | Out-Null
        }
    }
    It '停用 → undo 后恢复为启用' {
        New-CiTask 'wco-ci-task'
        New-Session | Out-Null
        (Disable-WcoScheduledTask -TaskPath '\' -TaskName 'wco-ci-task' -Apply).Status | Should -Be 'Changed'
        (Get-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task').State | Should -Be 'Disabled'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        (Get-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task').State | Should -Be 'Ready'
    }
    It '删除 → undo 用导出的 XML 重新注册，动作与原来一致' {
        New-CiTask 'wco-ci-task-del'
        $before = (Export-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task-del')
        New-Session | Out-Null
        (Remove-WcoScheduledTask -TaskPath '\' -TaskName 'wco-ci-task-del' -Apply).Status | Should -Be 'Deleted'
        Get-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task-del' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        $after = Get-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task-del'
        $after.Actions[0].Execute | Should -Be "$env:SystemRoot\System32\cmd.exe"
        ([xml](Export-ScheduledTask -TaskPath '\' -TaskName 'wco-ci-task-del')).Task.Actions.OuterXml | Should -Be ([xml]$before).Task.Actions.OuterXml
    }
}

Describe '启动项开关闭环' -Skip:(-not $script:canApply) {
    It '关掉一个 Run 项 → undo 后开关记录回到「没有记录」（默认启用）' {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'wco-ci-run' -Value "`"$env:SystemRoot\System32\cmd.exe`" /c exit"
        $sa = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        New-Session | Out-Null
        (Set-WcoStartupApproved -Name 'wco-ci-run' -Scope HKCU-Run -Enabled $false -Apply).Status | Should -Be 'Changed'
        (Get-WcoStartupApproved -Scope HKCU-Run | Where-Object Name -eq 'wco-ci-run').State | Should -Be 'Disabled'
        (Invoke-Undo (Export-WcoUndo)).Code | Should -Be 0
        Get-WcoStartupApproved -Scope HKCU-Run | Where-Object Name -eq 'wco-ci-run' | Should -BeNullOrEmpty
        (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run').'wco-ci-run' | Should -Not -BeNullOrEmpty
    }
}

Describe '中途失败与部分还原' -Skip:(-not $script:canApply) {
    It '一个备份文件丢了：undo 报告这一步失败（退出码 1），其余步骤照样还原' {
        & reg.exe add 'HKCU\Software\wco-ci-vendor\P1' /v A /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add 'HKCU\Software\wco-ci-vendor\P2' /v A /t REG_DWORD /d 1 /f | Out-Null
        $s = New-Session
        Set-WcoRegistryValue -Key 'HKCU\Software\wco-ci-vendor\P1' -Name A -Value 9 -Apply | Out-Null
        Set-WcoRegistryValue -Key 'HKCU\Software\wco-ci-vendor\P2' -Name A -Value 9 -Apply | Out-Null
        $first = @(Get-ChildItem (Join-Path $s.Dir 'reg') -Filter *.reg | Sort-Object LastWriteTime)[0]
        Remove-Item -LiteralPath $first.FullName
        $r = Invoke-Undo (Export-WcoUndo)
        $r.Code | Should -Be 1
        $r.Output | Should -Match '失败 1 步'
        (Get-ItemProperty 'HKCU:\Software\wco-ci-vendor\P2').A | Should -Be 1
    }
    It '回收站策略不确定时拒绝而不是永久删除' {
        $f = Join-Path $script:root 'keep-me.txt'
        Set-Content -LiteralPath $f -Value 'x'
        $r = Invoke-WcoRecycle -Path $f -Apply
        if ($r.Status -ne 'Recycled') { $r.Status | Should -Be 'Blocked'; Test-Path -LiteralPath $f | Should -BeTrue }
    }
}
