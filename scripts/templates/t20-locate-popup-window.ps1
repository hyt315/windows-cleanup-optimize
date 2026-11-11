# 模板 20：locate-popup-window（v2.1：直接运行即开始抓取，纯只读）
# 用法：
#   .\t20-locate-popup-window.ps1                   # 3 秒内切到弹窗
#   .\t20-locate-popup-window.ps1 -DelaySeconds 5
# 注意：只能抓到"前台"窗口；通知中心的 toast、不抢焦点的弹窗不会成为前台窗口，抓到的可能是别的程序。
param(
    [ValidateRange(1, 60)][int]$DelaySeconds = 3
)

function Watch-ForegroundPopup {
    param([int]$Delay = 3)
    # 同一会话重复运行时类型已存在，再次 Add-Type 会报错
    if (-not ('WindowHelper' -as [type])) {
        Add-Type @"
        using System; using System.Runtime.InteropServices;
        public class WindowHelper {
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        }
"@
    }
    Write-Host "请在 $Delay 秒内点击或切换到那个广告弹窗窗口..." -ForegroundColor Cyan
    Start-Sleep -Seconds $Delay
    $hwnd = [WindowHelper]::GetForegroundWindow()
    [uint32]$pidRef = 0; [void][WindowHelper]::GetWindowThreadProcessId($hwnd, [ref]$pidRef)
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

if ($env:OS -ne 'Windows_NT') {
    Write-Host '仅支持 Windows（依赖 user32.dll）。' -ForegroundColor Red
} else {
    Watch-ForegroundPopup -Delay $DelaySeconds
}
