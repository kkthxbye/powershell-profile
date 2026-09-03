function Get-PsrHistory {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}

function Export-AtuinHistoryToPsr {
    <#
    .PARAMETER Full
        Force a full re-export instead of syncing only what's new since the last run.
    #>
    [CmdletBinding()]
    param(
        [switch]$Full
    )

    if (-not (Get-Command atuin -ErrorAction Ignore)) {
        Write-Error "atuin executable not found in PATH."
        return
    }

    $path = (Get-PSReadlineOption).HistorySavePath

    $stateDir = Join-Path $HOME ".local/state/atuin-psr-sync"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    $cursorPath = Join-Path $stateDir "cursor"
    $lockPath = Join-Path $stateDir "sync.lock"

    try {
        $lock = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    }
    catch [System.IO.IOException] {
        Write-Verbose "Export-AtuinHistoryToPsr: a sync is already in progress; skipping."
        return
    }

    try {
        $cursor = if (-not $Full -and (Test-Path -LiteralPath $cursorPath)) {
            (Get-Content -LiteralPath $cursorPath -Raw).Trim()
        }

        $syncedThrough = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')

        $merged = if ($cursor) {
            atuin search --after $cursor --format "{time}`t{command}" --print0 2>&1
        }
        else {
            atuin history list --format "{time}`t{command}" --print0 2>&1
        }

        $raw = $merged | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
        $stderr = ($merged | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join "`n"
        if ($LASTEXITCODE -ne 0 -and $stderr) {
            Write-Error "atuin history query failed (exit $LASTEXITCODE): $stderr`nLeaving $path untouched."
            return
        }

        $records = ($raw -join "`n") -split "`0" | Where-Object { $_ -ne '' }
        if (-not $records) {
            Set-Content -LiteralPath $cursorPath -Value $syncedThrough
            if ($cursor) { "No new commands since last sync." } else { Write-Error "atuin returned no history; leaving $path untouched." }
            return
        }

        $commands = $records | ForEach-Object {
            $time, $cmd = $_ -split "`t", 2
            [pscustomobject]@{ Time = $time; Command = $cmd }
        } | Sort-Object Time | Select-Object -ExpandProperty Command

        $continuation = [char]96 + "`n"
        $lines = $commands | ForEach-Object { ($_ -split "`n") -join $continuation }

        if ($cursor) {
            Add-Content -LiteralPath $path -Value $lines -Encoding utf8
        }
        else {
            Set-Content -LiteralPath $path -Value $lines -Encoding utf8
        }
        Set-Content -LiteralPath $cursorPath -Value $syncedThrough

        "Wrote $($commands.Count) command(s) from atuin history to $path"
    }
    finally {
        $lock.Close()
        $lock.Dispose()
    }
}

function Write-Newlines {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline)]
        [string[]]$s
    )

    PROCESS {
        $s.Replace('\\n', "`n").Replace('\n', "`n").Replace('\t', "`t").Replace('\r', "`r")
    }
}

function Invoke-Make {
    $escapedArgs = $args | ForEach-Object { $_.Replace("'", "''") }
    $rawArgs = $escapedArgs -join ' '
    $cmd = "make --% SHELL=/bin/bash $rawArgs"
    Invoke-Expression $cmd
}

function Enter-PythonVenv {
    $a = "Activate.ps1"
    $bin_path = $isWindows ? 'Scripts' : 'bin'
    $a, $a.ToLower() | ForEach-Object {
        $path = "./.venv/$bin_path/$_"; $path
    } | Where-Object { Test-Path $_ } | Select-Object -First 1 | ForEach-Object {
        . $_
        "🟢 Activated venv: $_"
    }
}

function Get-WordWrappedString {
    param(
        [Parameter(ValueFromPipeline = $true)] $InputObject,
        [Parameter(Position = 0)] [int]$Width = 80
    )
    process {
        $InputObject | python -c @"
import fileinput
from itertools import takewhile
from sys import stdout

def wrap_words(text, width):
    words = iter(text.split())
    while True:
        line = []
        length = 0
        for word in takewhile(lambda w: length + len(w) + (1 if line else 0) <= width, words):
            line.append(word)
            length += len(word) + (1 if line else 0)
        if not line:
            break
        yield " ".join(line)

stdout.writelines(
    "\n".join(wrap_words(" ".join(s.strip() for s in fileinput.input()), width=$Width))
)
"@
    }
}

function Expand-Property {
    param(
        [Parameter(ValueFromPipeline)] $InputObject,
        [Parameter(Position = 0)] [string]$Property
    )

    process {
        $current = $InputObject
        foreach ($part in $Property -split '\.') {
            if ($null -ne $current) {
                $current = $current.$part
            }
        }
        $current
    }
}

Set-Alias takeprop Expand-Property

function Watch-Command {
    <#
    .SYNOPSIS
        Repeatedly invokes a command, emitting its output prefixed with a timestamp.
        Runs forever - stop with Ctrl+C.
    .EXAMPLE
        { Get-Random -Maximum 100 } | Watch-Command -IntervalSeconds 1
    .EXAMPLE
        Watch-Command -IntervalSeconds 1 { Get-Random -Maximum 100 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [scriptblock]$Command,

        [Parameter(Position = 1)]
        [int]$IntervalSeconds = 60
    )

    process {
        while ($true) {
            $now = Get-Date -Format 'HH:mm:ss'
            & $Command | ForEach-Object {
                if ($_ -is [ValueType] -or $_ -is [string]) {
                    [pscustomobject]@{ Time = $now; Value = $_ }
                }
                else {
                    $_ | Select-Object @{Name = 'Time'; Expression = { $now } }, *
                }
            }
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

function ConvertTo-JiraTable {
    begin { $rows = @() }
    process { if ($_ -ne $null) { $rows += $_ } }
    end {
        if (-not $rows) { throw "ConvertTo-JiraTable: no input received." }

        $cols = $rows[0].PSObject.Properties.Name

        $header = "| " + ($cols -join " | ") + " |"
        $sep = "| " + (($cols | ForEach-Object { "---" }) -join " | ") + " |"

        $body = $rows | ForEach-Object {
            $row = $_;
            "| " + (($cols | ForEach-Object {
                        ($row.$_ | Out-String).Trim()
                    }) | join-string -separator " | ") + " |"
        } | join-string -separator "`n"

        ($header, $sep, $body) -join "`n"
    }
}
