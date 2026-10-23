---
title: Windows 11
permalink: /windows/
os_version: Windows 11 Pro, build 26300 or newer   # shown as the expected result of the Verify step
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
      - { id: MicrosoftWindows.Client.WebExperience, name: Widgets }
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
      - { id: 7EE7776C.LinkedInforWindows, name: LinkedIn }
      - { id: 5319275A.WhatsAppDesktop, name: WhatsApp }
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

Some Start menu entries on a fresh install (LinkedIn, WhatsApp and similar) are placeholder pins: the app only downloads when clicked, so there's nothing to uninstall yet. Right-click those and choose **Unpin from Start**.

{% include remove.md %}

## Update

Install the PSWindowsUpdate module (once per machine). It's downloaded straight from the PowerShell Gallery, pinned and checksum-checked like the MSIs below, so it doesn't need `Install-Module`, the NuGet provider or the Gallery's search:

```powershell
{% include ps-module.md name="PSWindowsUpdate" %}
Import-Module PSWindowsUpdate
(Get-Module PSWindowsUpdate).Version.ToString()   # {{ site.ps_modules.PSWindowsUpdate.version }}
```

Right after the first sign-in, Windows installs drivers and updates on its own for a while, and `Get-WindowsUpdate` fails with "Value does not fall within the expected range" while that runs. The commands below keep trying every 30 seconds for up to 10 minutes and print "Windows Update is busy" while they wait. If they still give up, wait until **Settings → Windows Update** shows nothing downloading or installing, and run them again.

Install all Windows updates, including drivers and other Microsoft products, rebooting automatically if needed. Run it again after each reboot until it finds nothing. The first line starts the Windows Update service, which stops itself when idle and can't be started while it's still stopping (common right after first boot):

```powershell
while ((Get-Service wuauserv).Status -eq 'StopPending') { Start-Sleep 2 }; Start-Service wuauserv
foreach ($try in 1..20) { try { Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -AutoReboot -ErrorAction Stop; break } catch { if ($try -eq 20) { throw }; "Windows Update is busy (usually installing updates on its own); trying again in 30 seconds ($try of 20)"; Start-Sleep 30 } }
UsoClient StartInteractiveScan
```

The last line refreshes the list in **Settings → Windows Update**, which otherwise keeps showing updates from its previous scan even after they're installed here. It prints nothing and returns at once. Like **Check for updates**, the scan may start downloading anything new it finds.

To see what's pending without installing anything:

```powershell
while ((Get-Service wuauserv).Status -eq 'StopPending') { Start-Sleep 2 }; Start-Service wuauserv
foreach ($try in 1..20) { try { Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop; break } catch { if ($try -eq 20) { throw }; "Windows Update is busy (usually installing updates on its own); trying again in 30 seconds ($try of 20)"; Start-Sleep 30 } }
```

`Get-WUHistory -Last 30` lists what was installed (times are in UTC).

**Update for Windows Security platform (KB5007651)** can show up again on every run, even though each run reports it as installed. Once it's the only thing left, Windows is up to date; it stops appearing after the Security app updates itself through the Store.

Tell the Microsoft Store to check for and install updates for all Store apps. It runs in the background; progress shows in **Store → Downloads**:

```powershell
Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
```

{% include update.md %}

The command runs twice on purpose. A fresh install ships an older `winget`, and when `winget upgrade --all` updates winget itself it prints "Restart the application to complete the upgrade", then stops with "Cancelled"; the second run, with the new winget, upgrades the rest. If nothing needed updating, the second run just says so. Afterwards `winget --version` shows v{{ site.winget_version }} or newer.

## Install

{% include install.md %}

**Over SSH (no desktop session):** the `winget` command, and the PowerShell module's usual mode, only work in a desktop session, so the block above fails when run over SSH. This installs the same packages from an SSH session: PowerShell 7 from its MSI, then Microsoft's WinGet PowerShell module, which runs the installs as SYSTEM through a one-off scheduled task. Store (MSIX) apps such as Windows Terminal can't be installed this way, but Windows 11 already includes Terminal.

```powershell
$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
if (-not (Test-Path $pwsh)) {
    $msi = "$env:TEMP\PowerShell-7-win-x64.msi"
    Invoke-WebRequest 'https://github.com/PowerShell/PowerShell/releases/download/v{{ site.pwsh_msi.version }}/PowerShell-{{ site.pwsh_msi.version }}-win-x64.msi' -OutFile $msi -UseBasicParsing
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
if (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") {
    winget upgrade --id Microsoft.PowerShell -e --source winget --accept-source-agreements --accept-package-agreements
} else {
    winget install --id Microsoft.PowerShell -e --source winget --installer-type wix --accept-source-agreements --accept-package-agreements
}
```

If PowerShell 7 is already installed (by the **Over SSH** block, or updated by Windows Update), this only upgrades it. "No available upgrade found" means it's already current: Windows Update can install a new release before winget's catalog has it, and winget would otherwise try to install the older version over it, which fails.

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
$PSVersionTable.PSVersion   # {{ site.pwsh_msi.version }} or newer
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

**File Explorer and taskbar** (Settings → System → Advanced): show file extensions, hidden files and the full path in the title bar, and add **End task** to the taskbar's right-click menu. Protected system files such as `desktop.ini` stay hidden (they'd clutter the desktop), so the **Show hidden and system files** switch in Settings, which covers both, shows as off:

```powershell
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $adv -Name HideFileExt -Type DWord -Value 0       # show file extensions
Set-ItemProperty -Path $adv -Name Hidden -Type DWord -Value 1            # show hidden files
Set-ItemProperty -Path $adv -Name ShowSuperHidden -Type DWord -Value 0   # keep protected system files (desktop.ini) hidden
$cab = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"
if (-not (Test-Path $cab)) { New-Item -Path $cab -Force | Out-Null }
Set-ItemProperty -Path $cab -Name FullPath -Type DWord -Value 1          # full path in the title bar
$tds = "$adv\TaskbarDeveloperSettings"
if (-not (Test-Path $tds)) { New-Item -Path $tds -Force | Out-Null }
Set-ItemProperty -Path $tds -Name TaskbarEndTask -Type DWord -Value 1    # End task on taskbar right-click
```

**Taskbar** (Settings → Personalization → Taskbar): align left, hide Search, Task view and the Copilot button, and show the taskbar on every display. Widgets is removed in **Remove apps** instead (Windows protects its switch and policy from scripts):

```powershell
$adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $adv -Name TaskbarAl -Type DWord -Value 0            # align left
Set-ItemProperty -Path $adv -Name ShowTaskViewButton -Type DWord -Value 0   # no Task view button
Set-ItemProperty -Path $adv -Name ShowCopilotButton -Type DWord -Value 0    # no Copilot button (where the build has one)
Set-ItemProperty -Path $adv -Name MMTaskbarEnabled -Type DWord -Value 1     # taskbar on all displays
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Type DWord -Value 0   # Search hidden
```

Search still works from the Start menu: open Start and type.

**Developer settings** (Settings → System → Advanced): Developer Mode, long file paths (beyond 260 characters), `sudo` in inline mode (runs in the same window, like Linux; elevate with `sudo <command>`), and Windows Terminal as the default terminal for console apps:

```powershell
$dev = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
if (-not (Test-Path $dev)) { New-Item -Path $dev -Force | Out-Null }
Set-ItemProperty -Path $dev -Name AllowDevelopmentWithoutDevLicense -Type DWord -Value 1   # Developer Mode
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Type DWord -Value 1   # long paths
$sudo = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
if (-not (Test-Path $sudo)) { New-Item -Path $sudo -Force | Out-Null }
Set-ItemProperty -Path $sudo -Name Enabled -Type DWord -Value 3          # sudo: 1 new window, 2 input closed, 3 inline
$con = "HKCU:\Console\%%Startup"
if (-not (Test-Path $con)) { New-Item -Path $con -Force | Out-Null }
Set-ItemProperty -Path $con -Name DelegationConsole -Value "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"    # default terminal:
Set-ItemProperty -Path $con -Name DelegationTerminal -Value "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"   # Windows Terminal
```

Long paths take effect for apps started after a restart. `sudo` needs Windows 11 24H2 or newer.

**No welcome screens or suggestions** after updates: turns off the three switches under **Settings → System → Notifications → Additional settings** (the "what's new" welcome experience, "finish setting up this device", and tips and suggestions):

```powershell
$cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $cdm -Name SubscribedContent-310093Enabled -Type DWord -Value 0   # welcome experience after updates
Set-ItemProperty -Path $cdm -Name SubscribedContent-338389Enabled -Type DWord -Value 0   # tips and suggestions
$upe = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
if (-not (Test-Path $upe)) { New-Item -Path $upe | Out-Null }
Set-ItemProperty -Path $upe -Name ScoobeSystemSettingEnabled -Type DWord -Value 0       # "finish setting up this device"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_AccountNotifications -Type DWord -Value 0   # no "Back up your PC to Microsoft account" in Start
```

The last line is **Settings → Personalization → Start → Show account-related notifications**; it takes effect when Explorer restarts (below).

**Start menu: All apps as a list** (the view switch next to **All** in Start). Start reads it when it next opens, so its process is restarted:

```powershell
$start = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
if (-not (Test-Path $start)) { New-Item -Path $start -Force | Out-Null }
Set-ItemProperty -Path $start -Name AllAppsViewMode -Type DWord -Value 2   # 0 category, 1 grid, 2 list
Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction Ignore
```

**No "Learn about this picture" icon** on the desktop when the wallpaper is **Windows Spotlight** (the daily Bing pictures). The pictures keep changing; only the icon goes:

```powershell
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Type DWord -Value 1   # hide "Learn about this picture"
```

**Microsoft Edge:** skip the first-run setup (no welcome pages, no sign-in prompt, no importing other browsers' data) and hide the Copilot button and the sidebar. These are machine-wide Edge policies, so Edge will say "Your browser is managed by your organization"; `edge://policy` lists them. They apply the next time Edge starts:

```powershell
$p = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name HideFirstRunExperience -Type DWord -Value 1               # no first-run setup
Set-ItemProperty -Path $p -Name AutoImportAtFirstRun -Type DWord -Value 4                 # don't import from other browsers
Set-ItemProperty -Path $p -Name Microsoft365CopilotChatIconEnabled -Type DWord -Value 0   # no Copilot button
Set-ItemProperty -Path $p -Name HubsSidebarEnabled -Type DWord -Value 0                   # no sidebar
```

**Edge search engine:** set it by hand. The policy for it only works on PCs joined to a domain or managed by an organization. Open `edge://settings/search` in Edge (type it in the address bar; links to `edge://` pages don't work from websites) and set **Search engine used in the address bar** to **Google**.

Restart Explorer to apply the theme, Alt+Tab, File Explorer and taskbar changes now (the taskbar disappears for a moment). The touchpad change applies after you sign out and back in:

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

{% include remove-again.md %}

Restart so every change takes effect: theme and Alt+Tab everywhere, touchpad scrolling, fast startup, PATH for newly installed tools, and anything Windows Update left pending. `-Force` doesn't wait for apps to close, so save open work first:

```powershell
Restart-Computer -Force
```

After it's back up:

{% include os-info.md %}
