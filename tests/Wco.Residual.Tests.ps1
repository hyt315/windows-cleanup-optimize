# Pester 5+ 单元测试：v2.1.2 残留判定、路径包含的根目录保护、模板不再用 -Recurse 统计体积、full_scan 分段状态。
# 纯函数与静态检查，可在 Linux 的 PowerShell 7 上跑。

BeforeAll {
    $modPath = Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1'
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function global:Get-CimInstance { param($ClassName, $Filter, $ErrorAction) }
    }
    Import-Module $modPath -Force
    $script:repo = Join-Path $PSScriptRoot '..'
    $script:programs = @(
        [pscustomobject]@{ DisplayName = 'Tencent QQ'; Publisher = 'Tencent'; InstallLocation = 'C:\Program Files\Tencent\QQNT' }
        [pscustomobject]@{ DisplayName = 'Google Chrome'; Publisher = 'Google LLC'; InstallLocation = 'C:\Program Files\Google\Chrome\Application' }
        [pscustomobject]@{ DisplayName = 'Visual Studio Code'; Publisher = 'Microsoft Corporation'; InstallLocation = 'C:\Users\a\AppData\Local\Programs\Microsoft VS Code\' }
        [pscustomobject]@{ DisplayName = 'Broken Installer'; Publisher = 'Nobody'; InstallLocation = 'C:\' }
        [pscustomobject]@{ DisplayName = 'Notepad++ (64-bit x64)'; Publisher = 'Notepad++ Team'; InstallLocation = '' }
    )
    $script:index = Get-WcoInstalledIndex -Program $script:programs -ExtraName @('JetBrains Toolbox')
}

Describe 'Test-WcoPathUnder 根目录保护' {
    It '<Child> 在 <Parent> 之下 = <Expected>' -ForEach @(
        @{ Child = 'C:\Program Files\Foo\bin\a.exe'; Parent = 'C:\Program Files\Foo'; Expected = $true }
        @{ Child = 'C:\Program Files\Foo'; Parent = 'C:\Program Files\Foo\'; Expected = $true }
        @{ Child = 'c:/program files/foo/a.exe'; Parent = '"C:\Program Files\Foo"'; Expected = $true }
        @{ Child = 'C:\Program Files\FooBar\a.exe'; Parent = 'C:\Program Files\Foo'; Expected = $false }
        @{ Child = 'C:\Windows\System32\svchost.exe'; Parent = 'C:\'; Expected = $false }
        @{ Child = 'C:\Windows\System32\svchost.exe'; Parent = 'C:'; Expected = $false }
        @{ Child = 'D:\Games\x.exe'; Parent = 'd:\'; Expected = $false }
        @{ Child = '\\srv\share\app\x.exe'; Parent = '\\srv\share'; Expected = $false }
        @{ Child = '\\srv\share\app\x.exe'; Parent = '\\srv\share\app'; Expected = $true }
        @{ Child = 'C:\a'; Parent = ''; Expected = $false }
    ) {
        Test-WcoPathUnder $Child $Parent | Should -Be $Expected
    }
}

Describe 'Get-WcoResidualStatus（T3/T4/full_scan 共用）' {
    It '名称比对从不给 🟢：<Name>' -ForEach @(
        @{ Name = 'Go' }, @{ Name = 'QQ' }, @{ Name = 'SomeRemovedApp' }, @{ Name = 'Google' }, @{ Name = '' + [char]0x2603 }
        @{ Name = 'Code' }, @{ Name = 'Tencent' }, @{ Name = 'npm' }, @{ Name = '12345' }
    ) {
        $st = Get-WcoResidualStatus -Name $Name -Path "D:\Apps\$Name" -Index $script:index
        $st.Level | Should -BeIn @('✅', '🟡')
        $st.Status | Should -BeIn @('Installed', 'Suspect')
    }
    It '短名不做子串匹配：Go 不因 Google Chrome 算在用' {
        (Get-WcoResidualStatus -Name 'Go' -Path 'C:\Go' -Index $script:index).Status | Should -Be 'Suspect'
    }
    It '短名完全相等仍算在用：Tencent 发布者目录' {
        (Get-WcoResidualStatus -Name 'Tencent' -Path 'D:\Tencent' -Index $script:index).Status | Should -Be 'Installed'
    }
    It '已安装程序的 InstallLocation 在目录内 → 在用（名称对不上也算）' {
        (Get-WcoResidualStatus -Name 'Application' -Path 'C:\Program Files\Google\Chrome\Application' -Index $script:index).Status | Should -Be 'Installed'
        (Get-WcoResidualStatus -Name 'Weird' -Path 'C:\Program Files\Google' -Index $script:index).Status | Should -Be 'Installed'
    }
    It 'InstallLocation 写成 C:\ 不会让任意目录都算在用' {
        (Get-WcoResidualStatus -Name 'OldTool2019' -Path 'C:\OldTool2019' -Index $script:index).Status | Should -Be 'Suspect'
    }
    It '运行中进程来自该目录 → 在用' {
        (Get-WcoResidualStatus -Name 'PortableThing' -Path 'D:\PortableThing' -Index $script:index -RunningPath @('D:\PortableThing\bin\pt.exe')).Status | Should -Be 'Installed'
    }
    It '规范化后相等：去掉版本、位数、括号' {
        (Get-WcoResidualStatus -Name 'Notepad++' -Path 'D:\Notepad++' -Index $script:index).Status | Should -Be 'Installed'
    }
    It '长名互相包含算在用；开始菜单名也参与比对' {
        (Get-WcoResidualStatus -Name 'JetBrains' -Path 'D:\JetBrains' -Index $script:index).Status | Should -Be 'Installed'
        (Get-WcoResidualStatus -Name 'Microsoft VS Code' -Path 'D:\x\Microsoft VS Code' -Index $script:index).Status | Should -Be 'Installed'
    }
    It '索引不把盘符根当目录名' {
        $script:index.Keys.ContainsKey('c') | Should -BeFalse
        $script:index.Locations | Should -Contain 'C:\Program Files\Tencent\QQNT'
    }
}

Describe '模板与 full_scan 静态检查' {
    It '<File> 不再用 Get-ChildItem -Recurse 统计体积，改用 Measure-WcoDirectory' -ForEach @(
        @{ File = 't01-scan-user-profile.ps1' }, @{ File = 't02-scan-nonsystem-drive.ps1' }, @{ File = 't03-detect-roaming-leftovers.ps1' }
        @{ File = 't05-detect-updater-leftovers.ps1' }, @{ File = 't17-detect-ai-model-caches.ps1' }
    ) {
        $text = Get-Content -LiteralPath (Join-Path $script:repo "scripts/templates/$File") -Raw -Encoding UTF8
        $text | Should -Match 'Measure-WcoDirectory'
        $text | Should -Not -Match 'Measure-Object\s+Length'
    }
    It 'T3/T4 走公共判定，名称比对的结果不进 🟢' {
        foreach ($f in 't03-detect-roaming-leftovers.ps1', 't04-detect-install-dir-leftovers.ps1') {
            $text = Get-Content -LiteralPath (Join-Path $script:repo "scripts/templates/$f") -Raw -Encoding UTF8
            $text | Should -Match 'Get-WcoResidualStatus'
            $text | Should -Not -Match '🟢'
        }
        $fs = Get-Content -LiteralPath (Join-Path $script:repo 'scripts/full_scan.ps1') -Raw -Encoding UTF8
        $fs | Should -Not -Match "Add-Finding 'T[34]'[^\r\n]*'🟢'"
        $fs | Should -Match 'Get-WcoResidualStatus'
    }
    It 'full_scan 每个 [Txx] 段都登记分段状态，并输出 [CHK]' {
        $fs = Get-Content -LiteralPath (Join-Path $script:repo 'scripts/full_scan.ps1') -Raw -Encoding UTF8
        $heads = [regex]::Matches($fs, "# ===== \[([A-Z0-9/]+)\][^\r\n]*\r?\nEnter-ScanSection '([A-Z0-9/]+)'")
        $all = [regex]::Matches($fs, '# ===== \[([A-Z0-9/]+)\]')
        $heads.Count | Should -Be $all.Count
        foreach ($h in $heads) { $h.Groups[1].Value | Should -Be $h.Groups[2].Value }
        $fs | Should -Match '\[CHK\]'
    }
}
