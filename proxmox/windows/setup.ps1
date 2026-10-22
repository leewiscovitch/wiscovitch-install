# First-logon setup for the Windows 11 VM-test template. Runs once as `tech`
# (an administrator) from autounattend.xml, in tech's desktop session, then shuts
# the VM down so it can be converted to a template. Log: C:\ci-setup.log
#
# __PASSWORD__ is replaced by build.sh (for auto-login); this file with the real
# password only ever exists on the answer-file ISO, which build.sh deletes.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
Start-Transcript -Path C:\ci-setup.log -Append

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$virtio = (Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path (Join-Path $_.Root 'virtio-win-gt-x64.msi') } | Select-Object -First 1).Root
"answer-file CD: $here   virtio CD: $virtio"

function Get-Verified($url, $sha256, $path) {
    Invoke-WebRequest $url -OutFile $path -UseBasicParsing
    if ((Get-FileHash $path -Algorithm SHA256).Hash -ne $sha256) { throw "checksum mismatch: $url" }
    $path
}

# All VirtIO drivers (balloon, serial, etc.) and the QEMU guest agent, so Proxmox can read the IP
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$(Join-Path $virtio 'virtio-win-gt-x64.msi')`" /qn /norestart"
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$(Join-Path $virtio 'guest-agent\qemu-ga-x86_64.msi')`" /qn /norestart"
Get-Service QEMU-GA | Format-List Name, Status, StartType

# Never sleep: a test VM that dozes off mid-run looks like a failure
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 0

# Auto-login as tech on every boot, so tests can run commands inside a desktop session
# (winget, MSIX installs and Explorer need one; see tests/windows_desktop_task.ps1).
$winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty $winlogon AutoAdminLogon '1'
Set-ItemProperty $winlogon DefaultUserName 'tech'
Set-ItemProperty $winlogon DefaultDomainName '.'
Set-ItemProperty $winlogon DefaultPassword '__PASSWORD__'
Remove-ItemProperty $winlogon AutoLogonCount -ErrorAction Ignore   # the unattend's one-time count would turn it off

# Keep the App Installer (winget) that ships with the ISO, like a fresh install: the
# page's Update section updates it (Repair-WinGetPackageManager), and a newer one here
# would hide that path from the VM test. Turn off Store auto-updates so it stays old
# until the page runs (the Store's background update also broke winget's shortcut once).
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' AutoDownload -Type DWord -Value 2
"App Installer: $((Get-AppxPackage -Name Microsoft.DesktopAppInstaller | Sort-Object Version | Select-Object -Last 1).Version)"

# OpenSSH Server from Microsoft's Win32-OpenSSH MSI (seconds, vs minutes from Windows
# Update). Keep in sync with openssh_msi in _config.yml.
$msi = Get-Verified 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.4.0.0p1-Preview/OpenSSH-Win64-v10.4.0.0.msi' '788D8643464A01EB63640A2FD746F9ED23D106B5A901A35F88DC8CD40E446AC9' "$env:TEMP\OpenSSH-Win64.msi"
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn /norestart"
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# Only the runner's key. tech is an administrator, so sshd reads
# administrators_authorized_keys, which must be limited to Administrators/SYSTEM.
$keys = "$env:ProgramData\ssh\administrators_authorized_keys"
Get-Content (Join-Path $here 'runner.pub') | Set-Content -Path $keys -Encoding ascii
icacls.exe $keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

# Windows marks a new network Public, and the OpenSSH rule only allows Private. This is a
# test VM on the home LAN, so allow SSH on any profile and mark the network Private.
Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server*' | Set-NetFirewallRule -Profile Any
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Get-Service sshd | Format-List Name, Status, StartType

"setup done; shutting down"
Stop-Transcript
Stop-Computer -Force
