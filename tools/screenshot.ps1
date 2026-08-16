<#
.SYNOPSIS
    Captures a screenshot of the running game window WITHOUT stealing
    window focus.

.DESCRIPTION
    Uses the Win32 PrintWindow API (with PW_RENDERFULLCONTENT, needed for
    hardware-accelerated/OpenGL content) to capture the target window's
    contents directly, instead of the more common approach of bringing
    the window to the foreground and grabbing the screen region under it.
    That older approach interrupts whatever the user is doing on their
    desktop; this one does not touch window focus or Z-order at all.

    See TESTING.md for the full visual-testing workflow this is part of.

.PARAMETER OutFile
    Where to save the PNG. Defaults to screenshots/<timestamp>.png.

.PARAMETER ProcessName
    Process to find the window of. Defaults to the project's Godot binary.

.EXAMPLE
    .\tools\screenshot.ps1 -OutFile "screenshots\20260101_shop_tabs.png"
#>
param(
    [string]$OutFile = "$PSScriptRoot\..\screenshots\$(Get-Date -Format 'yyyyMMdd_HHmmss').png",
    [string]$ProcessName = "Godot_v4.7.1-stable_win64"
)

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public static class WindowCapture {
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    // A DPI-unaware caller gets GetClientRect/PrintWindow results scaled
    // down by the display's DPI factor (e.g. a real 1280x720 window reads
    // back as 426x240 at 300% scaling) -- declaring awareness up front
    // makes both APIs report true physical pixels instead.
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    // PW_CLIENTONLY (0x1): capture just the client area, matching the
    // GetClientRect-sized bitmap below -- without it PrintWindow draws
    // the *whole* window (title bar included) starting from (0,0) of
    // whatever bitmap you give it, so a client-sized bitmap only ever
    // catches the title bar plus a sliver of content clipped off the top.
    // PW_RENDERFULLCONTENT (0x2): required on Windows 8.1+ to correctly
    // capture DirectX/OpenGL-rendered windows -- without it PrintWindow
    // silently returns a blank bitmap for GPU-rendered content, which is
    // exactly the kind of window a game is.
    const uint PW_CLIENTONLY = 0x1;
    const uint PW_RENDERFULLCONTENT = 0x2;

    public static Bitmap Capture(IntPtr hWnd) {
        RECT rect;
        GetClientRect(hWnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0) {
            throw new InvalidOperationException("Window has no client area (minimized?).");
        }
        Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            bool ok = PrintWindow(hWnd, hdc, PW_CLIENTONLY | PW_RENDERFULLCONTENT);
            g.ReleaseHdc(hdc);
            if (!ok) {
                throw new InvalidOperationException("PrintWindow failed.");
            }
        }
        return bmp;
    }
}
"@

[WindowCapture]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {
    Write-Error "No running process named '$ProcessName'. Is the game running? (see tools/launch_game.ps1)"
    exit 1
}
if ($proc.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Error "Process '$ProcessName' has no visible main window yet -- try again in a moment."
    exit 1
}

$outDir = Split-Path $OutFile -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$bmp = [WindowCapture]::Capture($proc.MainWindowHandle)
$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output $OutFile
