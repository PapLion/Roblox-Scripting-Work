param([string]$Out, [int]$X = 0, [int]$Y = 0, [int]$W = 0, [int]$H = 0)
# Captures the Roblox Studio main window with PrintWindow (PW_RENDERFULLCONTENT), so it works even when
# other windows cover it: nothing else on the desktop ends up in the image. Optional crop in client coords.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PW {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
}
"@
[PW]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
Add-Type -AssemblyName System.Drawing
$p = Get-Process RobloxStudioBeta -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$hw = $p.MainWindowHandle
$r = New-Object PW+RECT; [PW]::GetClientRect($hw, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap $r.R, $r.B, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
# 1 = PW_CLIENTONLY, 2 = PW_RENDERFULLCONTENT
$ok = [PW]::PrintWindow($hw, $hdc, 3)
$g.ReleaseHdc($hdc); $g.Dispose()
if ($W -gt 0) {
    $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $X, $Y, $W, $H), [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bmp.Dispose(); $bmp = $crop
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"printwindow ok=$ok saved $Out $($bmp.Width)x$($bmp.Height)"
$bmp.Dispose()
