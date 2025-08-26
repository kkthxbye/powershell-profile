# Set-PSDebug -Trace 1

$secrets = . "$(Split-Path $PROFILE)\secrets.ps1"

$c = [cultureinfo]::new('en-GB')
$c.DateTimeFormat.ShortDatePattern = 'dd.MM.yyyy'
[cultureinfo]::CurrentCulture = $c

$PSReadLineOptions = @{
    EditMode = 'Windows'
    PredictionSource = 'HistoryAndPlugin'
    HistoryNoDuplicates = $true
    MaximumHistoryCount = 100000
    PredictionViewStyle = 'ListView'
    ContinuationPrompt = $null
    AddToHistoryHandler = $null
    WordDelimiters = ";:,.[]{}()/\|^&*-=+'`"---_"
}
Set-PSReadLineOption @PSReadLineOptions

$env:SHELL = '/usr/bin/pwsh'
$env:EDITOR = 'mcedit'
$env:PATH = (@(
    "$env:HOME/.local/bin/",
    "$env:HOME/bin",
    '/home/linuxbrew/.linuxbrew/bin',
    '/.cargo/bin',
    "$env:HOME/.pyenv",
    "$env:HOME/.pyenv/bin",
    "$env:HOME/.nvm"
    # $(~/bin/trdl bin-path werf 1.2 stable)
) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"

oh-my-posh init pwsh --config ~/.poshthemes/kkthxbye.omp.json | Invoke-Expression

Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

$env:_PSFZF_FZF_DEFAULT_OPTS = '--wrap'

Import-Module powershell-yaml

$null = Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -MaxTriggerCount 1 -Action {
        $env:PATH = (@(
        $(~/bin/trdl bin-path werf 1.2 stable)
    ) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"
    Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Invoke-Expression "pyenv init - pwsh"
# Invoke-Expression "pyenv virtualenv-init -"

# TODO Look into https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.crescendo/about/about_crescendo
function snowsqlps {
    # TODO: EWWWWWWW
    snowsql --config ~/.snowsql/csv --query "ALTER USER SET MINS_TO_BYPASS_MFA = 60;" | Out-Null;
    snowsql --config ~/.snowsql/csv $args | Out-String | ConvertFrom-Csv
}

function psqlps {
    param (
        [Parameter(Mandatory, Position=0)]
        [string]$ConnectionAlias,

        [Parameter(Mandatory, Position=1)]
        [string]$Query,

        [Parameter(ValueFromPipeline)]
        [string]$InputObject
    )
    $tmp = $env:PGSERVICE
    $env:PGSERVICE = $ConnectionAlias
    if ($MyInvocation.ExpectingInput){
        $input | & psql @args --csv --command "$Query" | Out-String | ConvertFrom-Csv
    } else {
        & psql @args --csv --command "$Query" | Out-String | ConvertFrom-Csv
    }

    $env:PGSERVICE = $tmp
}

function sqlite3ps {
    sqlite3 --csv --header $args | ConvertFrom-Csv
}

function Get-PsrHistory {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}

function Enter-AwsSession {
    $j = Start-ThreadJob {
        aws sso login --no-browser --profile 'sm-dev'
    }
    do {
        $url = Receive-Job $j -Keep | Select-String -NoEmphasis "user_code"
        $url
    } while (!$url)
    Receive-Job $j | Out-Null
    opera.exe --app-url "$url"
    $j | Wait-Job | Receive-Job
}

function Write-Newlines {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string[]]$s
    )

    PROCESS {
        $s -replace "\\\\n",  "`n"`
            -replace "\\n", "`n" `
            -replace "\\t", "`t" `
            -replace "\\r" , "`r"`
    }
}

function Watch-JenkinsLog {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter()]
        [string]$Username = $secrets.jenkins.username,

        [Parameter()]
        [string]$TokenPath = "./.jenkins",

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
                -Body @{'start'=$start}
            )
        } catch {
            $_.Exception.Response
        }

        $start = [int]$r.Headers.'X-Text-Size'[0];
        $done = $null -eq  $r.Headers.'X-More-Data';
        Write-Host -NoNewline $r.Content;
        Start-Sleep $Period;
    } while (!$done)
}

function Wait-RDSDBLog {
    param(
        [Parameter(Mandatory, Position=0)]
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
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({($secrets.aws.default_profiles_regions.Keys -contains $_) ? $true : $false})]
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


function Invoke-Make {
    $escapedArgs = $args | ForEach-Object { $_ -replace "'", "''" }
    $rawArgs = $escapedArgs -join ' '
    $cmd = "make --% SHELL=/bin/bash $rawArgs"
    Invoke-Expression $cmd
}

function Enter-PythonVenv {
    $a = "Activate.ps1"
    $a, $a.ToLower() | ForEach-Object {
        $path = "./.venv/bin/$_"; $path
    } | Where-Object { Test-Path $_ } | ForEach-Object {
        . $_
        "Activated venv: $_"
    }
}
