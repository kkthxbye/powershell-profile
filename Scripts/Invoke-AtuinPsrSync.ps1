$ErrorActionPreference = "Stop"

$profileItem = Get-Item $PROFILE
$base = if ($profileItem.LinkType) { Split-Path $profileItem.Target } else { Split-Path $profileItem.FullName }

. (Join-Path $base "Include/Common/Utils.ps1")

Export-AtuinHistoryToPsr
