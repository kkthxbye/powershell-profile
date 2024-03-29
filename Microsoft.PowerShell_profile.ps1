Set-PSReadLineOption -EditMode Windows `
    -PredictionSource HistoryAndPlugin `
    -HistoryNoDuplicates `
    -MaximumHistoryCount 50000 `
    -ShowToolTips `
    -PredictionViewStyle ListView

$env:SHELL = '/usr/bin/pwsh'
$env:EDITOR = 'mcedit'
$env:PATH += @(
    '',
    '~/.local/bin/',
    '~/bin',
    '/home/linuxbrew/.linuxbrew/bin',
    '/.cargo/bin',
    $(~/bin/trdl bin-path werf 1.2 stable)
) | Join-String -Separator ":"

oh-my-posh --init --shell pwsh --config ~/.poshthemes/kkthxbye.omp.json | Invoke-Expression

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
