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
---

## Before you start

Run everything in an elevated terminal: **Win+X → Terminal (Admin)**.

Allow scripts and modules to run (needed for the Windows Update module below). `Bypass` turns off script checks for every user on this machine; it applies to the PowerShell you run it in, so repeat it in PowerShell 7 if you use that too:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
Get-ExecutionPolicy -List
```

`LocalMachine` should show `Bypass`. If a `MachinePolicy` or `UserPolicy` row is set, Group Policy is overriding it.

## Time zone

{% include timezone.md %}

## Update

Install the PSWindowsUpdate module (once per machine):

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force
```

Install all Windows updates, including drivers and other Microsoft products, rebooting automatically if needed. Run it again after each reboot until it finds nothing:

```powershell
Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -AutoReboot
```

To see what's pending without installing anything:

```powershell
Get-WindowsUpdate -MicrosoftUpdate
```

Tell the Microsoft Store to check for and install updates for all Store apps. It runs in the background; progress shows in **Store → Downloads**:

```powershell
Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
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
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Install-Module -Name Microsoft.WinGet.Client -Scope AllUsers -Force
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

Allow scripts in PowerShell 7 too; it keeps its own execution policy, separate from Windows PowerShell:

```powershell
& "$env:ProgramFiles\PowerShell\7\pwsh.exe" -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force; Get-ExecutionPolicy -Scope LocalMachine"
```

Make PowerShell 7 the default Windows Terminal profile, so new tabs and **Win+X → Terminal (Admin)** open it:

```powershell
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$pwshProfile = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
if (Test-Path $wt) {
    $json = [IO.File]::ReadAllText($wt) -replace '"defaultProfile"\s*:\s*"[^"]*"', "`"defaultProfile`": `"$pwshProfile`""
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $wt) | Out-Null
    $json = "{ `"defaultProfile`": `"$pwshProfile`" }"
}
[IO.File]::WriteAllText($wt, $json, [Text.UTF8Encoding]::new($false))
Select-String -Path $wt -Pattern '"defaultProfile"'
```

If Terminal has never been opened, this creates a settings file with just the default profile, and Terminal fills in the rest on first launch. Close and reopen Terminal; the PowerShell 7 profile appears once Terminal detects the new install.

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

## Remove apps

{% include remove.md %}

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

{% include os-info.md %}
