function Get-RcloneS3Profile {
    <#
    .SYNOPSIS
        Reads the `profile` set for a remote in ~/.config/rclone/rclone.conf.
    #>
    [CmdletBinding()]
    param(
        [string]$Remote = 's3',
        [string]$ConfigPath = (Join-Path $HOME '.config/rclone/rclone.conf')
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) { return $null }

    $inSection = $false
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $inSection = ($matches[1] -eq $Remote)
            continue
        }
        if ($inSection -and $trimmed -match '^profile\s*=\s*(.+)$') {
            return $matches[1].Trim()
        }
    }
    return $null
}

function Mount-S3Bucket {
    <#
    .SYNOPSIS
        Mounts an S3 bucket (or prefix) via rclone + fuse3, using AWS SSO credentials.
    .PARAMETER Bucket
        The S3 bucket name.
    .PARAMETER Prefix
        Optional key prefix within the bucket to mount instead of the whole bucket.
    .PARAMETER MountPath
        Local mount point. Defaults to ~/s3/<Bucket>.
    .PARAMETER AwsProfile
        SSO profile to use. Defaults to the `profile` set for the `s3` remote in ~/.config/rclone/rclone.conf.
    .PARAMETER Remote
        Name of the rclone remote to use. Defaults to `s3`.
    .PARAMETER DirCacheTime
        Value for rclone's --dir-cache-time. Defaults to 15m.
    .PARAMETER VfsCacheMode
        Value for rclone's --vfs-cache-mode. Defaults to writes.
    .PARAMETER PollInterval
        Value for rclone's --poll-interval. Defaults to 0 (disabled) since this is an on-demand mount, not a synced service - freshness is governed by -DirCacheTime instead.
    .EXAMPLE
        Mount-S3Bucket -Bucket my-data-bucket
    .EXAMPLE
        Mount-S3Bucket -Bucket my-data-bucket -Prefix exports/2026 -AwsProfile sdip-prod
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Bucket,

        [Parameter(Position = 1)]
        [string]$Prefix,

        [string]$MountPath,

        [string]$AwsProfile,

        [string]$Remote = 's3',

        [string]$DirCacheTime = '15m',

        [ValidateSet('off', 'minimal', 'writes', 'full')]
        [string]$VfsCacheMode = 'writes',

        [string]$PollInterval = '0'
    )

    if (-not $IsLinux) {
        Write-Warning "Mount-S3Bucket only works in WSL/Linux (needs rclone + fuse3); skipping on this platform."
        return
    }

    foreach ($cmd in 'rclone', 'aws', 'mountpoint') {
        if (-not (Get-Command $cmd -ErrorAction Ignore)) {
            Write-Error "Mount-S3Bucket: '$cmd' not found in PATH."
            return
        }
    }

    if (-not (Get-Command Get-STSCallerIdentity -ErrorAction Ignore)) {
        Write-Error "Mount-S3Bucket: AWS.Tools.SecurityTokenService cmdlets not available (Get-STSCallerIdentity not found)."
        return
    }

    if (-not $AwsProfile) {
        $AwsProfile = Get-RcloneS3Profile -Remote $Remote
        if (-not $AwsProfile) {
            Write-Error "Mount-S3Bucket: no -AwsProfile given and no 'profile' found for remote '$Remote' in ~/.config/rclone/rclone.conf."
            return
        }
    }

    if (-not $MountPath) {
        $MountPath = Join-Path $HOME "s3/$Bucket"
    }

    mountpoint -q $MountPath 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "🟢 $MountPath is already mounted; nothing to do."
        return
    }

    $sessionValid = $true
    try {
        $null = Get-STSCallerIdentity -ProfileName $AwsProfile -ErrorAction Stop
    }
    catch {
        $sessionValid = $false
    }

    if (-not $sessionValid) {
        Write-Host "SSO session for profile '$AwsProfile' is not valid; opening 'aws sso login'..."
        aws sso login --profile $AwsProfile
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Mount-S3Bucket: 'aws sso login --profile $AwsProfile' failed."
            return
        }
    }

    New-Item -ItemType Directory -Force -Path $MountPath | Out-Null

    $remoteSpec = "${Remote}:${Bucket}"
    if ($Prefix) { $remoteSpec += "/$($Prefix.Trim('/'))" }

    rclone mount $remoteSpec $MountPath --s3-profile $AwsProfile --vfs-cache-mode $VfsCacheMode --dir-cache-time $DirCacheTime --poll-interval $PollInterval --daemon
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Mount-S3Bucket: 'rclone mount' failed (exit $LASTEXITCODE)."
        return
    }

    Write-Host "🟢 Mounted $remoteSpec at $MountPath (profile: $AwsProfile)"
}

function Dismount-S3Bucket {
    <#
    .SYNOPSIS
        Unmounts an S3 bucket previously mounted with Mount-S3Bucket.
    .PARAMETER Bucket
        Bucket name; used to derive the default mount path (~/s3/<Bucket>) when -MountPath isn't given.
    .PARAMETER MountPath
        Local mount point to unmount.
    .EXAMPLE
        Dismount-S3Bucket -Bucket my-data-bucket
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Bucket,

        [string]$MountPath
    )

    if (-not $IsLinux) {
        Write-Warning "Dismount-S3Bucket only works in WSL/Linux; skipping on this platform."
        return
    }

    if (-not $MountPath) {
        if (-not $Bucket) {
            Write-Error "Dismount-S3Bucket: pass -Bucket or -MountPath."
            return
        }
        $MountPath = Join-Path $HOME "s3/$Bucket"
    }

    mountpoint -q $MountPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "🟢 $MountPath is not mounted; nothing to do."
        return
    }

    if (Get-Command fusermount -ErrorAction Ignore) {
        fusermount -u $MountPath
    }
    else {
        umount $MountPath
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Dismount-S3Bucket: failed to unmount $MountPath (exit $LASTEXITCODE)."
        return
    }

    Write-Host "🟢 Unmounted $MountPath"
}
