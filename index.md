---
layout: default
---

# Install Steps

Copy/paste steps for setting up a fresh OS. Click **Copy** on any block.

**Jump to:** [Windows](#windows) · [Linux (Debian/Ubuntu)](#linux-debianubuntu) · [Linux (RHEL/Oracle)](#linux-rheloracle)

## Windows

Run in an elevated PowerShell.

Update all installed apps:

```powershell
winget upgrade --all --accept-source-agreements --accept-package-agreements
```

Install common tools:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Microsoft.PowerShell -e
```

## Linux (Debian/Ubuntu)

Update the system:

```bash
sudo apt update && sudo apt full-upgrade -y
```

Install common tools:

```bash
sudo apt install -y git curl vim htop
```

## Linux (RHEL/Oracle)

Update the system:

```bash
sudo dnf upgrade -y
```

Install common tools:

```bash
sudo dnf install -y git curl vim htop
```
