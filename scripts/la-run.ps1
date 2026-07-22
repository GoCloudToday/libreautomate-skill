# Registers (if needed) and runs a LibreAutomate C# script, waits for it, prints its result.
# Usage:
#   pwsh -File la-run.ps1 -Name my-task -File path\to\code.cs [-Arguments a,b] [-TimeoutSec 120]
#   pwsh -File la-run.ps1 -Name my-task -Code 'script.writeResult("hi");'
#   pwsh -File la-run.ps1 -Name my-task            # re-run existing script
# Output: script's script.writeResult() text on stdout; "EXITCODE: n" as the last line.
param(
    [Parameter(Mandatory)][string]$Name,   # script name, no .cs extension
    [string]$Code,                         # C# source (top-level statements)
    [string]$File,                         # or: path to a .cs file with the source
    [string[]]$Arguments = @(),
    [int]$TimeoutSec = 120
)
$ErrorActionPreference = 'Stop'

$exe = "$env:ProgramFiles\LibreAutomate\Au.Editor.exe"
if (-not (Test-Path $exe)) { throw "LibreAutomate not installed. Run install.ps1 first." }
$ws = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'LibreAutomate\Main'

# Ensure workspace exists (created automatically on first editor start).
if (-not (Test-Path "$ws\files.xml")) {
    Start-Process $exe -ArgumentList '/a'
    $t = 0
    while (-not (Test-Path "$ws\files.xml") -and $t -lt 90) { Start-Sleep 1; $t++ }
    if (-not (Test-Path "$ws\files.xml")) { throw "Workspace not found at $ws." }
}

if ($File) { $Code = Get-Content -Path $File -Raw }
$scriptFile = Join-Path $ws "files\$Name.cs"
if ($Code) {
    Set-Content -Path $scriptFile -Value $Code -Encoding UTF8
} elseif (-not (Test-Path $scriptFile)) {
    throw "Script $Name.cs does not exist and no -Code/-File given."
}

# Register in files.xml if missing, then make the editor reload the workspace.
[xml]$x = Get-Content "$ws\files.xml" -Raw
$fileName = "$Name.cs"
$registered = $x.SelectNodes('//*[@n]') | Where-Object { $_.GetAttribute('n') -eq $fileName }
if (-not $registered) {
    $maxId = ($x.SelectNodes('//*[@i]') | ForEach-Object { [int]$_.GetAttribute('i') } | Measure-Object -Maximum).Maximum
    $el = $x.CreateElement('s')
    $el.SetAttribute('n', $fileName)
    $el.SetAttribute('i', $maxId + 1)
    $null = $x.DocumentElement.AppendChild($el)
    $x.Save("$ws\files.xml")
    if (Get-Process -Name 'Au.Editor' -ErrorAction SilentlyContinue) {
        & $exe /reload
        Start-Sleep 2
    }
}

# Run and wait. "*name.cs" = wait for script end, relay script.writeResult() to stdout,
# exit code = script's (0 ok, -1 compile error, -2 not found, -532462766 unhandled exception).
$psi = [System.Diagnostics.ProcessStartInfo]::new($exe)
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.ArgumentList.Add("*$fileName")
foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
$p = [System.Diagnostics.Process]::Start($psi)
$outTask = $p.StandardOutput.ReadToEndAsync()
$errTask = $p.StandardError.ReadToEndAsync()
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    $p.Kill()
    Get-Process -Name 'Au.Task*' -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
    Write-Output "TIMEOUT after $TimeoutSec s (script task killed)."
    Write-Output "EXITCODE: -999"
    exit 1
}
$out = $outTask.Result
$err = $errTask.Result
if ($out) { Write-Output $out.TrimEnd() }
if ($err) { Write-Output "STDERR: $($err.TrimEnd())" }
Write-Output "EXITCODE: $($p.ExitCode)"
exit $(if ($p.ExitCode -eq 0) { 0 } else { 1 })
