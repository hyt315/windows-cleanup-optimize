# Pester 5+ 单元测试（v2.2.1）：逐条守住写操作的拒绝条件与检测规则。
# 每条用例只让一个条件不满足、其余条件都设成「安全」，这样某条检查被关掉时，对应用例一定失败。
# 负对照清单见 tests/negative_controls.json，运行 python tests/negative_controls.py 验证。
# 可在 Linux 的 PowerShell 7 上跑：碰系统的原子函数（注册表、服务、计划任务、Appx）全部 Mock。

BeforeAll {
    $modPath = Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1'
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function global:Get-CimInstance { param($ClassName, $Filter, $ErrorAction) }
    }
    Import-Module $modPath -Force
    if (-not $env:TEMP) { $env:TEMP = [IO.Path]::GetTempPath() }
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ('wco_guard_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tmp | Out-Null
    $script:safePolicy = { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $false; MaxCapacityMB = 102400; Known = $true; PolicyOverride = $false; Reason = '' } }
}

AfterAll {
    Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Describe '回收站：每个拒绝条件单独成立' {
    BeforeEach {
        $script:f = Join-Path $script:tmp ('f_' + [guid]::NewGuid().ToString('N') + '.bin')
        [IO.File]::WriteAllBytes($script:f, (New-Object byte[] 1024))
    }
    It '对照：条件全部安全时演练通过（证明下面的拒绝不是别的条件造成的）' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy $script:safePolicy
        (Invoke-WcoRecycle -Path $script:f).Status | Should -Be 'DryRun'
    }
    It '卷没有回收站（策略其余项都正常）→ 拒绝' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $false; NukeOnDelete = $false; MaxCapacityMB = 102400; Known = $true; PolicyOverride = $false; Reason = '卷类型为 Removable，没有回收站' } }
        $r = Invoke-WcoRecycle -Path $script:f -Apply
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match '永久删除'
        Test-Path -LiteralPath $script:f | Should -BeTrue
    }
    It '组策略接管回收站 → 拒绝' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $false; MaxCapacityMB = 102400; Known = $true; PolicyOverride = $true; Reason = 'RecycleBinSize' } }
        $r = Invoke-WcoRecycle -Path $script:f -Apply
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match '组策略'
    }
    It '目录内有超长路径 → 跳过，不执行' {
        $d = Join-Path $script:tmp ('d_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $d | Out-Null
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy $script:safePolicy
        Mock -ModuleName Wco.Common Measure-WcoDirectory { [pscustomobject]@{ Exists = $true; Bytes = 1024; Files = 1; Errors = 0; LongPath = 2 } }
        $r = Invoke-WcoRecycle -Path $d -Apply
        $r.Status | Should -Be 'LongPath'
        Test-Path -LiteralPath $d | Should -BeTrue
    }
    It 'junction/符号链接本身 → 拒绝（策略安全时也一样）' -Skip:(-not (($env:OS -eq 'Windows_NT') -or $IsWindows -or (Get-Command ln -ErrorAction SilentlyContinue))) {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy $script:safePolicy
        $target = Join-Path $script:tmp ('t_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $target | Out-Null
        $link = Join-Path $script:tmp ('l_' + [guid]::NewGuid().ToString('N'))
        $type = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $type -Path $link -Target $target | Out-Null
        $r = Invoke-WcoRecycle -Path $link -Apply
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match 'junction'
    }
    It '路径经过 junction（上级目录是链接）→ 拒绝，因为实际所在卷可能不是盘符那个' -Skip:(-not (($env:OS -eq 'Windows_NT') -or $IsWindows -or (Get-Command ln -ErrorAction SilentlyContinue))) {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy $script:safePolicy
        $target = Join-Path $script:tmp ('t_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $target | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $target 'cache.bin'), (New-Object byte[] 16))
        $link = Join-Path $script:tmp ('中文 链接_' + [guid]::NewGuid().ToString('N'))
        $type = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $type -Path $link -Target $target | Out-Null
        $r = Invoke-WcoRecycle -Path (Join-Path $link 'cache.bin') -Apply
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match '经过 junction'
        Test-Path -LiteralPath (Join-Path $target 'cache.bin') | Should -BeTrue
    }
    It '普通目录（含中文和空格）不会被误判为经过链接' {
        $d = Join-Path $script:tmp '用户 数据\缓存'
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Get-WcoReparseAncestor -Path (Join-Path $d 'a.bin') | Should -BeNullOrEmpty
    }
}

Describe '服务：拒绝条件' {
    It '受保护服务不允许改成 disabled（演练阶段就拒绝）' {
        Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'WinDefend'; StartMode = 'Auto'; DelayedAutoStart = $false } }
        (Set-WcoServiceStartType -Name 'WinDefend' -StartType disabled).Status | Should -Be 'Blocked'
    }
    It '对照：普通第三方服务可以演练' {
        Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'FooUpdate'; StartMode = 'Auto'; DelayedAutoStart = $false } }
        (Set-WcoServiceStartType -Name 'FooUpdate' -StartType disabled).Status | Should -Be 'DryRun'
    }
    Context 'Remove-WcoService' {
        BeforeEach {
            Mock -ModuleName Wco.Common Get-WcoFileSigner { [pscustomobject]@{ Status = 'Valid'; Organization = 'Foo Ltd'; IsMicrosoft = $false } }
            Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'FooSvc'; PathName = '"D:\Foo\foo svc.exe" -run'; State = 'Stopped'; StartMode = 'Disabled' } }
        }
        It '对照：已停用的第三方服务可以演练删除' {
            (Remove-WcoService -Name 'FooSvc').Status | Should -Be 'DryRun'
        }
        It '受保护服务 → 拒绝（不论状态）' {
            Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'wuauserv'; PathName = 'D:\x\x.exe'; State = 'Stopped'; StartMode = 'Disabled' } }
            (Remove-WcoService -Name 'wuauserv').Status | Should -Be 'Blocked'
        }
        It 'svchost 承载的共享服务 → 拒绝' {
            Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'FooSvc'; PathName = 'C:\Windows\system32\svchost.exe -k netsvcs -p'; State = 'Stopped'; StartMode = 'Disabled' } }
            $r = Remove-WcoService -Name 'FooSvc'
            $r.Status | Should -Be 'Blocked'
            $r.Reason | Should -Match 'svchost'
        }
        It '微软签名的服务 → 拒绝' {
            Mock -ModuleName Wco.Common Get-WcoFileSigner { [pscustomobject]@{ Status = 'Valid'; Organization = 'Microsoft Corporation'; IsMicrosoft = $true } }
            $r = Remove-WcoService -Name 'FooSvc'
            $r.Status | Should -Be 'Blocked'
            $r.Reason | Should -Match 'Microsoft'
        }
        It '还在运行或未禁用 → 拒绝，要求先停用观察' {
            Mock -ModuleName Wco.Common Get-WcoServiceInfo { [pscustomobject]@{ Name = 'FooSvc'; PathName = 'D:\Foo\foo.exe'; State = 'Running'; StartMode = 'Auto' } }
            (Remove-WcoService -Name 'FooSvc').Status | Should -Be 'Blocked'
        }
    }
}

Describe '注册表：先备份、备份失败就不动' {
    BeforeEach {
        Mock -ModuleName Wco.Common Test-WcoAdmin { $true }
        Mock -ModuleName Wco.Common Test-WcoRegKey { $true }
        Mock -ModuleName Wco.Common Export-WcoRegKey { $false }
        Mock -ModuleName Wco.Common Remove-WcoRegKeyRaw { }
        Mock -ModuleName Wco.Common Set-WcoRegValueRaw { }
        Mock -ModuleName Wco.Common Get-WcoRegValue { [pscustomobject]@{ Exists = $true; Value = 1; Kind = 'DWord' } }
        InModuleScope Wco.Common -Parameters @{ root = $script:tmp } { param($root) Start-WcoSession -Root $root | Out-Null }
    }
    It '整键删除：reg export 失败 → Error，且没有删除' {
        $r = Remove-WcoRegistryKey -Path 'HKCU\Software\FooVendor\FooApp' -Apply
        $r.Status | Should -Be 'Error'
        Should -Invoke -ModuleName Wco.Common Remove-WcoRegKeyRaw -Times 0
    }
    It '改值：reg export 失败 → Error，且没有写入' {
        $r = Set-WcoRegistryValue -Key 'HKCU\Software\FooVendor\FooApp' -Name 'X' -Value 0 -Apply
        $r.Status | Should -Be 'Error'
        Should -Invoke -ModuleName Wco.Common Set-WcoRegValueRaw -Times 0
    }
}

Describe '计划任务、商店应用、卸载：拒绝条件' {
    It '\Microsoft\ 下的计划任务不允许删除' {
        Mock -ModuleName Wco.Common Get-WcoScheduledTaskRaw { [pscustomobject]@{ TaskName = 'X'; State = 'Ready' } }
        (Remove-WcoScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName 'ScheduledDefrag').Status | Should -Be 'Blocked'
    }
    It '对照：第三方计划任务可以演练删除' {
        Mock -ModuleName Wco.Common Get-WcoScheduledTaskRaw { [pscustomobject]@{ TaskName = 'FooUpdate'; State = 'Ready' } }
        (Remove-WcoScheduledTask -TaskPath '\' -TaskName 'FooUpdate').Status | Should -Be 'DryRun'
    }
    It '商店必需组件不允许移除' {
        Mock -ModuleName Wco.Common Get-WcoAppxRaw { @([pscustomobject]@{ Name = 'Microsoft.WindowsStore'; PackageFullName = 'Microsoft.WindowsStore_1_x64__8wekyb3d8bbwe'; IsFramework = $false; NonRemovable = $false; SignatureKind = 'Store' }) }
        (Remove-WcoAppxPackage -Name 'Microsoft.WindowsStore').Status | Should -Be 'Blocked'
    }
    It '通配符匹配到过多包 → 拒绝' {
        Mock -ModuleName Wco.Common Get-WcoAppxRaw { 1..6 | ForEach-Object { [pscustomobject]@{ Name = "Contoso.App$_"; PackageFullName = "Contoso.App$_`_1_x64__abc"; IsFramework = $false; NonRemovable = $false; SignatureKind = 'Store' } } }
        (Remove-WcoAppxPackage -Name 'Contoso.*').Status | Should -Be 'Blocked'
    }
    It '对照：普通商店应用可以演练移除' {
        Mock -ModuleName Wco.Common Get-WcoAppxRaw { @([pscustomobject]@{ Name = 'Contoso.Game'; PackageFullName = 'Contoso.Game_1_x64__abc'; IsFramework = $false; NonRemovable = $false; SignatureKind = 'Store' }) }
        (Remove-WcoAppxPackage -Name 'Contoso.Game').Status | Should -Be 'DryRun'
    }
    It 'UninstallString 指向网页 → 拒绝（卸载陷阱）' {
        Mock -ModuleName Wco.Common Get-WcoInstalledProgram { [pscustomobject]@{ DisplayName = 'Foo'; UninstallString = 'https://foo.example/uninstall'; WindowsInstaller = $false; ProductCode = $null; SystemComponent = $false; Scope = 'HKCU'; DisplayVersion = '1' } }
        $r = Invoke-WcoUninstall -Name 'Foo'
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match '网页'
    }
    It '隐藏的系统组件 → 拒绝' {
        Mock -ModuleName Wco.Common Get-WcoInstalledProgram { [pscustomobject]@{ DisplayName = 'Foo Helper'; UninstallString = 'msiexec /x {11111111-1111-1111-1111-111111111111}'; WindowsInstaller = $true; ProductCode = '{11111111-1111-1111-1111-111111111111}'; SystemComponent = $true; Scope = 'HKLM'; DisplayVersion = '1' } }
        (Invoke-WcoUninstall -Name 'Foo Helper').Status | Should -Be 'Blocked'
    }
}

Describe '残留判定与名称规范化' {
    It '短名已安装（QQ）不会让长名目录（QQMusicData）算作在用' {
        $idx = Get-WcoInstalledIndex -Program @([pscustomobject]@{ DisplayName = 'QQ'; Publisher = ''; InstallLocation = '' })
        (Get-WcoResidualStatus -Name 'QQMusicData' -Path 'D:\QQMusicData' -Index $idx).Status | Should -Be 'Suspect'
    }
    It '<Raw> 规范化为 <Key>（中英混排、版本号贴着汉字或字母）' -ForEach @(
        @{ Raw = '微信4.1.0.34'; Key = '微信' }
        @{ Raw = '微信64位'; Key = '微信' }
        @{ Raw = '钉钉v7.6.5'; Key = '钉钉' }
        @{ Raw = 'QQ9.9.15'; Key = 'qq' }
        @{ Raw = '百度网盘 7.40.0'; Key = '百度网盘' }
        @{ Raw = '7-Zip 24.08 (x64)'; Key = '7zip' }
        @{ Raw = 'Tencent Co., Ltd.'; Key = 'tencent' }
    ) {
        InModuleScope Wco.Common -Parameters @{ raw = $Raw } { param($raw) Get-WcoNameKey $raw } | Should -Be $Key
    }
    It '规范化不吃掉名字里本来的数字和字母：<Raw>' -ForEach @(
        @{ Raw = 'x264vfw'; Key = 'x264vfw' }
        @{ Raw = 'WPS Office 2024'; Key = 'wpsoffice2024' }
        @{ Raw = 'Incredibuild'; Key = 'incredibuild' }
        @{ Raw = 'Linc Corp'; Key = 'linc' }
    ) {
        InModuleScope Wco.Common -Parameters @{ raw = $Raw } { param($raw) Get-WcoNameKey $raw } | Should -Be $Key
    }
    It '带版本号的中文显示名与目录名能对上（旧版会把装着的微信当成疑似残留）' {
        $idx = Get-WcoInstalledIndex -Program @([pscustomobject]@{ DisplayName = '微信4.1.0.34'; Publisher = '腾讯科技(深圳)有限公司'; InstallLocation = '' })
        (Get-WcoResidualStatus -Name '微信' -Path 'D:\微信' -Index $idx).Status | Should -Be 'Installed'
    }
}

Describe '特征库比对 Get-WcoCatalogHit' {
    BeforeAll {
        $script:cat = [pscustomobject]@{ families = @(
                [pscustomobject]@{ id = 'fam-a'; name = '甲家族'; confidence = 'high'; processes = @('FooTray.exe', 'FooPop'); services = @('FooSvc'); tasks = @('\FooUpdate*') }
                [pscustomobject]@{ id = 'fam-q'; name = 'Q 家族'; confidence = 'low'; processes = @('QQ') }
            ) }
    }
    It '命中：进程（去掉 .exe）、服务、任务通配，并带置信度' {
        $p = @([pscustomobject]@{ ProcessName = 'FooTray'; Path = 'D:\Foo\FooTray.exe'; WorkingSet64 = 10MB }, [pscustomobject]@{ ProcessName = 'FooTray'; Path = 'D:\Foo\FooTray.exe'; WorkingSet64 = 10MB })
        $s = @([pscustomobject]@{ Name = 'FooSvc'; DisplayName = 'Foo'; State = 'Running'; StartMode = 'Auto'; PathName = 'D:\Foo\svc.exe' })
        $t = @([pscustomobject]@{ TaskPath = '\'; TaskName = 'FooUpdateTaskMachine'; State = 'Ready'; Actions = @([pscustomobject]@{ Execute = 'D:\Foo\up.exe'; Arguments = '/c' }) })
        $h = @(Get-WcoCatalogHit -Catalog $script:cat -Process $p -Service $s -Task $t)
        $h.Count | Should -Be 3
        ($h | Where-Object Kind -eq '进程').Count | Should -Be 2
        ($h | Where-Object Kind -eq '进程').MemoryMB | Should -Be 20
        $h[0].Confidence | Should -Be 'high'
    }
    It '不误报：名字只是包含特征（QQMusic、FooTrayHelper）不算命中' {
        $p = @([pscustomobject]@{ ProcessName = 'QQMusic'; Path = ''; WorkingSet64 = 1 }, [pscustomobject]@{ ProcessName = 'FooTrayHelper'; Path = ''; WorkingSet64 = 1 })
        @(Get-WcoCatalogHit -Catalog $script:cat -Process $p).Count | Should -Be 0
    }
    It '白名单里的名称跳过' {
        $p = @([pscustomobject]@{ ProcessName = 'FooPop'; Path = ''; WorkingSet64 = 1 })
        @(Get-WcoCatalogHit -Catalog $script:cat -Process $p -Whitelist @('FooPop')).Count | Should -Be 0
    }
    It 'low 置信度的家族标成「疑似」' {
        $p = @([pscustomobject]@{ ProcessName = 'QQ'; Path = ''; WorkingSet64 = 1 })
        (Get-WcoCatalogHit -Catalog $script:cat -Process $p)[0].Level | Should -Match '疑似'
    }
}

Describe '台账与 undo.ps1' {
    It '只有一条变更时台账也是 JSON 数组' {
        InModuleScope Wco.Common -Parameters @{ root = $script:tmp } {
            param($root)
            $s = Start-WcoSession -Root $root
            Add-WcoChange -Kind other -Target 'only' -Undo 'Write-Output 1' | Out-Null
            (Get-Content -LiteralPath $s.Ledger -Raw).TrimStart() | Should -Match '^\['
        }
    }
    It '某一步还原失败时继续执行其余步骤，最后列出失败并以退出码 1 结束' {
        $undo = InModuleScope Wco.Common -Parameters @{ root = $script:tmp } {
            param($root)
            Start-WcoSession -Root $root | Out-Null
            Add-WcoChange -Kind other -Target 'first-ok' -Undo '$null = 1' | Out-Null
            Add-WcoChange -Kind other -Target 'throws' -Undo 'throw "boom"' | Out-Null
            Add-WcoChange -Kind other -Target 'exit-code' -Undo '& pwsh -NoProfile -NonInteractive -Command "exit 3"' | Out-Null
            Export-WcoUndo
        }
        $out = & pwsh -NoProfile -NonInteractive -File $undo 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $out | Should -Match '成功 1 步，失败 2 步'
        $out | Should -Match 'throws'
        $out | Should -Match '退出码 3'
    }
    It '全部成功时退出码 0，且可以重复运行' {
        $undo = InModuleScope Wco.Common -Parameters @{ root = $script:tmp } {
            param($root)
            Start-WcoSession -Root $root | Out-Null
            Add-WcoChange -Kind other -Target 'ok' -Undo '$null = 1' | Out-Null
            Export-WcoUndo
        }
        & pwsh -NoProfile -NonInteractive -File $undo | Out-Null
        $LASTEXITCODE | Should -Be 0
        & pwsh -NoProfile -NonInteractive -File $undo | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
    It '服务名带空格时 undo 命令仍是一个参数' {
        InModuleScope Wco.Common { ConvertTo-WcoPsLiteral 'Foo Bar' } | Should -Be "'Foo Bar'"
        $src = Get-Content (Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1') -Raw
        $src | Should -Match 'sc\.exe config \$\(ConvertTo-WcoPsLiteral \$Name\) start= \$before'
    }
}
