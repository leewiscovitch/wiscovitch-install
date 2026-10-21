---
title: Windows 11
permalink: /windows/
pm: winget
packages:
  - Git.Git
  - GitHub.cli
  - Microsoft.PowerShell
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

**Touchpad scrolling: normal** ("down motion scrolls down", not natural). Laptops with a precision touchpad only; mouse wheels already scroll normally:

```powershell
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" -Name ScrollDirection -Type DWord -Value 0xFFFFFFFF
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
