{%- assign pm = site.data.pm[page.pm] -%}
{% if pm.lang == "powershell" -%}
Accept SSH logins with your keys ([how keys work]({{ '/ssh/' | relative_url }})). Install and start the OpenSSH server:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
```

Let SSH through the firewall. Windows marks a new network as Public, and the OpenSSH rule only allows Private networks, so out of the box the server can't be reached from the LAN. This marks the current network Private and allows the SSH rule on every network type:

```powershell
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any
```

Trust the keys published at [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys). Because `{{ site.user }}` is an administrator, Windows reads them from a shared file instead of `~\.ssh\authorized_keys`, and that file must be locked to Administrators and SYSTEM:

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

Trust the keys published at [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys) (run as `{{ site.user }}`):

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
curl -fsSL https://github.com/{{ site.github_user }}.keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
{%- endif %}
