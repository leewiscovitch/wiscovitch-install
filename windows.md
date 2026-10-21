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

## Configure

{% include ssh-config.md %}

{% include ssh-server.md %}

{% include git-config.md %}

## Optional

_No steps yet._

## Verify

{% include os-info.md %}
