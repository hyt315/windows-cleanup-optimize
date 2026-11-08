# 模板 19：audit-wmi-lnk-hijack（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 19 节。

function Audit-HiddenPersistence {
    Write-Host "=== WMI 隐蔽自启动事件消费者 ==="
    $wmiConsumers = Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer -EA SilentlyContinue
    if ($wmiConsumers) {
        $wmiConsumers | ForEach-Object {
            Write-Host ("[WMI] 名称: {0} -> 执行: {1}" -f $_.Name, $_.CommandLineTemplate) -ForegroundColor Red
        }
    } else {
        Write-Host "  （无第三方 WMI 事件消费者，系统干净）"
    }

    Write-Host "`n=== 浏览器快捷方式 (.lnk) 网址劫持排查 ==="
    $shell = New-Object -ComObject WScript.Shell
    $dirs = @("$env:USERPROFILE\Desktop", "$env:PUBLIC\Desktop", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
    $foundHijack = $false
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            Get-ChildItem $d -Filter "*.lnk" -Recurse -EA SilentlyContinue | ForEach-Object {
                $lnk = $shell.CreateShortcut($_.FullName)
                if ($lnk.TargetPath -match 'chrome\.exe|msedge\.exe|firefox\.exe|360se\.exe' -and $lnk.Arguments -match 'http|\.com|\.cn|\.html') {
                    Write-Host ("[劫持警告] {0} -> 目标: {1} 参数: {2}" -f $_.Name, $lnk.TargetPath, $lnk.Arguments) -ForegroundColor Red
                    $foundHijack = $true
                }
            }
        }
    }
    if (-not $foundHijack) { Write-Host "  （未发现浏览器快捷方式被恶意追加参数）" }
}
