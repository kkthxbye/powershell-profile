function Get-GitPromptSegment {
    $status = git status --porcelain=v2 --branch 2 > $null
    if (-not $status) { return $null }

    $branch = $null
    $ahead = 0; $behind = 0
    $dirty = $false

    foreach ($line in $status) {
        if ($line.StartsWith('# branch.head ')) {
            $branch = $line.Substring(14)
        }
        elseif ($line.StartsWith('# branch.ab ')) {
            $parts = $line.Substring(12).Split(' ')
            $ahead = [int]$parts[0].TrimStart('+')
            $behind = [int]$parts[1].TrimStart('-')
        }
        elseif (-not $line.StartsWith('#')) {
            $dirty = $true
        }
    }

    if ($branch -eq '(detached)') {
        $branch = (git rev-parse --short HEAD 2>$null)
    }

    $suffix = @()
    if ($ahead -gt 0) { $suffix += "^$ahead" }
    if ($behind -gt 0) { $suffix += "v$behind" }
    if ($dirty) { $suffix += '*' }

    if ($suffix) { "$branch $($suffix -join ' ')" } else { $branch }
}

function Format-CustomPrompt {
    $esc = [char]27
    $reset = "$esc[0m"
    $navy = "$esc[38;2;16;14;35m"
    $green = "$esc[38;2;144;238;144m"
    $mint = "$esc[38;2;109;255;158m"
    $blue = "$esc[38;2;173;216;230m"
    $purple = "$esc[38;2;173;127;168m"

    $sb = [System.Text.StringBuilder]::new()

    $isAdmin = if ($IsWindows) {
        ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        (id -u) -eq 0
    }
    if ($isAdmin) {
        [void]$sb.Append($navy).Append(" `u{f0e7} ").Append($reset)
    }

    $userName = if ($IsWindows) { $env:USERNAME } else { $env:USER }
    $sshIcon = if ($env:SSH_CONNECTION -or $env:SSH_CLIENT) { "`u{f817} " } else { '' }
    [void]$sb.Append($green).Append("$sshIcon$userName@$([System.Net.Dns]::GetHostName()) ").Append($reset)

    if ($env:VIRTUAL_ENV) {
        [void]$sb.Append($mint).Append("($(Split-Path $env:VIRTUAL_ENV -Leaf)) ").Append($reset)
    }

    [void]$sb.Append($blue).Append("$($PWD.Path) ").Append($reset)

    $git = Get-GitPromptSegment
    if ($git) {
        [void]$sb.Append($purple).Append('(').Append($reset)
        [void]$sb.Append($green).Append($git).Append($reset)
        [void]$sb.Append($purple).Append(') ').Append($reset)
    }

    $promptChar = if ($IsWindows) { '>' } else { '$' }
    [void]$sb.Append($blue).Append("$promptChar ").Append($reset)

    $sb.ToString()
}

function Enable-CustomPrompt {
    function global:prompt { Format-CustomPrompt }
    Write-Host 'Custom prompt enabled. Run Enable-PoshPrompt to switch back.' -ForegroundColor DarkGray
}

function Enable-PoshPrompt {
    oh-my-posh init pwsh --config "~/.poshthemes/kkthxbye.omp.json" | Invoke-Expression
    Write-Host 'oh-my-posh prompt enabled. Run Enable-CustomPrompt to switch back.' -ForegroundColor DarkGray
}
