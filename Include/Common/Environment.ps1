$c = [cultureinfo]::new('en-GB')
$c.DateTimeFormat.ShortDatePattern = 'dd.MM.yyyy'
[cultureinfo]::CurrentCulture = $c

Import-Module CompletionPredictor -ErrorAction SilentlyContinue

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
    Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -BriefDescription 'Run Atuin search' -ScriptBlock {
        & (Get-Module Atuin) { Invoke-AtuinSearch }
    }
    Set-PSReadLineKeyHandler -Function DigitArgument -Chord @()
}
catch {

}

function global:prompt { Format-CustomPrompt }
# oh-my-posh init pwsh --config "~/.poshthemes/kkthxbye.omp.json" | Invoke-Expression

Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordReverseHistory 'Ctrl+r'
$env:_PSFZF_FZF_DEFAULT_OPTS = '--wrap --height=100%'

Import-Module powershell-yaml

atuin init powershell --disable-up-arrow --disable-ctrl-r | Out-String | Invoke-Expression

if (Test-Path ~/.nvm/nvm.sh) {
    bash -c "source ~/.nvm/nvm.sh; nvm list" | Out-Null

    function nvm {
        bash -c "source ~/.nvm/nvm.sh; nvm $args"
    }

    function node {
        bash -c "source ~/.nvm/nvm.sh; node $args"
    }

    function npm {
        bash -c "source ~/.nvm/nvm.sh; npm $args"
    }
}


