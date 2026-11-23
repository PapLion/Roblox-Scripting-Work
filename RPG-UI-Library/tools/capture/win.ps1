param([string]$Action = 'info', [int]$X = 0, [int]$Y = 0, [int]$W = 0, [int]$H = 0)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
}
"@
[Win]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
$p = Get-Process RobloxStudioBeta -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$hw = $p.MainWindowHandle
switch ($Action) {
    'restore' { [Win]::ShowWindow($hw, 9) | Out-Null }
    'maximize' { [Win]::ShowWindow($hw, 3) | Out-Null }
    'move' { [Win]::ShowWindow($hw, 9) | Out-Null; [Win]::SetWindowPos($hw, [IntPtr]::Zero, $X, $Y, $W, $H, 0x0014) | Out-Null }
}
Start-Sleep -Milliseconds 400
$r = New-Object Win+RECT; [Win]::GetWindowRect($hw, [ref]$r) | Out-Null
$c = New-Object Win+RECT; [Win]::GetClientRect($hw, [ref]$c) | Out-Null
"title='$($p.MainWindowTitle)' rect=($($r.L),$($r.T))-($($r.R),$($r.B)) size=$($r.R - $r.L)x$($r.B - $r.T) client=$($c.R)x$($c.B) maximized=$([Win]::IsZoomed($hw))"
