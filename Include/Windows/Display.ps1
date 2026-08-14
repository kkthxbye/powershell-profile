function Start-MonitorStandby {
    $j = Start-ThreadJob {
        Add-Type -TypeDefinition @"
  using System;
  using System.Runtime.InteropServices;
  public class MonitorControl {
      [DllImport("user32.dll", CharSet = CharSet.Auto)]
      public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);
  }
"@

        $HWND_BROADCAST = [intptr]0xffff
        $WM_SYSCOMMAND = 0x0112
        $SC_MONITORPOWER = 0xF170
        $MONITOR_OFF = 2

        [MonitorControl]::SendMessage($HWND_BROADCAST, $WM_SYSCOMMAND, [intptr]$SC_MONITORPOWER, [intptr]$MONITOR_OFF)
    }

    $j | Wait-Job -Timeout 1 | Stop-Job
}

function Start-TvSession {
    param(
        [Parameter(Position = 0)]
        [bool]$WithSteam = $false,

        [Parameter(Position = 0)]
        [bool]$SwitchPrimary = $true
    )

    $mmt = $configs.Windows.MultiMonTool
    $cfg_path = $mmt.TvLayoutPath

    $mmt.TvLayoutContent | Out-File "$cfg_path"

    $tv = $mmt.TvMonitorId
    $tv_speakers = $mmt.TvSpeakers

    multimonitortool /enable "$tv"
    Start-Sleep -Seconds 2
    multimonitortool /loadconfig "$cfg_path"
    if ($SwitchPrimary) {
        Start-Sleep -Seconds 2
        multimonitortool /setprimary "$tv"
    }

    if ($WithSteam) {
        Stop-Process -Name "steam"
        steam -bigpicture
    }

    Select-AudioDevice "$tv_speakers"
}

function Stop-TvSession {
    param(
        [Parameter(Position = 0)]
        [bool]$WithSteam = $false,

        [Parameter(Position = 0)]
        [bool]$SwitchPrimary = $true
    )

    $mmt = $configs.Windows.MultiMonTool
    $cfg_path = $mmt.DefaultLayoutPath
    $mmt.DefaultLayoutContent | Out-File "$cfg_path"

    $tv = $mmt.TvMonitorId
    $monitor = $mmt.DesktopMonitorId
    $desktop_speakers = $mmt.DesktopSpeakers

    multimonitortool /loadconfig "$cfg_path"
    Start-Sleep -Seconds 2

    if ($SwitchPrimary) {
        multimonitortool /setprimary "$monitor"
        Start-Sleep -Seconds 1
    }

    multimonitortool /disable "$tv"
    Start-Sleep -Seconds 2

    Select-AudioDevice "$desktop_speakers"
}
