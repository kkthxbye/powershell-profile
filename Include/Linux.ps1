# if ($env:TERM_PROGRAM -eq "vscode") {
#     . "$(code --locate-shell-integration-path pwsh)"
# }

$env:SHELL = '/usr/bin/pwsh'
$env:EDITOR = 'code --wait'
$env:BROWSER = 'opera.exe'
$env:PATH = (@(
        "$env:HOME/.local/bin/",
        "$env:HOME/bin",
        "$env:HOME/.cargo/bin",
        "$env:HOME/.pyenv",
        "$env:HOME/.pyenv/bin",
        "$env:HOME/.nvm",
        "$env:HOME/.uv/venvs/bin/",
        "$env:HOME/go/bin/",
        "$env:HOME/.duckdb/cli/latest/duckdb",
        "$env:HOME/.terragrunt/bin"
        # $(~/bin/trdl bin-path werf 1.2 stable)
    ) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"

$null = Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -MaxTriggerCount 1 -Action {
    $env:PATH = (@(
            $(~/bin/trdl bin-path werf 1.2 stable)
        ) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"
    Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

Import-Module PsqlPs
Import-Module MySqlPs
