<#
  Installs Colemak-SE (github.com/motform/colemak-se, tag 1.0) and makes it the
  default input method for this user, the welcome screen and new users.

  Run by a FLARE <custom-item> after all packages (both config/*-config.xml).
  The MSI sits in colemak-se\ next to this script on the Desktop (staged by
  dfir-lab) with the DLL folders it installs from, so if this fails, double-click it and pick the layout
  in Settings > Time & language > Language & region. Log: colemak-se.log here.
#>
$ErrorActionPreference = 'Stop'
Start-Transcript (Join-Path $PSScriptRoot 'colemak-se.log') -Force | Out-Null
try {
    $msi = Join-Path $PSScriptRoot 'colemak-se\se-cmak_amd64.msi'
    $p = Start-Process msiexec -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
    if ($p.ExitCode -notin 0, 3010) { throw "msiexec exited $($p.ExitCode)" }

    # MSKLC registers the layout under the first free a0NN041d id, so find it
    # by its DLL rather than hardcoding the id.
    $klid = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts' |
        Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq 'se-cmak.dll' } |
        Select-Object -First 1 -ExpandProperty PSChildName
    if (-not $klid) { throw 'se-cmak.dll is not registered as a keyboard layout' }

    # Pair the layout with the current display language (keeps the UI language)
    # and put it first; the old layouts stay reachable via Win+Space.
    $list = Get-WinUserLanguageList
    $lcid = ([Globalization.CultureInfo]$list[0].LanguageTag).LCID
    $tip = '{0:X4}:{1}' -f $lcid, $klid.ToUpper()
    [void]$list[0].InputMethodTips.Remove($tip)
    $list[0].InputMethodTips.Insert(0, $tip)
    Set-WinUserLanguageList $list -Force
    Set-WinDefaultInputMethodOverride -InputTip $tip
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true

    Write-Host "Colemak-SE enabled: $tip"
} finally {
    Stop-Transcript | Out-Null
}
