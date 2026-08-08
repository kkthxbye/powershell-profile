$env:SNOWFLAKE_DISABLE_PLATFORM_DETECTION = 'true'
function snowsqlps {
    snow sql --silent --format csv $args | Out-String | ConvertFrom-Csv
}

function sqlite3ps {
    sqlite3 --csv --header $args | ConvertFrom-Csv
}

function Watch-JenkinsLog {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter()]
        [string]$Username = $secrets.jenkins.username,

        [Parameter()]
        [string]$TokenPath = $(if ($IsWindows) { "./.jenkins" } else { "~/.jenkins" }),

        [Parameter()]
        [float]$Period = 1
    )
    $progressive_url = $Url.TrimEnd('/'), 'logText', 'progressiveText' -join "/"
    $key = Get-Content $TokenPath;
    $cred = New-Object System.Management.Automation.PSCredential($Username, $(ConvertTo-SecureString $key -AsPlainText));
    $start = 0;
    do {
        try {
            $r = (Invoke-WebRequest `
                    -Authentication Basic `
                    -Credential $cred `
                    $progressive_url `
                    -Body @{'start' = $start }
            )
        }
        catch {
            $_.Exception.Response
        }

        $start = [int]$r.Headers.'X-Text-Size'[0];
        $done = $null -eq $r.Headers.'X-More-Data';
        Write-Host -NoNewline $r.Content;
        Start-Sleep $Period;
    } while (!$done)
}
