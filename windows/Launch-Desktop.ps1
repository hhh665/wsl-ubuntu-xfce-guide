[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [switch]$RepairGraphics,
    [switch]$RestartSession
)
$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'
$mutex = $null
$locked = $false
try {
    Add-Type -AssemblyName System.Windows.Forms
    Import-Module (Join-Path $PSScriptRoot 'WslHelpers.psm1') -Force
    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $mutexName = 'Local\WslXfce-' + ($config.Distro -replace '[^a-zA-Z0-9._-]', '_')
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    try { $locked = $mutex.WaitOne(30000) }
    catch [System.Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'Another desktop launch is still in progress.' }
    if (-not ('WslXfceWindows' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WslXfceWindows {
    public delegate bool Callback(IntPtr window, IntPtr parameter);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool EnumWindows(Callback callback, IntPtr parameter);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rectangle);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr window, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
    public static IntPtr[] Find(string expectedTitle) {
        var found = new List<IntPtr>();
        EnumWindows(delegate(IntPtr window, IntPtr unused) {
            var text = new StringBuilder(1024);
            GetWindowText(window, text, text.Capacity);
            if (text.ToString().Contains(expectedTitle) && !text.ToString().Contains("[WARN:COPY MODE]")) found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@
    }
    function Show-DesktopWindow {
        foreach ($window in [WslXfceWindows]::Find($config.WindowTitle)) {
            [void][WslXfceWindows]::ShowWindowAsync($window, 9)
            Start-Sleep -Milliseconds 150
            $rectangle = New-Object WslXfceWindows+Rect
            $onScreen = $false
            if ([WslXfceWindows]::GetWindowRect($window, [ref]$rectangle)) {
                foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
                    $area = $screen.WorkingArea
                    if (($rectangle.Right -gt ($area.Left + 60)) -and ($rectangle.Left -lt ($area.Right - 60)) -and
                        ($rectangle.Bottom -gt ($area.Top + 40)) -and ($rectangle.Top -lt ($area.Bottom - 40))) { $onScreen = $true }
                }
                if (-not $onScreen) {
                    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
                    [void][WslXfceWindows]::SetWindowPos($window, [IntPtr]::Zero, $area.Left, $area.Top,
                        [Math]::Min(1620, $area.Width), [Math]::Min(940, $area.Height), 0x0044)
                }
            }
            [void][WslXfceWindows]::SetForegroundWindow($window)
            return $true
        }
        return $false
    }
    if ($RestartSession) {
        # This switch explicitly requests closing this managed desktop's apps.
        Invoke-WslCommand -Distro $config.Distro -LinuxUser $config.LinuxUser -Command @(
            ($config.LinuxHome + '/.local/bin/stop-xfce-desktop')
        )
        Start-Sleep -Seconds 2
    }
    $mode = Get-WslGraphicsMode -Distro $config.Distro -LinuxUser $config.LinuxUser
    if ($mode -eq '0') {
        if (-not $RepairGraphics) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                'WSLg COPY MODE prevents windows from rendering. Restart Linux graphics? This closes Linux graphical apps; save work first.',
                'Ubuntu Desktop', 'YesNo', 'Warning')
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { exit 0 }
        }
        Invoke-WslCommand -Distro $config.Distro -System -Command @('pkill', '-TERM', '-x', 'weston')
        $repairDeadline = [DateTime]::UtcNow.AddSeconds(20)
        do {
            Start-Sleep -Milliseconds 500
            $mode = Get-WslGraphicsMode -Distro $config.Distro -LinuxUser $config.LinuxUser
        } while (($mode -ne '1') -and ([DateTime]::UtcNow -lt $repairDeadline))
        if ($mode -ne '1') { throw 'WSLg graphics recovery failed. Inspect the latest weston.log entry.' }
        Start-Sleep -Seconds 2
    }
    if (Show-DesktopWindow) { exit 0 }
    $arguments = ConvertTo-NativeCommandLine -Arguments @('-d', $config.Distro, '-u', $config.LinuxUser,
        '--exec', ($config.LinuxHome + '/.local/bin/start-xfce-desktop'))
    $desktopProcess = Start-Process -FilePath (Get-WslExecutable) -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Show-DesktopWindow) { exit 0 }
        if ($desktopProcess.HasExited -and ($desktopProcess.ExitCode -ne 0)) {
            throw ('Desktop launcher exited with code ' + $desktopProcess.ExitCode)
        }
        Start-Sleep -Milliseconds 250
    }
    throw 'No desktop window appeared. Inspect ~/.local/state/wsl-xfce-desktop/session.log.'
} catch {
    [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Ubuntu Desktop', 'OK', 'Error')
    exit 1
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    if ($null -ne $mutex) { $mutex.Dispose() }
}
