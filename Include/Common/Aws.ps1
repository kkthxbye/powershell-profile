function Enter-AwsSession {
    [CmdletBinding()]
    param()
    $j = Start-ThreadJob {
        aws sso login --no-browser
    }
    $seen = 0
    do {
        Start-Sleep -Milliseconds 200
        $lines = @(Receive-Job $j -Keep)
        if ($lines.Count -gt $seen) {
            $lines[$seen..($lines.Count - 1)] | ForEach-Object { Write-Verbose $_ }
            $seen = $lines.Count
        }
        $url = $lines | Select-String -NoEmphasis "^https?://\S+"
    } while (!$url -and $j.State -eq 'Running')
    if (!$url) {
        Receive-Job $j
        Write-Error "Enter-AwsSession: aws sso login exited without producing a login URL."
        return
    }
    Receive-Job $j | ForEach-Object { Write-Verbose $_ }
    Write-Host "$url"
    & $env:BROWSER --app-url "$url"
    $j | Wait-Job | Receive-Job
}

function Wait-RDSDBLog {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$DBInstanceIdentifier
    )
    $credentials = Get-AWSCredential
    $region = (Get-AWSRegion | Where-Object IsShellDefault).Region

    (
        @($credentials, "No credentials selected"),
        @($region, "No region specified")
    ) | ForEach-Object {
        if ($null -eq ($_[0])) {
            throw $_[1]
        }
    }

    $j = Start-ThreadJob {
        Set-DefaultAWSRegion "$($using:region)"
        Get-RDSDBLogFile -DBInstanceIdentifier $using:DBInstanceIdentifier -Credential $using:credentials `
        | Select-Object -Last 1 `
        | Get-RDSDBLogFilePortion -DBInstanceIdentifier $using:DBInstanceIdentifier -Credential $using:credentials
    }
    while ($true) {
        Receive-Job $j | Where-Object LogFileData | Select-Object -ExpandProperty LogFileData
    }
}

function Set-AwsDefaultProfile {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({ ($secrets.aws.default_profiles_regions.Keys -contains $_) ? $true : $false })]
        [string]$ProfileName
    )
    $default_regions = $secrets.aws.default_profiles_regions

    $Global:aws_profile = $ProfileName
    $env:AWS_DEFAULT_PROFILE = $aws_profile
    [System.Environment]::SetEnvironmentVariable('AWS_DEFAULT_PROFILE', $aws_profile, 'User')

    Set-AWSCredential -ProfileName $ProfileName -Scope Global
    Set-DefaultAWSRegion $default_regions[$ProfileName] -Scope Global

    Write-Host "🟢 Switched to profile: $aws_profile with region $($default_regions[$aws_profile])"
}
