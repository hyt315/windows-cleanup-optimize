# Pester 5+ 单元测试：v2.1 新增的卸载、自启动开关与保护清单（纯函数，可在 Linux 的 PowerShell 7 上跑）。

BeforeAll {
    $modPath = Join-Path $PSScriptRoot '..\scripts\lib\Wco.Common.psm1'
    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        function global:Get-CimInstance { param($ClassName, $Filter, $ErrorAction) }
    }
    Import-Module $modPath -Force
}

Describe 'StartupApproved 字节编码' {
    It '启用写 02，禁用写 03 并带 FILETIME' {
        $on = ConvertTo-WcoStartupApprovedData -Enabled $true
        $off = ConvertTo-WcoStartupApprovedData -Enabled $false -Time ([datetime]'2026-11-11T08:00:00Z')
        $on.Length | Should -Be 12
        $on[0] | Should -Be 2
        $off[0] | Should -Be 3
        [BitConverter]::ToInt64($off, 4) | Should -BeGreaterThan 0
    }
    It '解读 02/06 为启用，03/07 为禁用，空值为默认启用' {
        (ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))).State | Should -Be 'Enabled'
        (ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]](6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))).Enabled | Should -BeTrue
        (ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))).State | Should -Be 'Disabled'
        (ConvertFrom-WcoStartupApprovedData -Bytes ([byte[]](7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))).Enabled | Should -BeFalse
        (ConvertFrom-WcoStartupApprovedData -Bytes $null).State | Should -Be 'Absent'
    }
    It '编码后再解读得到同样的状态' {
        (ConvertFrom-WcoStartupApprovedData -Bytes (ConvertTo-WcoStartupApprovedData -Enabled $false)).State | Should -Be 'Disabled'
        (ConvertFrom-WcoStartupApprovedData -Bytes (ConvertTo-WcoStartupApprovedData -Enabled $true)).State | Should -Be 'Enabled'
    }
}

Describe '注册表整键删除的保护清单' {
    It '拒绝 <Key>' -ForEach @(
        @{ Key = 'HKLM:\SOFTWARE' }
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows' }
        @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office' }
        @{ Key = 'HKLM:\SOFTWARE\Classes' }
        @{ Key = 'HKLM:\SOFTWARE\Policies' }
        @{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Foo' }
        @{ Key = 'HKCU:\Software\Kingsoft' }
        @{ Key = 'HKCU:\Software\Tencent' }
    ) {
        Test-WcoProtectedRegistryKey -Key $Key | Should -Not -BeNullOrEmpty
    }
    It '允许具体产品子键 <Key>' -ForEach @(
        @{ Key = 'HKCU:\Software\Kingsoft\Office' }
        @{ Key = 'HKLM:\SOFTWARE\WOW6432Node\2345Explorer' }
    ) {
        Test-WcoProtectedRegistryKey -Key $Key | Should -BeNullOrEmpty
    }
    It 'Remove-WcoRegistryKey 遇到保护键直接 Blocked，不触碰注册表' {
        (Remove-WcoRegistryKey -Path 'HKLM:\SOFTWARE\Microsoft' -Apply).Status | Should -Be 'Blocked'
    }
}

Describe '名称匹配：短名不做模糊匹配' {
    It '4 个字符以内只认完全相等' {
        Get-WcoNameMatch -Candidate 'QQ' -Target 'QQMusic' | Should -Be 'None'
        Get-WcoNameMatch -Candidate 'WPS' -Target 'WPS' | Should -Be 'Exact'
    }
    It '长名互相包含为 Fuzzy' {
        Get-WcoNameMatch -Candidate 'Ludashi' -Target 'Ludashi Hardware Monitor' | Should -Be 'Fuzzy'
    }
    It '不相关为 None' {
        Get-WcoNameMatch -Candidate 'Photoshop' -Target 'Thunder Speed' | Should -Be 'None'
    }
}

Describe '商店应用移除的保护' {
    It '只有通配符时拒绝' {
        (Remove-WcoAppxPackage -Name '*' -Apply).Status | Should -Be 'Blocked'
    }
}

Describe '流氓软件特征库' {
    It '能读取 data/bloatware-catalog.json 且家族 id 唯一' -Skip:(-not (Test-Path (Join-Path $PSScriptRoot '..\data\bloatware-catalog.json'))) {
        $cat = Get-WcoBloatwareCatalog
        @($cat.families).Count | Should -BeGreaterThan 10
        $ids = @($cat.families | ForEach-Object { $_.id })
        ($ids | Sort-Object -Unique).Count | Should -Be $ids.Count
    }
}
