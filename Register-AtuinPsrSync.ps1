param(
    [int]$IntervalMinutes = 5
)

$ErrorActionPreference = "Stop"

$profileItem = Get-Item $PROFILE
$base = if ($profileItem.LinkType) { Split-Path $profileItem.Target } else { Split-Path $profileItem.FullName }
$syncScript = Join-Path $base "Scripts/Invoke-AtuinPsrSync.ps1"
$pwshPath = (Get-Command pwsh).Source

if ($IsWindows) {
    $TaskName = "AtuinPsrSync"

    $action = New-ScheduledTaskAction -Execute $pwshPath `
        -Argument "-NoLogo -NonInteractive -NoProfile -File `"$syncScript`""

    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn
    $repeatingTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
        -RepetitionDuration ([TimeSpan]::MaxValue)

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask -TaskName $TaskName -Action $action `
        -Trigger @($logonTrigger, $repeatingTrigger) -Principal $principal -Settings $settings -Force | Out-Null

    Write-Host "Registered scheduled task '$TaskName': every $IntervalMinutes min while logged on -> $syncScript"
}
elseif ($IsLinux) {
    $unitDir = Join-Path $HOME ".config/systemd/user"
    New-Item -ItemType Directory -Force -Path $unitDir | Out-Null

    $serviceFile = Join-Path $unitDir "atuin-psr-sync.service"
    $timerFile = Join-Path $unitDir "atuin-psr-sync.timer"

    @"
[Unit]
Description=Sync atuin history into the PSReadLine history file

[Service]
Type=oneshot
ExecStart=$pwshPath -NoLogo -NonInteractive -NoProfile -File $syncScript
"@ | Set-Content -LiteralPath $serviceFile -Encoding utf8

    @"
[Unit]
Description=Run atuin-psr-sync periodically

[Timer]
OnBootSec=1min
OnUnitActiveSec=${IntervalMinutes}min
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
"@ | Set-Content -LiteralPath $timerFile -Encoding utf8

    $systemdUp = $false
    try {
        systemctl --user daemon-reload 2>$null
        $systemdUp = $LASTEXITCODE -eq 0
    }
    catch { $systemdUp = $false }

    if ($systemdUp) {
        systemctl --user enable --now atuin-psr-sync.timer | Out-Null
        Write-Host "Enabled systemd --user timer: every $IntervalMinutes min -> $syncScript"
        Write-Host "(Requires systemd=true in .wslconfig and lingering enabled if you want it to run without an open WSL session: loginctl enable-linger $env:USER)"
    }
    else {
        Write-Warning "systemd --user is not available in this WSL distro; falling back to cron."
        $cronLine = "*/$IntervalMinutes * * * * $pwshPath -NoLogo -NonInteractive -NoProfile -File $syncScript >> $HOME/.local/state/atuin-psr-sync/cron.log 2>&1"
        $existing = (crontab -l 2>$null) -split "`n" | Where-Object { $_ -notmatch [regex]::Escape($syncScript) }
        ($existing + $cronLine) -join "`n" | crontab -
        Write-Host "Installed cron entry: every $IntervalMinutes min -> $syncScript"
    }
}
else {
    throw "Unsupported platform."
}
