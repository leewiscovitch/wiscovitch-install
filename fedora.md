---
title: Fedora
permalink: /fedora/
os_version: Fedora Linux 44   # shown as the expected result of the Verify step
pm: dnf
packages:
  - git
  - curl
  - micro
  - htop
---

## Before you start

Run as a user with `sudo` rights.

{% include sudoers.md %}

## Time zone

{% include timezone.md %}

## Update

{% include update.md %}

## Install

{% include install.md %}

## Configure

{% include ssh-config.md %}

{% include ssh-server.md %}

{% include git-config.md %}

## Optional

### Server use: always on, lid closed

For a laptop that runs as a server on constant power: it keeps running with the lid closed (also through reboots), and Wi-Fi stays fully awake.

{% include server-power.md part="lid" %}

Idle sleep only applies with a desktop. Server installs never sleep on idle, so there's nothing more to set. On a GNOME desktop (Fedora Workstation), to never sleep on AC and sleep after 30 minutes on battery, add a system-wide default for every user account and one for the login screen. Fedora's dconf profiles already read the `local` and `gdm` databases. Not tested on a GNOME machine yet:

```bash
sudo mkdir -p /etc/dconf/db/local.d /etc/dconf/db/gdm.d
sudo tee /etc/dconf/db/local.d/50-server-power > /dev/null << 'EOF'
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-type='suspend'
sleep-inactive-battery-timeout=1800
EOF
sudo cp /etc/dconf/db/local.d/50-server-power /etc/dconf/db/gdm.d/50-server-power
sudo dconf update
```

{% include server-power.md part="wifi" %}

{% include server-power.md part="check" wifi="yes" %}

{% include server-power.md part="bios" %}

{% include claude-service.md %}

## Verify

{% include os-info.md %}
