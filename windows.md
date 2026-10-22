---
title: Windows 11
permalink: /windows/
pm: winget
packages:
  - Git.Git
  - GitHub.cli
  - Microsoft.WindowsTerminal
# Built-in apps offered for removal, in groups. `id` is the version-free
# package name winget matches against (see `winget list`).
remove:
  - group: News, tips and feedback
    apps:
      - { id: Microsoft.BingNews, name: News }
      - { id: Microsoft.BingWeather, name: Weather }
      - { id: Microsoft.BingSearch, name: Bing Search }
      - { id: Microsoft.Getstarted, name: Tips }
      - { id: Microsoft.GetHelp, name: Get Help }
      - { id: Microsoft.WindowsFeedbackHub, name: Feedback Hub }
  - group: Microsoft 365, Outlook, Teams and OneDrive
    apps:
      - { id: Microsoft.MicrosoftOfficeHub, name: Microsoft 365 app }
      - { id: Microsoft.OutlookForWindows, name: Outlook (new) }
      - { id: MSTeams, name: Teams }
      - { id: Microsoft.OneDrive, name: OneDrive }
  - group: Copilot
    apps:
      - { id: Microsoft.Copilot, name: Copilot }
  - group: Xbox and games
    apps:
      - { id: Microsoft.GamingApp, name: Xbox }
      - { id: Microsoft.XboxGamingOverlay, name: Xbox Game Bar }
      - { id: Microsoft.MicrosoftSolitaireCollection, name: Solitaire }
  - group: Small apps
    apps:
      - { id: Clipchamp.Clipchamp, name: Clipchamp }
      - { id: Microsoft.Todos, name: To Do }
      - { id: Microsoft.PowerAutomateDesktop, name: Power Automate }
      - { id: Microsoft.YourPhone, name: Phone Link }
      - { id: MicrosoftCorporationII.QuickAssist, name: Quick Assist }
      - { id: Microsoft.MicrosoftStickyNotes, name: Sticky Notes }
      - { id: Microsoft.WindowsSoundRecorder, name: Sound Recorder }
      - { id: MicrosoftCorporationII.MicrosoftFamily, name: Family }
      - { id: Microsoft.ZuneMusic, name: Media Player }
---

## Before you start

Run everything in an elevated terminal: **Win+X → Terminal (Admin)**.

Allow scripts and modules to run (needed for the Windows Update module below). `Bypass` turns off script checks for every user on this machine; it applies to Windows PowerShell; PowerShell 7 gets its own setting in the **PowerShell 7** section:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
Get-ExecutionPolicy -List
```

`LocalMachine` should show `Bypass`. If a `MachinePolicy` or `UserPolicy` row is set, Group Policy is overriding it.

## Time zone

{% include timezone.md %}

## Remove apps

Do this before **Update**, so the updates don't spend time upgrading apps that are about to be removed.

{% include remove.md %}

## Update

Install the PSWindowsUpdate module (once per machine). It's downloaded straight from the PowerShell Gallery, pinned and checksum-checked like the MSIs below, so it doesn't need `Install-Module`, the NuGet provider or the Gallery's search:

```powershell
{% include ps-module.md name="PSWindowsUpdate" %}
Import-Module PSWindowsUpdate
Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
```

The last line turns on Microsoft Update (the same as **Settings → Windows Update → Advanced options → Receive updates for other Microsoft products**), so `-MicrosoftUpdate` below doesn't have to register it on the fly. If a `Get-WindowsUpdate` command still fails with "Value does not fall within the expected range", wait a minute and run it again: Windows Update can still be starting up right after boot.

Install all Windows updates, including drivers and other Microsoft products, rebooting automatically if needed. Run it again after each reboot until it finds nothing. The first line starts the Windows Update service, which stops itself when idle and can't be started while it's still stopping (common right after first boot):

```powershell
while ((Get-Service wuauserv).Status -eq 'StopPending') { Start-Sleep 2 }; Start-Service wuauserv
Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -AutoReboot
```

To see what's pending without installing anything:

```powershell
while ((Get-Service wuauserv).Status -eq 'StopPending') { Start-Sleep 2 }; Start-Service wuauserv
Get-WindowsUpdate -MicrosoftUpdate
```

**Update for Windows Security platform (KB5007651)** can show up again on every run, even though each run reports it as installed. Once it's the only thing left, Windows is up to date; it stops appearing after the Security app updates itself through the Store.

Tell the Microsoft Store to check for and install updates for all Store apps. It runs in the background; progress shows in **Store → Downloads**:

```powershell
Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
```

Update winget itself first. A fresh install ships an older App Installer (which provides `winget`), and winget can't replace itself mid-run: `winget upgrade` stops with "Restart the application" or "file in use". Microsoft's WinGet PowerShell module updates it and its dependencies from outside winget:

```powershell
{% include ps-module.md name="Microsoft.WinGet.Client" %}
Import-Module Microsoft.WinGet.Client
Repair-WinGetPackageManager -Latest
winget --version
```

{% include update.md %}

## Install

{% include install.md %}

**Over SSH (no desktop session):** the `winget` command, and the PowerShell module's usual mode, only work in a desktop session, so the block above fails when run over SSH. This installs the same packages from an SSH session: PowerShell 7 from its MSI, then Microsoft's WinGet PowerShell module, which runs the installs as SYSTEM through a one-off scheduled task. Store (MSIX) apps such as Windows Terminal can't be installed this way, but Windows 11 already includes Terminal.

```powershell
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
if (-not (Test-Path $pwsh)) {
    $msi = "$env:TEMP\PowerShell-7-win-x64.msi"
    Invoke-WebRequest '{{ site.pwsh_msi.url }}' -OutFile $msi -UseBasicParsing
    if ((Get-FileHash $msi -Algorithm SHA256).Hash -ne '{{ site.pwsh_msi.sha256 }}') { throw 'PowerShell MSI checksum mismatch; not installing.' }
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
}
{% include ps-module.md name="Microsoft.WinGet.Client" %}
$ids = @({% assign first = true %}{% for p in page.packages %}{% unless p == 'Microsoft.WindowsTerminal' %}{% unless first %}, {% endunless %}'{{ p }}'{% assign first = false %}{% endunless %}{% endfor %})
$script = "$env:ProgramData\winget-over-ssh.ps1"
$log = "$env:ProgramData\winget-over-ssh.log"
Set-Content -Path $script -Value (@('Import-Module Microsoft.WinGet.Client') + ($ids | ForEach-Object { "Install-WinGetPackage -Id $_ -Source winget -Mode Silent -Scope System | Select-Object Id, Status, InstallerErrorCode" }))
Register-ScheduledTask -TaskName winget-over-ssh -User SYSTEM -RunLevel Highest -Force -Action (New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -Command & '$script' *> '$log'") | Out-Null
Start-ScheduledTask -TaskName winget-over-ssh
do { Start-Sleep 5 } while ((Get-ScheduledTask -TaskName winget-over-ssh).State -eq 'Running')
Unregister-ScheduledTask -TaskName winget-over-ssh -Confirm:$false
Get-Content $log
```

## PowerShell 7

Install the latest stable PowerShell 7. Run the same command later to update it (winget upgrades it if it's already installed; `winget upgrade --all` also keeps it current). Run it from Windows PowerShell rather than from PowerShell 7 itself, so the installer isn't replacing the shell it's running in:

```powershell
winget install --id Microsoft.PowerShell -e --source winget --installer-type wix --accept-source-agreements --accept-package-agreements
```

`--installer-type wix` picks the classic MSI, which installs to `C:\Program Files\PowerShell\7`. Without it, winget now defaults to the MSIX package, which lands in a versioned WindowsApps folder that the SSH step below can't point to. If an MSIX or Store copy is already installed, both can coexist.

Allow scripts in PowerShell 7 too; it keeps its own execution policy, separate from Windows PowerShell. `Set-ExecutionPolicy` in PowerShell 7 saves it in a file in the install folder, which every PowerShell update replaces, so set it as a machine policy in the registry instead. That survives updates and shows as the `MachinePolicy` row:

```powershell
$p = "HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore"
if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name EnableScripts -Type DWord -Value 1
Set-ItemProperty -Path $p -Name ExecutionPolicy -Type String -Value Bypass
& "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -Command "Get-ExecutionPolicy -List"
```

Make PowerShell 7 the default Windows Terminal profile, so new tabs and **Win+X → Terminal (Admin)** open it:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$line = "`"defaultProfile`": `"{574e775e-4f2a-5b96-ac1e-a2962a402336}`""
$json = if (Test-Path $wt) { [IO.File]::ReadAllText($wt) } else { "" }
if ($json -match '"defaultProfile"\s*:') {
    $json = $json -replace '"defaultProfile"\s*:\s*"[^"]*"', $line
} elseif ($json -match '^[^{]*\{\s*("|//)') {
    $json = $json -replace '^([^{]*\{)', "`$1`n    $line,"
} else {
    if ($json) { Copy-Item $wt "$wt.bak" -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $wt) | Out-Null
    $json = "{ $line }"
}
[IO.File]::WriteAllText($wt, $json, [Text.UTF8Encoding]::new($false))
Select-String -Path $wt -Pattern '"defaultProfile"'
```

It replaces an existing `defaultProfile`, or adds one if the file has none. If Terminal has never been opened, or the file is empty or damaged (for example after a crash), it saves any old file as `settings.json.bak` and writes one with just the default profile; Terminal fills in the rest on first launch. Close and reopen Terminal; the PowerShell 7 profile appears once Terminal detects the new install.

Make PowerShell 7 the shell for incoming SSH sessions (the default is `cmd.exe`):

```powershell
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
if (Test-Path $pwsh) {
    if (-not (Test-Path "HKLM:\SOFTWARE\OpenSSH")) { New-Item -Path "HKLM:\SOFTWARE\OpenSSH" | Out-Null }
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $pwsh -PropertyType String -Force | Out-Null
    Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell
} else {
    Write-Warning "$pwsh not found, so the SSH shell was left unchanged. Install PowerShell 7 with the MSI step above first."
}
```

The check matters: if `DefaultShell` points at a file that doesn't exist, sshd refuses every login. To undo the setting: `Remove-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell`.

Check the version from a new Terminal tab:

```powershell
$PSVersionTable.PSVersion
```

## Settings

Run in the elevated terminal as `{{ site.user }}`; `HKCU` settings apply to the signed-in user.

**Dark theme** for apps and Windows:

```powershell
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-ItemProperty -Path $p -Name AppsUseLightTheme -Type DWord -Value 0
Set-ItemProperty -Path $p -Name SystemUsesLightTheme -Type DWord -Value 0
```

**Touchpad scrolling: normal** ("down motion scrolls down", not natural). Applies to precision touchpads (harmless on machines without one); mouse wheels already scroll normally:

```powershell
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
if (-not (Test-Path $p)) { New-Item -Path $p | Out-Null }
Set-ItemProperty -Path $p -Name ScrollDirection -Type DWord -Value 0xFFFFFFFF
```

**Alt+Tab shows windows only**, not browser tabs:

```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name MultiTaskingAltTabFilter -Type DWord -Value 3
```

**Disable fast startup**, so shutdown fully shuts down (hibernate stays available):

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -Type DWord -Value 0
```

**Power timeouts.** Plugged in: screen off after 30 minutes, never sleep. On battery: screen off after 15 minutes, sleep after 30 (`0` means never):

```powershell
powercfg /change monitor-timeout-ac 30
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-dc 15
powercfg /change standby-timeout-dc 30
```

**Lid close** (laptops): do nothing when plugged in, sleep on battery. Uses GUIDs because the `LIDACTION` alias isn't available on every machine; values are 0 nothing, 1 sleep, 2 hibernate, 3 shut down:

```powershell
$buttons = "4f971e89-eebd-4455-a8de-9e59040e7347"
$lid = "5ca83367-6e45-459f-a27b-476b1d01c936"
powercfg /setacvalueindex SCHEME_CURRENT $buttons $lid 0
powercfg /setdcvalueindex SCHEME_CURRENT $buttons $lid 1
powercfg /setactive SCHEME_CURRENT
```

**Power mode: Best performance** (Settings → System → Power → Power mode). `powercfg` has no command for this, so it calls the Windows power API directly; it prints `0` on success:

```powershell
if (-not ('Win.Power' -as [type])) { Add-Type -Namespace Win -Name Power -MemberDefinition '[DllImport("powrprof.dll")] public static extern uint PowerSetActiveOverlayScheme(Guid overlay);' }
[Win.Power]::PowerSetActiveOverlayScheme([Guid]"ded574b5-45a0-4f42-8737-46345c09c238")
```

Check the timeouts and lid setting:

```powershell
powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
powercfg /query SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936
```

Restart Explorer to apply the theme and Alt+Tab changes now (the taskbar disappears for a moment). The touchpad change applies after you sign out and back in:

```powershell
Stop-Process -Name explorer -Force
```

## Configure

{% include ssh-config.md %}

{% include ssh-server.md %}

{% include git-config.md %}

## Optional

_No steps yet._

## Verify

Restart so every change takes effect: theme and Alt+Tab everywhere, touchpad scrolling, fast startup, PATH for newly installed tools, and anything Windows Update left pending. `-Force` doesn't wait for apps to close, so save open work first:

```powershell
Restart-Computer -Force
```

After it's back up:

{% include os-info.md %}
