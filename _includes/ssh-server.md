{%- assign pm = site.data.pm[page.pm] -%}
{% if pm.lang == "powershell" -%}
Accept SSH logins with your keys ([how keys work]({{ '/ssh/' | relative_url }})). Install and start the OpenSSH server. This uses Microsoft's OpenSSH {{ site.openssh_msi.version }} MSI from GitHub, which installs in seconds; the built-in "OpenSSH Server" feature comes from Windows Update and can take many minutes. If an SSH server is already installed (either kind), it's kept as is:

```powershell
if (Get-Service sshd -ErrorAction Ignore) {
    "An SSH server is already installed; keeping it."
} else {
    $msi = "$env:TEMP\OpenSSH-Win64.msi"
    Invoke-WebRequest 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/{{ site.openssh_msi.release }}/OpenSSH-Win64-v{{ site.openssh_msi.version }}.msi' -OutFile $msi -UseBasicParsing
    if ((Get-FileHash $msi -Algorithm SHA256).Hash -ne '{{ site.openssh_msi.sha256 }}') { throw 'OpenSSH MSI checksum mismatch; not installing.' }
    Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
}
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
Get-Service sshd                 # Status: Running
(Get-Item ((Get-CimInstance Win32_Service -Filter "Name='sshd'").PathName.Trim('"'))).VersionInfo.ProductVersion   # {{ site.openssh_msi.version }} from the MSI (a built-in server shows its own version)
```

Let SSH through the firewall. Windows marks a new network as Public, and the OpenSSH rule only allows Private networks, so out of the box the server can't be reached from the LAN. This marks the current network Private and allows the SSH rule on every network type (the rule's display name is "OpenSSH SSH Server (sshd)" for the built-in server, "OpenSSH SSH Server Preview (sshd)" for the MSI):

```powershell
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Get-NetFirewallRule -DisplayName 'OpenSSH SSH Server*' | Set-NetFirewallRule -Profile Any
```

Trust the keys published at [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys). Because `{{ site.user }}`{:.user} is an administrator, Windows reads them from a shared file instead of `~\.ssh\authorized_keys`{:.path}, and that file must be locked to Administrators and SYSTEM:

```powershell
$keys = "$env:ProgramData\ssh\administrators_authorized_keys"
Invoke-RestMethod https://github.com/{{ site.github_user }}.keys | Add-Content -Path $keys
icacls.exe $keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```
{%- else -%}
Accept SSH logins with your keys ([how keys work]({{ '/ssh/' | relative_url }})). Install and start the SSH server:

```bash
{{ pm.install }} {{ pm.sshd_pkg }}
sudo systemctl enable --now {{ pm.sshd_service }}
```
{% if page.pm == "apt" %}
```output
Reading package lists... Done
…
Setting up openssh-server (<version>) ...
Creating config file /etc/ssh/sshd_config with new version
…
Synchronizing state of ssh.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable ssh
```
{% endif %}

Trust the keys published at [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys) (run as `{{ site.user }}`{:.user}):

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
curl -fsSL https://github.com/{{ site.github_user }}.keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

{% include no-output.md %}
{%- endif %}
