# 模板 19：audit-wmi-lnk-hijack（v2.1：直接运行即输出结果，纯只读）
# 用法：.\t19-audit-wmi-lnk-hijack.ps1    （WMI 部分需管理员；非管理员时明确报"查询失败"，不会误报干净）
# v2.1：WMI 查全四类（__EventFilter、CommandLineEventConsumer、ActiveScriptEventConsumer、__FilterToConsumerBinding）；
#       快捷方式检查覆盖桌面、开始菜单、任务栏固定和桌面 .url，命中标"待核实"（PWA 的 --app= 也会列出）。
#       发现项只列出，不自动删除（删除 WMI 订阅不可逆，需逐项人工确认）。
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Find-HiddenPersistence {
    Write-Host "=== WMI 永久事件订阅（隐蔽自启动）==="
    $wmi = Get-WcoWmiSubscription
    if ($wmi.Status -eq 'Unsupported') {
        Write-Host ("  未检查：{0}" -f $wmi.Message) -ForegroundColor Yellow
    } elseif ($wmi.Status -ne 'OK') {
        Write-Host ("  查询失败（需管理员）：{0}" -f $wmi.Message) -ForegroundColor Yellow
        Write-Host '  请以管理员身份重新运行本脚本；在此之前不能认为 WMI 是干净的。'
    } else {
        $suspect = @($wmi.Items | Where-Object { -not $_.KnownDefault })
        $wmi.Items | Where-Object { $_.KnownDefault } | ForEach-Object {
            Write-Host ("  [系统自带] {0}: {1}" -f $_.Class, $_.Name)
        }
        if ($suspect.Count -gt 0) {
            $suspect | ForEach-Object {
                Write-Host ("[WMI 待核实] {0}: {1} -> {2}" -f $_.Class, $_.Name, $_.Detail) -ForegroundColor Red
            }
        } else {
            Write-Host "  （四类均已查询，无第三方 WMI 事件订阅）"
        }
    }

    Write-Host "`n=== 快捷方式 (.lnk/.url) 网址劫持排查 ==="
    $hits = @(Get-WcoShortcutArgument)
    foreach ($h in $hits) {
        Write-Host ("[{0}] {1} -> 目标: {2} 参数: {3}" -f $h.Flag, $h.Path, $h.Target, $h.Arguments) -ForegroundColor Red
    }
    if ($hits.Count -eq 0) { Write-Host "  （未发现快捷方式被追加网址参数）" }
}

Find-HiddenPersistence
