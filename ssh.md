---
title: SSH keys
permalink: /ssh/
parent_title: Home
---

## Before you start

A key has two halves:

- **Private key** (`id_ed25519`): stays on the machine you connect **from**. Never copy it anywhere.
- **Public key** (`id_ed25519.pub`): goes on every machine you connect **to**. It's safe to share.

The machines you log in to trust the public keys listed at [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys). To let a new machine log in everywhere, add its public key to GitHub; to let a machine accept your keys, run the **Configure** step on its OS page. Commands use `<HOST>` for the machine you're connecting to.

## Create a key

On the machine you'll connect **from**. Press Enter to accept the default file; a passphrase is optional.

Linux:

```bash
ssh-keygen -t ed25519 -C "$USER@$(uname -n)"
```

Windows (PowerShell):

```powershell
ssh-keygen -t ed25519 -C "$env:USERNAME@$env:COMPUTERNAME"
```

Show the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

```powershell
Get-Content "$HOME\.ssh\id_ed25519.pub"
```

## Publish the key

Add the public key to GitHub so every machine that trusts [github.com/{{ site.github_user }}.keys](https://github.com/{{ site.github_user }}.keys) accepts it. Either paste it at [GitHub → Settings → SSH keys → New SSH key](https://github.com/settings/ssh/new), or use the GitHub CLI. The first command grants `gh` permission to manage keys (once per machine):

```bash
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(uname -n)"
```

```powershell
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add "$HOME\.ssh\id_ed25519.pub" --title $env:COMPUTERNAME
```

The key also works for `git` over SSH to GitHub.

## Accept keys

Each OS page's **Configure** section installs the SSH server and trusts your GitHub keys: [Windows]({{ '/windows/#configure' | relative_url }}) · [Ubuntu Desktop]({{ '/ubuntu/desktop/#configure' | relative_url }}) · [Ubuntu Server]({{ '/ubuntu/server/#configure' | relative_url }}) · [Fedora]({{ '/fedora/#configure' | relative_url }}) · [Alma/Rocky]({{ '/alma/#configure' | relative_url }}) · [CachyOS]({{ '/cachyos/#configure' | relative_url }}).

After publishing a new key, add it to machines that are already set up by fetching the list again. On Linux, this replaces the file with the current list:

```bash
curl -fsSL https://github.com/{{ site.github_user }}.keys > ~/.ssh/authorized_keys
```

On Windows (elevated PowerShell):

```powershell
Invoke-RestMethod https://github.com/{{ site.github_user }}.keys | Set-Content -Path "$env:ProgramData\ssh\administrators_authorized_keys"
```

## Copy a key directly

Without GitHub, copy a public key straight to one machine. It asks for that machine's password once.

From Linux to a Linux machine:

```bash
ssh-copy-id {{ site.user }}@<HOST>
```

From Windows to a Linux machine (Windows has no `ssh-copy-id`):

```powershell
Get-Content "$HOME\.ssh\id_ed25519.pub" | ssh {{ site.user }}@<HOST> "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

To a Windows machine: run this on that machine in an elevated PowerShell, pasting the public key between the quotes:

```powershell
$keys = "$env:ProgramData\ssh\administrators_authorized_keys"
Add-Content -Path $keys -Value '<PASTE PUBLIC KEY>'
icacls.exe $keys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
```

## Test

Log in from the machine that has the private key. It should connect without asking for a password (it will ask for the key's passphrase if you set one):

```bash
ssh {{ site.user }}@<HOST>
```

If it still asks for a password, run with `-v` and look for `Offering public key` and the server's reply. Common causes: wrong permissions on `~/.ssh` or `authorized_keys` (Linux), the key in `~\.ssh\authorized_keys` instead of `administrators_authorized_keys` (Windows admin accounts), or a firewall blocking port 22.

```bash
ssh -v {{ site.user }}@<HOST>
```

## Disable passwords

Password logins stay enabled: nothing on this site turns them off unless you run the steps below. Once key logins work, you can disable passwords so only keys are accepted. Keep one SSH session open while you do this, so a mistake can't lock you out.

Linux (the service is `ssh` on Ubuntu and `sshd` elsewhere; the reload line tries both):

```bash
echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/01-no-passwords.conf > /dev/null
sudo sshd -t &&\
{ sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd; }
sudo sshd -T | grep -i '^passwordauthentication'
```

The last line should print `passwordauthentication no`.

Windows (elevated PowerShell):

```powershell
$cfg = "$env:ProgramData\ssh\sshd_config"
(Get-Content $cfg) -replace '^#?PasswordAuthentication .*', 'PasswordAuthentication no' | Set-Content $cfg
Restart-Service sshd
Select-String -Path $cfg -Pattern '^PasswordAuthentication'
```

The last line should show `PasswordAuthentication no`.

To turn passwords back on, Linux:

```bash
sudo rm /etc/ssh/sshd_config.d/01-no-passwords.conf
sudo sshd -t &&\
{ sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd; }
```

Windows (elevated PowerShell):

```powershell
$cfg = "$env:ProgramData\ssh\sshd_config"
(Get-Content $cfg) -replace '^PasswordAuthentication no', '#PasswordAuthentication yes' | Set-Content $cfg
Restart-Service sshd
```
