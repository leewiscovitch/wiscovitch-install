# First-logon setup for the Windows 11 VM-test template. Runs once as `tech`
# (an administrator) from autounattend.xml, then shuts the VM down so it can be
# converted to a template. Log: C:\ci-setup.log
$ErrorActionPreference = 'Continue'
Start-Transcript -Path C:\ci-setup.log -Append

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$virtio = (Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path (Join-Path $_.Root 'virtio-win-gt-x64.msi') } | Select-Object -First 1).Root
"answer-file CD: $here   virtio CD: $virtio"

# All VirtIO drivers (balloon, serial, etc.) and the QEMU guest agent, so Proxmox can read the IP
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$(Join-Path $virtio 'virtio-win-gt-x64.msi')`" /qn /norestart"
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$(Join-Path $virtio 'guest-agent\qemu-ga-x86_64.msi')`" /qn /norestart"
Get-Service QEMU-GA | Format-List Name, Status, StartType

# Never sleep: a test VM that dozes off mid-run looks like a failure
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 0

# OpenSSH Server with only the runner's key. tech is an administrator, so sshd reads
# administrators_authorized_keys, which must be owned by and limited to Administrators/SYSTEM.
for ($i = 1; $i -le 5; $i++) {
    $cap = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    if ((Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0).State -eq 'Installed') { break }
    "OpenSSH.Server not installed yet (attempt $i), retrying in 30s"; Start-Sleep 30
}
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
$keys = "$env:ProgramData\ssh\administrators_authorized_keys"
Get-Content (Join-Path $here 'runner.pub') | Set-Content -Path $keys -Encoding ascii
icacls.exe $keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}
# Windows marks a new network Public, and the OpenSSH rule only allows Private. This is a
# test VM on the home LAN, so allow SSH on any profile and mark the network Private.
Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Profile Any
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Get-Service sshd | Format-List Name, Status, StartType

"setup done; shutting down"
Stop-Transcript
Stop-Computer -Force
