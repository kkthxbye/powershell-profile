$null = Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -MaxTriggerCount 1 -Action {
    $env:PATH = (@(
            $(~/bin/trdl bin-path werf 1.2 stable)
        ) | Join-String -Separator ":"), $env:PATH | Join-String -Separator ":"
    Set-PsFzfOption -EnableAliasFuzzyHistory -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
