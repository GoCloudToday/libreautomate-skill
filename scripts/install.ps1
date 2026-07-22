# Installs LibreAutomate (C# automation tool for Windows) silently and initializes its workspace.
# Requires: internet access. Shows one UAC prompt unless the shell is already elevated.
# Usage: pwsh -File install.ps1 [-Force]
param([switch]$Force)
$ErrorActionPreference = 'Stop'

$exe = "$env:ProgramFiles\LibreAutomate\Au.Editor.exe"
$ws  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'LibreAutomate\Main'

function Wait-Workspace {
    if (-not (Test-Path "$ws\files.xml")) {
        Start-Process $exe -ArgumentList '/a'   # /a = start hidden (tray only)
        $t = 0
        while (-not (Test-Path "$ws\files.xml") -and $t -lt 90) { Start-Sleep 1; $t++ }
        if (-not (Test-Path "$ws\files.xml")) { throw "Workspace was not created at $ws within 90 s." }
    }
}

if ((Test-Path $exe) -and -not $Force) {
    Wait-Workspace
    Write-Output "ALREADY-INSTALLED: $exe"
    Write-Output "WORKSPACE: $ws"
    return
}

# Resolve latest release; fall back to a known-good pinned version.
$url = 'https://github.com/qgindi/LibreAutomate/releases/download/v1.16.1/LibreAutomateSetup.exe'
try {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/qgindi/LibreAutomate/releases/latest'
    $asset = $rel.assets | Where-Object name -eq 'LibreAutomateSetup.exe' | Select-Object -First 1
    if ($asset) { $url = $asset.browser_download_url }
} catch { Write-Output "NOTE: GitHub API unavailable, using pinned $url" }

$setup = Join-Path $env:TEMP 'LibreAutomateSetup.exe'
Write-Output "Downloading $url ..."
Invoke-WebRequest -Uri $url -OutFile $setup

# Silent install. Installer also downloads + silently installs .NET 10 Desktop Runtime if missing (~60 MB).
Write-Output "Installing (UAC prompt may appear; .NET runtime download can take a few minutes)..."
$p = Start-Process -FilePath $setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Verb RunAs -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "Installer failed with exit code $($p.ExitCode)." }
if (-not (Test-Path $exe)) { throw "Installer reported success but $exe not found." }

Wait-Workspace
Write-Output "INSTALLED: $exe"
Write-Output "WORKSPACE: $ws"
