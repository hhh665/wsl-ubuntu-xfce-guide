[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu-24.04',
    [string]$LinuxUser,
    [switch]$WithChrome,
    [switch]$ConfigureOnly,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'
Import-Module (Join-Path $PSScriptRoot 'WslHelpers.psm1') -Force
$wsl = Get-WslExecutable
$distributions = @(& $wsl --list --quiet) | ForEach-Object { ($_ -replace "`0", '').Trim() }
if ($distributions -notcontains $Distro) {
    throw ('Distribution "{0}" is not visible to Windows account {1}. Check the real user context; do not reinstall blindly.' -f
        $Distro, [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
}
if (-not $LinuxUser) {
    $LinuxUser = (Invoke-WslCommand -Distro $Distro -Command @('id', '-un') | Out-String).Trim()
}
$uid = (Invoke-WslCommand -Distro $Distro -LinuxUser $LinuxUser -Command @('id', '-u') | Out-String).Trim()
if ($uid -eq '0') { throw 'Choose a normal Linux user with -LinuxUser. Do not run the desktop or Chrome as root.' }
$passwd = (Invoke-WslCommand -Distro $Distro -Command @('getent', 'passwd', $LinuxUser) | Out-String).Trim()
$fields = $passwd.Split(':')
if ($fields.Count -ne 7) { throw 'Could not determine the Linux home directory.' }
$linuxHome = $fields[5]
Write-Host ('Target: {0}, user: {1}, home: {2}' -f $Distro, $LinuxUser, $linuxHome)
Invoke-WslCommand -Distro $Distro -LinuxUser $LinuxUser -Command @('uname', '-m')
if ($CheckOnly) { return }

$sourceWindows = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\linux'))
$sourceLinux = (Invoke-WslCommand -Distro $Distro -LinuxUser $LinuxUser -Command @(
    'wslpath', '-a', '-u', $sourceWindows
) | Out-String).Trim()
$packageCommand = @('bash', ($sourceLinux + '/install-packages.sh'))
$configureCommand = @('bash', ($sourceLinux + '/configure-user.sh'))
if ($WithChrome) { $packageCommand += '--chrome'; $configureCommand += '--chrome' }
if (-not $ConfigureOnly) {
    Invoke-WslCommand -Distro $Distro -LinuxUser root -Command $packageCommand
}
Invoke-WslCommand -Distro $Distro -LinuxUser $LinuxUser -Command $configureCommand

$safeName = $Distro -replace '[^a-zA-Z0-9._-]', '_'
$runtimeWindows = Join-Path $env:LOCALAPPDATA ('WSL-Xfce\' + $safeName)
New-Item -ItemType Directory -Path $runtimeWindows -Force | Out-Null
foreach ($filename in @('Launch-Desktop.ps1', 'WslHelpers.psm1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $filename) -Destination $runtimeWindows -Force
}
$config = [ordered]@{
    Distro = $Distro
    LinuxUser = $LinuxUser
    LinuxHome = $linuxHome
    WindowTitle = ('Ubuntu Desktop (Xfce) [{0}]' -f $Distro)
}
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runtimeWindows 'config.json') -Encoding UTF8
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ('Ubuntu Desktop - ' + $safeName + '.lnk')
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shortcut.Arguments = ConvertTo-NativeCommandLine -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', (Join-Path $runtimeWindows 'Launch-Desktop.ps1')
)
$shortcut.WorkingDirectory = $runtimeWindows
$shortcut.IconLocation = $wsl + ',0'
$shortcut.Save()
Write-Host ('Installed. Open: ' + $shortcutPath)
Write-Host 'Check the Windows picture and click a desktop menu before calling this successful.'
