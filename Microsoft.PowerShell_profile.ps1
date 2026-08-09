$ProfileItem = Get-Item $PROFILE
$Base = if ($ProfileItem.LinkType) { Split-Path $ProfileItem.Target } else { Split-Path $ProfileItem.FullName }
$Include = Join-Path $Base "Include"

$secrets = . (Join-Path $Include "Secrets.ps1")
$configs = . (Join-Path $Include "Configs.ps1")

. (Join-Path $Include "Environment.ps1")
. (Join-Path $Include "Prompt.ps1")
. (Join-Path $Include "Aws.ps1")
. (Join-Path $Include "Database.ps1")
. (Join-Path $Include "Utils.ps1")

if ($IsWindows) {
    . (Join-Path $Include "Windows.ps1")
}
elseif ($IsLinux) {
    . (Join-Path $Include "Linux.ps1")
}
