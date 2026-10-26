---
title: CachyOS
permalink: /cachyos/
os_version: CachyOS (rolling release)   # shown as the expected result of the Verify step
pm: pacman
packages:
  - git
  - curl
  - micro
  - htop
---

## Before you start

Run as a user with `sudo`{:.sudo} rights.

CachyOS defaults to `fish`{:.cmd}, but these steps use `bash`{:.cmd} syntax. Make `bash`{:.cmd} the login shell (asks for your password):

```bash
chsh -s /bin/bash
```

Then switch to `bash`{:.cmd} in the current terminal:

```bash
bash
```

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

Idle sleep on CachyOS's default KDE Plasma desktop is set in **System Settings → Power Management**: on **AC Power**, set **When inactive** to **Do nothing**; on **Battery**, **Sleep** after **30 min**. The login screen (SDDM) doesn't suspend on its own.

{% include server-power.md part="wifi" %}

{% include server-power.md part="check" wifi="yes" %}

{% include server-power.md part="bios" %}

{% include claude-service.md %}

## Verify

{% include os-info.md %}
