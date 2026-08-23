function Get-PsrHistory {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}

function Export-AtuinHistoryToPsr {
    if (-not (Get-Command atuin -ErrorAction Ignore)) {
        Write-Error "atuin executable not found in PATH."
        return
    }

    $path = (Get-PSReadlineOption).HistorySavePath
    $commands = atuin history list --cmd-only --reverse false | Where-Object { $_ -ne '' }
    Set-Content -LiteralPath $path -Value $commands -Encoding utf8

    "Wrote $($commands.Count) command(s) from atuin history to $path"
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
