$ProfileItem = Get-Item $PROFILE
$Base = if ($ProfileItem.LinkType) { Split-Path $ProfileItem.Target } else { Split-Path $ProfileItem.FullName }
$Include = "$Base\Include"

$secrets = . "$Include\Secrets.ps1"
$configs = . "$Include\Configs.ps1"

. "$Include\Environment.ps1"
. "$Include\Aws.ps1"
. "$Include\Database.ps1"
. "$Include\Utils.ps1"

if ($IsWindows) {
    . "$Include\Windows.ps1"
}
elseif ($IsLinux) {
    . "$Include\Linux.ps1"
}
