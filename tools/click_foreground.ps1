<#
.SYNOPSIS
    Clicks a point in the running game window using real OS input --
    this WORKS reliably (verified 2026-08-16), unlike click_at.ps1's
    PostMessage approach, at the cost of briefly taking window focus.

.DESCRIPTION
    Brings the window to the foreground, moves the real cursor there, and
    sends a real mouse_event click. This is the same class of technique
    that prompted the original "stop stealing my focus" complaint this
    tooling exists to move away from -- so treat it as the exception, not
    the default:
      - Only run this when the user has explicitly asked for interactive
        UI testing (clicking through screens, verifying a flow) --
        never proactively.
      - Prefer screenshot.ps1 alone wherever a passive look is enough.
      - Say what you're about to click before running this, same as
        launching the game at all -- the window will visibly pop to the
        front for a moment.

.PARAMETER X
.PARAMETER Y
    Client-area pixel coordinates to click, at the window's actual size
    (screenshot.ps1's output dimensions == this coordinate space).

.PARAMETER ProcessName
    Process to find the window of. Defaults to the project's Godot binary.

.EXAMPLE
    .\tools\click_foreground.ps1 -X 639 -Y 595
#>
param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [string]$ProcessName = "Godot_v4.7.1-stable_win64"
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class ForegroundClick {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

    const uint MOUSEEVENTF_LEFTDOWN = 0x2;
    const uint MOUSEEVENTF_LEFTUP = 0x4;

    // Client-relative (x, y) -> real screen coordinates via ClientToScreen,
    // rather than guessing at title-bar/border height -- that guess is
    // what cost the most iteration time when this was first built.
    public static void Click(IntPtr hWnd, int x, int y) {
        SetForegroundWindow(hWnd);
        System.Threading.Thread.Sleep(500);
        POINT pt = new POINT { X = x, Y = y };
        ClientToScreen(hWnd, ref pt);
        SetCursorPos(pt.X, pt.Y);
        System.Threading.Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }
}
"@

[ForegroundClick]::SetProcessDPIAware() | Out-Null

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc -or $proc.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Error "No running '$ProcessName' window found."
    exit 1
}

[ForegroundClick]::Click($proc.MainWindowHandle, $X, $Y)
Write-Output "Clicked client ($X, $Y) in $ProcessName (window was briefly foregrounded)."
