$env:SHELL = '/usr/bin/pwsh'
$env:EDITOR = 'code --wait'
$env:BROWSER = 'opera.exe'
$env:PATH = @(
    "$env:HOME/.local/bin/",
    "$env:HOME/bin",
    "$env:HOME/.cargo/bin",
    "$env:HOME/.pyenv",
    "$env:HOME/.pyenv/bin",
    "$env:HOME/.nvm",
    "$env:HOME/.uv/venvs/bin/",
    "$env:HOME/go/bin/",
    "$env:HOME/.duckdb/cli/latest/duckdb",
    "$env:HOME/.terragrunt/bin",
    "/home/linuxbrew/.linuxbrew/bin/"
    $env:PATH
) -join ":"
