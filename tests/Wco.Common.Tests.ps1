# Pester 5+ 单元测试：scripts/lib/Wco.Common.psm1
# 运行：Invoke-Pester ./tests -Output Detailed
# 可在 Linux/macOS 的 PowerShell 7 上跑（Windows 专属调用均被 Mock）。

BeforeAll {
    $modPath = Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1'
    # 非 Windows 上没有 Get-CimInstance，放一个空壳供 Mock
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function global:Get-CimInstance { param($ClassName, $Filter, $ErrorAction) }
    }
    Import-Module $modPath -Force
    $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("wco_test_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tmp | Out-Null
    if (-not $env:TEMP) { $env:TEMP = [IO.Path]::GetTempPath() }
}

AfterAll {
    Remove-Item -LiteralPath $script:tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Describe '变更留痕与 undo 生成' {
    It '按执行的相反顺序写 undo，且文件带 UTF-8 BOM' {
        InModuleScope Wco.Common -Parameters @{ root = $script:tmp } {
            param($root)
            $s = Start-WcoSession -Root $root
            Add-WcoChange -Kind service -Target 'SvcA' -Before 'demand' -After 'disabled' -Undo 'sc.exe config SvcA start= demand' | Out-Null
            Add-WcoChange -Kind service -Target 'SvcB' -Before 'delayed-auto' -After 'disabled' -Undo 'sc.exe config SvcB start= delayed-auto' | Out-Null
            $undo = Export-WcoUndo
            $bytes = [IO.File]::ReadAllBytes($undo)
            $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
            $text = [IO.File]::ReadAllText($undo)
            $text.IndexOf('SvcB start= delayed-auto') | Should -BeLessThan $text.IndexOf('SvcA start= demand')
            (Get-Content $s.Ledger -Raw | ConvertFrom-Json).Count | Should -Be 2
        }
    }

    It '无法自动回退的变更在 undo 里写明原因' {
        InModuleScope Wco.Common -Parameters @{ root = $script:tmp } {
            param($root)
            Start-WcoSession -Root $root | Out-Null
            Add-WcoChange -Kind recycle -Target 'X' -Note '从回收站还原' | Out-Null
            (Get-Content (Export-WcoUndo) -Raw) | Should -Match '无法自动回退：从回收站还原'
        }
    }
}

Describe 'Invoke-WcoRecycle 预检' {
    BeforeEach {
        $script:f = Join-Path $script:tmp ("f_" + [guid]::NewGuid().ToString('N') + '.bin')
        [IO.File]::WriteAllBytes($script:f, (New-Object byte[] 2048))
    }

    It '路径不存在时跳过' {
        (Invoke-WcoRecycle -Path (Join-Path $script:tmp 'nope')).Status | Should -Be 'Skip'
    }

    It '卷没有回收站时拒绝（避免变成永久删除）' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $false; NukeOnDelete = $null; MaxCapacityMB = $null; Known = $false; Reason = '卷类型为 Removable，没有回收站' } }
        $r = Invoke-WcoRecycle -Path $script:f -Apply
        $r.Status | Should -Be 'Blocked'
        Test-Path $script:f | Should -BeTrue
    }

    It '回收站设为直接删除时拒绝' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $true; MaxCapacityMB = 10240; Known = $true; Reason = '' } }
        (Invoke-WcoRecycle -Path $script:f -Apply).Status | Should -Be 'Blocked'
    }

    It '体积超过回收站上限时拒绝' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $false; MaxCapacityMB = 1; Known = $true; Reason = '' } }
        Mock -ModuleName Wco.Common Get-WcoItemSizeMB { 5 }
        $r = Invoke-WcoRecycle -Path $script:f -Apply
        $r.Status | Should -Be 'Blocked'
        $r.Reason | Should -Match '超过回收站上限'
    }

    It '上限未知且大于 1 GB 时拒绝' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $null; MaxCapacityMB = $null; Known = $false; Reason = '未找到' } }
        Mock -ModuleName Wco.Common Get-WcoItemSizeMB { 2048 }
        (Invoke-WcoRecycle -Path $script:f -Apply).Status | Should -Be 'Blocked'
    }

    It '不加 -Apply 只演练，不动文件' {
        Mock -ModuleName Wco.Common Get-WcoRecycleBinPolicy { [pscustomobject]@{ HasRecycleBin = $true; NukeOnDelete = $false; MaxCapacityMB = 10240; Known = $true; Reason = '' } }
        (Invoke-WcoRecycle -Path $script:f).Status | Should -Be 'DryRun'
        Test-Path $script:f | Should -BeTrue
    }

    It 'junction / 符号链接直接拒绝' -Skip:($IsWindows -eq $false -and -not (Get-Command ln -ErrorAction SilentlyContinue)) {
        $target = Join-Path $script:tmp ('t_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $target | Out-Null
        $link = Join-Path $script:tmp ('l_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
        (Invoke-WcoRecycle -Path $link -Apply).Status | Should -Be 'Blocked'
        Test-Path $target | Should -BeTrue
    }
}

Describe 'Set-WcoServiceStartType 记原值' {
    It '原值为自动(延迟启动)时演练结果显示 delayed-auto，而不是 auto' {
        Mock -ModuleName Wco.Common Get-CimInstance { [pscustomobject]@{ StartMode = 'Auto'; DelayedAutoStart = $true } }
        $r = Set-WcoServiceStartType -Name 'Foo' -StartType disabled
        $r.Status | Should -Be 'DryRun'
        $r.Before | Should -Be 'delayed-auto'
    }

    It '原值为手动时显示 demand' {
        Mock -ModuleName Wco.Common Get-CimInstance { [pscustomobject]@{ StartMode = 'Manual'; DelayedAutoStart = $false } }
        (Set-WcoServiceStartType -Name 'Foo' -StartType disabled).Before | Should -Be 'demand'
    }

    It '服务不存在时跳过' {
        Mock -ModuleName Wco.Common Get-CimInstance { $null }
        (Set-WcoServiceStartType -Name 'Nope' -StartType disabled).Status | Should -Be 'Skip'
    }
}
