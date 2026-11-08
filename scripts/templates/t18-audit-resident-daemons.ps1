# 模板 18：audit-resident-daemons（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 18 节。

function Audit-StubbornServices {
    $targetServices = @('YunDetectService', 'XLServicePlatform', 'ThunderNetwork', 'wpscloudsvr', 'AlibabaProtect')
    Get-Service -Name $targetServices -EA SilentlyContinue | ForEach-Object {
        $startType = (Get-CimInstance Win32_Service -Filter "Name='$($_.Name)'" -EA SilentlyContinue).StartMode
        Write-Host ("[Daemon] 服务名: {0,-18} 状态: {1,-8} 启动类型: {2}" -f $_.Name, $_.Status, $startType)
    }
}
