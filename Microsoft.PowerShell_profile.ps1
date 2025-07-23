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
    $(~/bin/trdl bin-path werf 1.2 stable)
) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"

oh-my-posh init pwsh --config ~/.poshthemes/kkthxbye.omp.json | Invoke-Expression

Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

$env:_PSFZF_FZF_DEFAULT_OPTS = '--wrap'

Import-Module powershell-yaml

# TODO Look into https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.crescendo/about/about_crescendo
function snowsqlps {
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

function Authorize-Aws {
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
        [Parameter(Mandatory, Position=0)]
        [string]$Url,

        [Parameter(Mandatory, Position=1)]
        [string]$Username,

        [Parameter(Mandatory, Position=2)]
        [string]$TokenPath,

        [Parameter(Position=3)]
        [float]$Period = 1
    )
    $progressive_url = $Url.TrimEnd('/'), 'logText', 'progressiveText' -join "/"
    $key = Get-Content $TokenPath;
    $cred = New-Object System.Management.Automation.PSCredential($Username, $(ConvertTo-SecureString $key -AsPlainText));
    $start = 0;
    do {
        try {
            $r = (Invoke-WebRequest `
                -verbose `
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
