$c = [cultureinfo]::new('en-GB')
$c.DateTimeFormat.ShortDatePattern = 'dd.MM.yyyy'
[cultureinfo]::CurrentCulture = $c

$PSReadLineOptions = @{
    EditMode = 'Windows'
    PredictionSource = 'HistoryAndPlugin'
    HistoryNoDuplicates = $true
    MaximumHistoryCount = 100000
    PredictionViewStyle = 'ListView'
    ContinuationPrompt = ''
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
        [string]$Query
    )
    $tmp = $env:PGSERVICE
    $env:PGSERVICE = $ConnectionAlias
    psql --csv --command "$Query" | ConvertFrom-Csv
    $env:PGSERVICE = $tmp
}

function sqlite3ps {
    sqlite3 --csv --header $args | ConvertFrom-Csv
}

function Get-PsrHistory {
    Get-Content (Get-PSReadlineOption).HistorySavePath
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
        $r = (Invoke-WebRequest `
            -Authentication Basic `
            -Credential $cred `
            $progressive_url `
            -Body @{'start'=$start}
        );
        $start = [int]$r.Headers.'X-Text-Size'[0];
        $done = $null -eq  $r.Headers.'X-More-Data';
        Write-Host -NoNewline $r.Content;
        Start-Sleep $Period;
    } while (!$done)
}
