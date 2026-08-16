<#
.SYNOPSIS
    Sends a left-click to a specific client-area coordinate of the running
    game window WITHOUT bringing it to the foreground.

.DESCRIPTION
    Uses PostMessage to deliver WM_LBUTTONDOWN/UP directly to the window
    handle, without touching focus or Z-order -- unlike
    SetForegroundWindow-based approaches, which pull the window on top of
    whatever the user is looking at.

    CAVEAT (found 2026-08-16): in practice this did NOT reliably register
    with Godot's input handling in testing -- Godot's DisplayServer
    appears to only process mouse input while the window actually has OS
    input focus, regardless of whether the message was delivered. If
    clicks sent through this script don't seem to land, that's why --
    use click_foreground.ps1 instead (it works, at the cost of briefly
    taking focus). This script is kept in case a future Godot/Windows
    combination behaves differently; verify with a before/after
    screenshot before relying on it.

    Coordinates are in the window's CLIENT area (0,0 = top-left of the
    game viewport, not the OS window frame/title bar) at the window's
    CURRENT size -- take a screenshot first (see screenshot.ps1) to work
    out where the thing you want to click actually is.

.PARAMETER X
.PARAMETER Y
    Client-area pixel coordinates to click.

.PARAMETER ProcessName
    Process to find the window of. Defaults to the project's Godot binary.

.EXAMPLE
    .\tools\click_at.ps1 -X 878 -Y 372
#>
param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [string]$ProcessName = "Godot_v4.7.1-stable_win64"
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class BackgroundInput {
    [DllImport("user32.dll")]
    public static extern IntPtr PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    const uint WM_LBUTTONDOWN = 0x0201;
    const uint WM_LBUTTONUP = 0x0202;
    const uint WM_MOUSEMOVE = 0x0200;

    public static void Click(IntPtr hWnd, int x, int y) {
        IntPtr lParam = (IntPtr)((y << 16) | (x & 0xFFFF));
        PostMessage(hWnd, WM_MOUSEMOVE, IntPtr.Zero, lParam);
        PostMessage(hWnd, WM_LBUTTONDOWN, (IntPtr)1, lParam);
        PostMessage(hWnd, WM_LBUTTONUP, IntPtr.Zero, lParam);
    }
}
"@

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Error "No running '$ProcessName' window found."
    exit 1
}

[BackgroundInput]::Click($proc.MainWindowHandle, $X, $Y)
Write-Output "Clicked ($X, $Y) in $ProcessName without changing focus."
