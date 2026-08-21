function Backup-SettingsFile {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return }

    $backupDir = Join-Path (Split-Path $Path) '.theme-backups'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

    $name = Split-Path $Path -Leaf
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -LiteralPath $Path -Destination (Join-Path $backupDir "$name.$stamp.bak") -Force

    Get-ChildItem $backupDir -Filter "$name.*.bak" `
        | Sort-Object LastWriteTime -Descending `
        | Select-Object -Skip 5 `
        | Remove-Item -Force
}

function Restore-SettingsFile {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $backupDir = Join-Path (Split-Path $Path) '.theme-backups'
    $name = Split-Path $Path -Leaf
    $latest = Get-ChildItem $backupDir -Filter "$name.*.bak" -ErrorAction SilentlyContinue `
        | Sort-Object LastWriteTime -Descending `
        | Select-Object -First 1

    if (-not $latest) {
        Write-Warning "No backup found for $Path"
        return
    }

    Copy-Item -LiteralPath $latest.FullName -Destination $Path -Force
    Write-Host "Restored $Path from $($latest.Name)" -ForegroundColor DarkGray
}

function Get-SystemTheme {
    $value = Get-ItemPropertyValue `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
        -Name AppsUseLightTheme
    if ($value) { 'Light' } else { 'Dark' }
}

function Set-VSCodeTheme {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Light', 'Dark')]
        [string]$Theme
    )

    $path = Join-Path $env:APPDATA 'Code\User\settings.json'
    if (-not (Test-Path $path)) { return }

    Backup-SettingsFile $path
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $json.'workbench.colorTheme' = if ($Theme -eq 'Dark') { 'Dark Modern' } else { 'Light Modern' }
    $json | ConvertTo-Json -Depth 20 | Set-Content $path
}

function Set-WindowsTerminalTheme {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Light', 'Dark')]
        [string]$Theme
    )

    $path = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path $path)) { return }

    Backup-SettingsFile $path
    $json = Get-Content $path -Raw | ConvertFrom-Json
    $json.profiles.defaults.colorScheme = if ($Theme -eq 'Dark') { 'Tango Dark' } else { 'Tango Light' }
    $json | ConvertTo-Json -Depth 20 | Set-Content $path
}

function Set-Theme {
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Light', 'Dark')]
        [string]$Theme
    )

    Set-VSCodeTheme $Theme
    Set-WindowsTerminalTheme $Theme
    Write-Host "Theme set to $Theme. Restart VS Code / open a new Windows Terminal tab to see it." -ForegroundColor DarkGray
}

function Switch-Theme {
    $path = Join-Path $env:APPDATA 'Code\User\settings.json'
    $current = if (Test-Path $path) {
        (Get-Content $path -Raw | ConvertFrom-Json).'workbench.colorTheme'
    }

    $next = if ($current -match 'Light') { 'Dark' } else { 'Light' }
    Set-Theme $next
}

function Sync-SystemTheme {
    Set-Theme (Get-SystemTheme)
}

function Restore-Theme {
    Restore-SettingsFile (Join-Path $env:APPDATA 'Code\User\settings.json')
    Restore-SettingsFile (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
}
