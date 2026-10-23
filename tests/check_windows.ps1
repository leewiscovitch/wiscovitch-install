# After the Windows page has run and the VM has rebooted, check that its changes
# stuck. Runs on the VM as tech; prints one "name<TAB>status<TAB>note" line per check.
param([string] $GitName = 'CI Test', [string] $GitEmail = 'ci@example.com')
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

function Check($name, $note, [scriptblock] $test) {
    $ok = $false
    try { $ok = [bool](& $test) } catch { $note = "$note ($($_.Exception.Message))" }
    "check-$name`t$(if ($ok) { 'pass' } else { 'fail' })`t$note"
}
function Reg($path, $name) { (Get-ItemProperty -Path $path -Name $name).$name }

$pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$keys = "$env:ProgramData\ssh\administrators_authorized_keys"
$github = @((Invoke-RestMethod https://github.com/leewiscovitch.keys) -split "`n" | Where-Object { $_ -match '^ssh-' })

Check execution-policy 'LocalMachine execution policy is Bypass'      { (Get-ExecutionPolicy -Scope LocalMachine) -eq 'Bypass' }
Check timezone        'time zone is Eastern Standard Time'             { (Get-TimeZone).Id -eq 'Eastern Standard Time' }
Check time-service    'Windows Time service set to start automatically' { (Get-Service w32time).StartType -eq 'Automatic' }
Check pwsh            'PowerShell 7 installed in Program Files'        { (Test-Path $pwshPath) -and ((& $pwshPath -NoProfile -Command '$PSVersionTable.PSVersion.Major') -eq '7') }
Check pwsh-policy     'PowerShell 7 execution policy is Bypass'         { (& $pwshPath -NoProfile -Command 'Get-ExecutionPolicy -Scope MachinePolicy') -eq 'Bypass' }
Check terminal        'Windows Terminal installed'                     { [bool](Get-AppxPackage -Name Microsoft.WindowsTerminal) }
Check terminal-default 'Terminal default profile is PowerShell 7'      { (Get-Content $wt -Raw) -match '"defaultProfile"\s*:\s*"\{574e775e-4f2a-5b96-ac1e-a2962a402336\}"' }
Check git             'Git installed'                                   { [bool](Get-Command git) }
Check gh              'GitHub CLI installed'                            { [bool](Get-Command gh) }
Check git-identity    'git name/email from the prompts'                { ((git config --global user.name) -eq $GitName) -and ((git config --global user.email) -eq $GitEmail) }
Check sshd            'sshd running and automatic'                     { $s = Get-Service sshd; $s.Status -eq 'Running' -and $s.StartType -eq 'Automatic' }
Check ssh-firewall    'SSH firewall rule allows any profile'           { $r = @(Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server*'); $r.Count -gt 0 -and @($r | Where-Object Profile -ne 'Any').Count -eq 0 }
Check network-private 'network marked Private'                         { @(Get-NetConnectionProfile | Where-Object NetworkCategory -ne 'Private').Count -eq 0 }
Check ssh-shell       'SSH default shell is PowerShell 7'              { (Reg 'HKLM:\SOFTWARE\OpenSSH' DefaultShell) -eq $pwshPath }
Check github-keys     "all $($github.Count) GitHub keys trusted"       { $have = Get-Content $keys; @($github | Where-Object { $have -notcontains $_.Trim() }).Count -eq 0 }
Check keys-acl        'admin keys file limited to Administrators/SYSTEM' { $a = (Get-Acl $keys).Access | ForEach-Object { $_.IdentityReference.Value }; @($a | Where-Object { $_ -notin 'BUILTIN\Administrators', 'NT AUTHORITY\SYSTEM' }).Count -eq 0 }
Check ssh-config      'ssh client config: accept-new, known hosts NUL' { $c = Get-Content "$HOME\.ssh\config" -Raw; $c -match 'StrictHostKeyChecking=accept-new' -and $c -match 'UserKnownHostsFile=NUL' }
Check dark-theme      'dark theme for apps and Windows'                { (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme) -eq 0 -and (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' SystemUsesLightTheme) -eq 0 }
Check touchpad-scroll 'touchpad scrolling: normal'                     { '{0:X8}' -f (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' ScrollDirection) -eq 'FFFFFFFF' }   # Int32 -1 or UInt32 4294967295
Check alt-tab         'Alt+Tab shows windows only'                     { (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' MultiTaskingAltTabFilter) -eq 3 }
Check fast-startup    'fast startup off'                               { (Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' HiberbootEnabled) -eq 0 }
Check explorer-view   'Explorer: file extensions, hidden files (not system files), full path' { $a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; (Reg $a HideFileExt) -eq 0 -and (Reg $a Hidden) -eq 1 -and (Reg $a ShowSuperHidden) -eq 0 -and (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' FullPath) -eq 1 }
Check taskbar         'taskbar: left, no Search/Task view/Copilot, all displays' { $a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; (Reg $a TaskbarAl) -eq 0 -and (Reg $a ShowTaskViewButton) -eq 0 -and (Reg $a ShowCopilotButton) -eq 0 -and (Reg $a MMTaskbarEnabled) -eq 1 -and (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode) -eq 0 }
Check end-task       'End task on taskbar right-click'                { (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' TaskbarEndTask) -eq 1 }
Check developer       'Developer Mode, long paths, sudo inline'        { (Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' AllowDevelopmentWithoutDevLicense) -eq 1 -and (Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled) -eq 1 -and (Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' Enabled) -eq 3 }
Check default-terminal 'Windows Terminal is the default terminal'      { (Reg 'HKCU:\Console\%%Startup' DelegationTerminal) -eq '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}' }
Check no-welcome     'no welcome experience, setup suggestions, tips or Start account prompts' { $c = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; (Reg $c 'SubscribedContent-310093Enabled') -eq 0 -and (Reg $c 'SubscribedContent-338389Enabled') -eq 0 -and (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled) -eq 0 -and (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' Start_AccountNotifications) -eq 0 }
Check start-list      'Start menu All apps view: list'               { (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' AllAppsViewMode) -eq 2 }
Check spotlight-icon 'no "Learn about this picture" desktop icon'    { (Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}') -eq 1 }
Check edge-policies 'Edge: no first run or import, no Copilot button or sidebar' { $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; (Reg $e HideFirstRunExperience) -eq 1 -and (Reg $e AutoImportAtFirstRun) -eq 4 -and (Reg $e Microsoft365CopilotChatIconEnabled) -eq 0 -and (Reg $e HubsSidebarEnabled) -eq 0 }
Check power-ac       'plugged in: screen 30 min, never sleep'         { $v = powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE | Out-String; $s = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Out-String; $v -match 'Current AC Power Setting Index: 0x00000708' -and $s -match 'Current AC Power Setting Index: 0x00000000' }
# The Remove apps list, read from the page's own blocks ('Name'  # comment lines)
$removeList = @(Get-ChildItem "$PSScriptRoot\blocks\*remove-apps*.powershell" -ErrorAction SilentlyContinue |
    Get-Content | Select-String -Pattern "^\s*'([^']+)'\s*#" | ForEach-Object { $_.Matches[0].Groups[1].Value })
# Count an app only if it's installed for some account and has files: Windows can keep a
# stub registration (e.g. MSTeams_1.0.0.1) with no users or no files, which can't be removed.
$leftUser = @(Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $removeList -and ($_.PackageUserInformation | Where-Object InstallState -eq 'Installed') -and $_.InstallLocation -and (Test-Path $_.InstallLocation) } |
    Select-Object -ExpandProperty Name -Unique)
$leftProv = @(Get-AppxProvisionedPackage -Online | Where-Object DisplayName -in $removeList | Select-Object -ExpandProperty DisplayName)
Check removed-apps        "all $($removeList.Count) Remove-apps entries uninstalled$(if ($leftUser) { '; still installed: ' + ($leftUser -join ', ') })" { $removeList.Count -gt 0 -and $leftUser.Count -eq 0 }
Check removed-provisioned "no Remove-apps entries provisioned for new users$(if ($leftProv) { '; still provisioned: ' + ($leftProv -join ', ') })" { $leftProv.Count -eq 0 }
Check onedrive-removed    'OneDrive uninstalled'                         { -not (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe') }
