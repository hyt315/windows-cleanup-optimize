# 模板 18：audit-resident-daemons（v2.1：直接运行即输出结果，纯只读）
# 用法：
#   .\t18-audit-resident-daemons.ps1
#   .\t18-audit-resident-daemons.ps1 -ServiceName 'YunDetectService','wpscloudsvr'
param(
    [string[]]$ServiceName = @('YunDetectService', 'XLServicePlatform', 'ThunderNetwork', 'wpscloudsvr', 'AlibabaProtect')
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Find-StubbornService {
    param([string[]]$Name)
    $found = 0
    foreach ($svc in @(Get-Service -Name $Name -EA SilentlyContinue)) {
        $found++
        $safeName = $svc.Name -replace "'", "''"
        $cim = Get-CimInstance Win32_Service -Filter "Name='$safeName'" -EA SilentlyContinue
        $startType = if ($cim) { $cim.StartMode } else { '?' }
        Write-Host ("[Daemon] 服务名: {0,-18} 状态: {1,-8} 启动类型: {2}" -f $svc.Name, $svc.Status, $startType)
        if ($cim -and $cim.PathName) {
            $exe = Resolve-ServiceExePath $cim.PathName
            $sig = Get-WcoFileSigner -Path $exe
            Write-Host ("         路径: {0}  签名: {1} ({2})" -f $exe, $sig.Organization, $sig.Status)
        }
    }
    if ($found -eq 0) { Write-Host '  （未发现目标常驻服务）' }
}

function Resolve-ServiceExePath {
    # 模块未导出 Resolve-WcoExecutablePath，这里做最小解析：去引号与参数
    param([string]$CommandLine)
    $c = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    if ($c.StartsWith('"')) { $end = $c.IndexOf('"', 1); if ($end -gt 1) { return $c.Substring(1, $end - 1) } }
    $m = [regex]::Match($c, '^(.+?\.exe)(?=\s|$)', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value }
    return $c
}

Write-Host '=== 顽固后台常驻服务审计（只读）==='
if ($env:OS -ne 'Windows_NT') { Write-Host '  仅支持 Windows，未检查。' -ForegroundColor Red } else { Find-StubbornService -Name $ServiceName }
