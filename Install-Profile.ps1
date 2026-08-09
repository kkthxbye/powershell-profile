$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$profileSource = Join-Path $root "Microsoft.PowerShell_profile.ps1"
$includeSource = Join-Path $root "Include"

$profileDir = Split-Path $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

try {
    New-Item -ItemType SymbolicLink -Path $PROFILE -Target $profileSource -Force | Out-Null
}
catch {
    if ($IsWindows) {
        throw "Failed to create symlink at '$PROFILE'. On Windows this needs Developer Mode enabled or an elevated shell.`n$_"
    }
    throw
}
Write-Host "Linked   $PROFILE -> $profileSource"

$includePath = Join-Path $profileDir "Include"
if ($IsWindows) {
    # Junctions don't require elevation on Windows, unlike symlinks.
    New-Item -ItemType Junction -Path $includePath -Target $includeSource -Force | Out-Null
}
else {
    New-Item -ItemType SymbolicLink -Path $includePath -Target $includeSource -Force | Out-Null
}
Write-Host "Linked   $includePath -> $includeSource"
