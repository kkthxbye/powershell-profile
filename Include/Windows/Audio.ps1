function Select-AudioDevice {
    <#
    .LINK
    https://github.com/frgnca/AudioDeviceCmdlets
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Device
    )

    (Get-AudioDevice -List `
  | Where-Object { ($_.name -ilike "*$Device*") -and ($_.type -eq 'Playback') -and (-not $_.default) } `
  | Select-Object -First 1 `
  ) `
  | Set-AudioDevice | Select-Object Name
}
