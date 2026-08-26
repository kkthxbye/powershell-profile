$c = [cultureinfo]::new('en-GB')
$c.DateTimeFormat.ShortDatePattern = 'dd.MM.yyyy'
[cultureinfo]::CurrentCulture = $c

Import-Module CompletionPredictor

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
try {
    Set-PSReadLineOption @PSReadLineOptions

    Set-PSReadLineOption -Colors @{
        "Operator" = "`e[38;2;150;150;150m"
        "Parameter" = "`e[38;2;150;150;150m"
    }
} catch {
    # No interactive console available (e.g. non-interactive SSH exec) - skip PSReadLine setup
}

# function global:prompt { Format-CustomPrompt }
oh-my-posh init pwsh --config "~/.poshthemes/kkthxbye.omp.json" | Invoke-Expression

Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
$env:_PSFZF_FZF_DEFAULT_OPTS = '--wrap --height=100%'

Import-Module powershell-yaml

atuin init powershell --disable-up-arrow --disable-ctrl-r | Out-String | Invoke-Expression
