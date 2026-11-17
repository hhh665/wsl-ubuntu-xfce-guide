Set-StrictMode -Version Latest

function Get-WslExecutable {
    $candidate = Join-Path $env:WINDIR 'System32\wsl.exe'
    if (-not (Test-Path -LiteralPath $candidate)) { throw 'wsl.exe was not found.' }
    return $candidate
}

function ConvertTo-NativeCommandLine {
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments)
    $encoded = foreach ($argument in $Arguments) {
        # CommandLineToArgvW / Microsoft CRT quoting, including trailing slashes.
        $escaped = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }
    return ($encoded -join ' ')
}

function Invoke-WslCommand {
    param(
        [string]$Distro,
        [string]$LinuxUser,
        [switch]$System,
        [Parameter(Mandatory)][string[]]$Command
    )
    $nativeArguments = @()
    if ($System) {
        if (-not $Distro) { throw 'Select the distribution whose WSLg system instance should be used.' }
        $nativeArguments += @('-d', $Distro, '--system')
    }
    else {
        if (-not $Distro) { throw 'A distribution name is required.' }
        $nativeArguments += @('-d', $Distro)
        if ($LinuxUser) { $nativeArguments += @('-u', $LinuxUser) }
    }
    $nativeArguments += '--exec'
    $nativeArguments += $Command
    & (Get-WslExecutable) @nativeArguments
    if ($LASTEXITCODE -ne 0) {
        throw ('WSL command failed with exit code {0}: {1}' -f $LASTEXITCODE, $Command[0])
    }
}

function Get-WslGraphicsMode {
    param([Parameter(Mandatory)][string]$Distro, [string]$LinuxUser)
    try {
        $lines = @(Invoke-WslCommand -Distro $Distro -LinuxUser $LinuxUser -Command @(
            'grep', 'use_gfxredir', '/mnt/wslg/weston.log'
        ))
    } catch { return 'unknown' }
    $modeMatches = [regex]::Matches(($lines -join "`n"), 'use_gfxredir\s*=\s*([01])')
    if ($modeMatches.Count -eq 0) { return 'unknown' }
    return $modeMatches[$modeMatches.Count - 1].Groups[1].Value
}

Export-ModuleMember -Function Get-WslExecutable, ConvertTo-NativeCommandLine, Invoke-WslCommand, Get-WslGraphicsMode
