$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$scripts = Get-ChildItem -LiteralPath (Join-Path $repo 'windows') -File |
    Where-Object { $_.Extension -in @('.ps1', '.psm1') }
$scripts += Get-Item -LiteralPath $PSCommandPath
foreach ($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
}
Import-Module (Join-Path $repo 'windows\WslHelpers.psm1') -Force
$python = (Get-Command python.exe -CommandType Application | Select-Object -First 1).Source
$payload = @('', 'plain', 'argument with spaces', 'a"b', 'C:\path with spaces\', 'a\\\"b', ('unicode-' + [char]0x4e2d))
$arguments = @('-c', 'import json,sys; print(json.dumps(sys.argv[1:]))') + $payload
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $python
$startInfo.Arguments = ConvertTo-NativeCommandLine -Arguments $arguments
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
$process = [Diagnostics.Process]::Start($startInfo)
if (-not $process.WaitForExit(10000)) { $process.Kill(); throw 'Argument round-trip process timed out.' }
$text = $process.StandardOutput.ReadToEnd()
if ($process.ExitCode -ne 0) { throw $process.StandardError.ReadToEnd() }
$actual = ConvertFrom-Json -InputObject $text
if ($actual.Count -ne $payload.Count) { throw 'Argument count changed during native launch.' }
for ($index = 0; $index -lt $payload.Count; $index++) {
    if ($actual[$index] -cne $payload[$index]) { throw ('Argument did not round-trip at index ' + $index) }
}
Write-Output 'POWERSHELL_PARSE_OK'
Write-Output 'NATIVE_ARGUMENT_ROUNDTRIP_OK'
