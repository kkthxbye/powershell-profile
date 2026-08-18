[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'secrets/configs are consumed by dot-sourced Include scripts and there is no per-line #ignore'
)]
param()

$ProfileItem = Get-Item $PROFILE
$Base = if ($ProfileItem.LinkType) { Split-Path $ProfileItem.Target } else { Split-Path $ProfileItem.FullName }
$Include = Join-Path $Base "Include"

$secretsPath = Join-Path $Include "Secrets.ps1"
$configsPath = Join-Path $Include "Configs.ps1"

$secrets = if (Test-Path $secretsPath) { . $secretsPath }
$configs = if (Test-Path $configsPath) { . $configsPath }

if ($IsWindows) {
    . (Join-Path $Include "Windows.ps1")
    Get-ChildItem (Join-Path $Include "Windows") -Filter "*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }
}
elseif ($IsLinux) {
    . (Join-Path $Include "Linux.ps1")
    Get-ChildItem (Join-Path $Include "Linux") -Filter "*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }
}

Get-ChildItem (Join-Path $Include "Common") -Filter "*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }
