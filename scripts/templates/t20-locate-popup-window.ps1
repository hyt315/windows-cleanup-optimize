# 模板 20：locate-popup-window（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 20 节。

function Catch-ForegroundPopup {
    Add-Type @"
        using System; using System.Runtime.InteropServices;
        public class WindowHelper {
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        }
"@
    Write-Host "请在 3 秒内点击或切换到那个广告弹窗窗口..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
    $hwnd = [WindowHelper]::GetForegroundWindow()
    $pidRef = 0; [void][WindowHelper]::GetWindowThreadProcessId($hwnd, [ref]$pidRef)
    if ($pidRef -ne 0) {
        $proc = Get-Process -Id $pidRef -ErrorAction SilentlyContinue
        Write-Host "`n[抓捕成功！弹窗所属进程信息]：" -ForegroundColor Green
        Write-Host "  进程名: $($proc.Name)"
        Write-Host "  进程PID: $($proc.Id)"
        Write-Host "  程序路径: $($proc.Path)"
    } else {
        Write-Host "未能捕获到活动窗口，请重试。" -ForegroundColor Red
    }
}
