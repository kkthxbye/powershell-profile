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

# helm completion powershell | Out-String | Invoke-Expression
# Import-Module posh-dotnet
# Import-Module DockerCompletion
# Import-Module posh-git
# Import-Module PSKubectlCompletion
# Import-Module npm-completion

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
    $env:PGSERVICE = $ConnectionAlias
    psql --csv --command "$Query" | ConvertFrom-Csv
}

function sqlite3ps {
    sqlite3 --csv --header $args | ConvertFrom-Csv
}
