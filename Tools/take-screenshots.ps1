#Requires -Version 7
<#
.SYNOPSIS
    Launches every Blinki app (demos + smoke tests), captures a screenshot and saves it
    as Screenshot.png inside the project folder.
.NOTES
    Uses wt.exe --window new so each app opens in a dedicated Windows Terminal window
    that can be captured independently. Requires compiled .exe files (run MSBuild first).
    The base directory is derived automatically from the script location ($PSScriptRoot\..).
    Projects are discovered automatically: any subfolder of Demos\ or Tests\SmokeTests\
    that contains an exe named after the folder (e.g. Form\Form.exe) is included.
#>

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# --------------------------------------------------------------------------
# Win32 API P/Invoke (native types only — no System.Drawing references in C#)
# --------------------------------------------------------------------------
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class WinApi {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc fn, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc fn, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder sb, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder sb, int n);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hDC, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    // Closes only the specified window without touching the WT process
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("gdi32.dll")]  public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
    [DllImport("gdi32.dll")]  public static extern bool DeleteDC(IntPtr hdc);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public static string GetClass(IntPtr hWnd) {
        var sb = new System.Text.StringBuilder(256);
        GetClassName(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }
    public static string GetTitle(IntPtr hWnd) {
        var sb = new System.Text.StringBuilder(512);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    // Returns all top-level HWNDs matching the given window class name
    public static IntPtr[] FindWindowsByClass(string className) {
        var list = new List<IntPtr>();
        EnumWindows((h, _) => {
            if (GetClass(h) == className) list.Add(h);
            return true;
        }, IntPtr.Zero);
        return list.ToArray();
    }

    // Returns the largest visible child HWND (approximates the terminal content area)
    public static IntPtr FindLargestChildWindow(IntPtr parent) {
        IntPtr best = IntPtr.Zero;
        int bestArea = 0;
        RECT r;
        EnumChildWindows(parent, (h, _) => {
            if (!IsWindowVisible(h)) return true;
            if (GetWindowRect(h, out r)) {
                int area = (r.Right - r.Left) * (r.Bottom - r.Top);
                if (area > bestArea) { bestArea = area; best = h; }
            }
            return true;
        }, IntPtr.Zero);
        return best;
    }
}
'@

# Load System.Drawing for bitmap operations and PNG export
Add-Type -AssemblyName System.Drawing

# --------------------------------------------------------------------------
# Resolve base directory from script location (script lives in <repo>\Tools\)
# --------------------------------------------------------------------------
$base = Split-Path $PSScriptRoot -Parent
Write-Host "Repository root: $base" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# Helper: locate wt.exe (Windows Terminal)
# --------------------------------------------------------------------------
function Find-Wt {
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe",
        "C:\Program Files\WindowsApps\Microsoft.WindowsTerminalPreview*\wt.exe",
        "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*\wt.exe"
    )
    foreach ($c in $candidates) {
        $found = Get-Item $c -EA SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    $cmd = Get-Command wt.exe -EA SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$wtExe = Find-Wt
if (-not $wtExe) { Write-Error "wt.exe not found"; exit 1 }
Write-Host "wt.exe: $wtExe" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# Capture function: launch the app, wait for the new WT window, PrintWindow
# --------------------------------------------------------------------------
function Take-Screenshot {
    param(
        [string]$Name,
        [string]$ExePath,
        [string]$OutPath
    )

    if (-not (Test-Path $ExePath)) {
        Write-Host "[$Name] SKIP: exe not found ($ExePath)" -ForegroundColor Yellow
        return $false
    }

    Write-Host "[$Name]" -NoNewline

    # Snapshot existing WT window handles as long integers for reliable comparison
    [long[]]$beforeLongs = @(
        [WinApi]::FindWindowsByClass("CASCADIA_HOSTING_WINDOW_CLASS") +
        [WinApi]::FindWindowsByClass("CASCADIA_HOSTING_APP_CLASS") |
        ForEach-Object { [long]$_ }
    )

    # Launch the app in a new dedicated Windows Terminal window (--window new)
    # and set the console size before the TUI starts so the layout is consistent
    $escapedExe = $ExePath -replace '"','\"'
    $wtArgs = "--window new -- cmd.exe /c `"mode con cols=120 lines=37 & `"$escapedExe`"`""
    $wtProc = Start-Process -FilePath $wtExe -ArgumentList $wtArgs -PassThru -EA SilentlyContinue

    if (-not $wtProc) {
        Write-Host " ERROR: wt.exe did not start" -ForegroundColor Red
        return $false
    }
    Write-Host " wt=$($wtProc.Id)" -NoNewline

    # Poll for the new WT window HWND (up to 8 s)
    $hwnd = [IntPtr]::Zero
    $deadline = [DateTime]::Now.AddSeconds(8)
    while ($hwnd -eq [IntPtr]::Zero -and [DateTime]::Now -lt $deadline) {
        Start-Sleep -Milliseconds 400
        $candidates = @(
            [WinApi]::FindWindowsByClass("CASCADIA_HOSTING_WINDOW_CLASS") +
            [WinApi]::FindWindowsByClass("CASCADIA_HOSTING_APP_CLASS")
        )
        foreach ($c in $candidates) {
            if ($beforeLongs -notcontains [long]$c) {
                $hwnd = $c
                break
            }
        }
    }

    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Host " ERROR: new WT window not found" -ForegroundColor Red
        try { Stop-Process -Id $wtProc.Id -Force -EA SilentlyContinue } catch {}
        return $false
    }

    Write-Host " hwnd=$hwnd" -NoNewline

    # Wait for the TUI to render its first frame
    Start-Sleep -Milliseconds 2500

    # Bring the window to the foreground (improves PrintWindow reliability)
    [WinApi]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE = 9
    [WinApi]::BringWindowToTop($hwnd) | Out-Null
    [WinApi]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300

    # Measure window dimensions
    $rect = New-Object WinApi+RECT
    [WinApi]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $w = [Math]::Max($rect.Right - $rect.Left, 10)
    $h = [Math]::Max($rect.Bottom - $rect.Top, 10)

    # Capture with PrintWindow flag 2 (PW_RENDERFULLCONTENT) — works with DX/XAML rendering
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $gfx.GetHdc()
    $pwOk = [WinApi]::PrintWindow($hwnd, $hdc, 2)
    $gfx.ReleaseHdc($hdc)
    $gfx.Dispose()

    # Fall back to CopyFromScreen if PrintWindow returned a black image
    $corner = $bmp.GetPixel(10, 10)
    $isMostlyBlack = ($corner.R + $corner.G + $corner.B) -lt 30
    if (-not $pwOk -or $isMostlyBlack) {
        Write-Host " [fallback: CopyFromScreen]" -NoNewline
        $bmp.Dispose()
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $gfx2 = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx2.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($w, $h),
            [System.Drawing.CopyPixelOperation]::SourceCopy)
        $gfx2.Dispose()
    }

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    # Close ONLY this WT window via WM_CLOSE (0x10).
    # Do NOT kill the WindowsTerminal.exe process — it is shared across all open WT windows,
    # including the session running this script. PostMessage targets the single HWND only.
    [WinApi]::PostMessage($hwnd, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 800

    $fi = Get-Item $OutPath -EA SilentlyContinue
    $kb = if ($fi) { [Math]::Round($fi.Length / 1024, 0) } else { 0 }
    Write-Host " OK ($w x $h px, $kb KB)" -ForegroundColor Green
    return $true
}

# --------------------------------------------------------------------------
# Auto-discover projects: scan Demos\ and Tests\SmokeTests\ for subfolders
# that contain an exe named after the folder (e.g. Form\Form.exe).
# --------------------------------------------------------------------------
$searchRoots = @(
    (Join-Path $base "Demos"),
    (Join-Path $base "Tests\SmokeTests")
)

$projects = @()
foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($dir in Get-ChildItem $root -Directory | Sort-Object Name) {
        $exePath = Join-Path $dir.FullName "$($dir.Name).exe"
        if (Test-Path $exePath) {
            $projects += [PSCustomObject]@{
                N = $dir.Name
                E = $exePath
                O = Join-Path $dir.FullName "Screenshot.png"
            }
        }
    }
}

# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Starting screenshot capture ($($projects.Count) projects) ===" -ForegroundColor Cyan
Write-Host ""

$ok = 0; $fail = 0; $results = @()

foreach ($p in $projects) {
    $success = Take-Screenshot -Name $p.N -ExePath $p.E -OutPath $p.O
    if ($success) { $ok++ } else { $fail++ }
    $results += [PSCustomObject]@{ Project = $p.N; Result = if ($success) { "OK" } else { "FAIL" } }
    Start-Sleep -Milliseconds 800
}

Write-Host ""
Write-Host "=== FINAL RESULTS ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Host ""
Write-Host "Total: $ok OK, $fail failed out of $($projects.Count) projects" `
    -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
