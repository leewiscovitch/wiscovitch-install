---
title: Ubuntu Desktop
permalink: /ubuntu/desktop/
os_version: Ubuntu 26.04 LTS or 26.04.x LTS   # shown as the expected result of the Verify step
parent: /ubuntu/
parent_title: Ubuntu
pm: apt
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

## Settings

Scrolling: normal, not natural, for touchpads and mice. Run as `{{ site.user }}` in a terminal inside the desktop session (not over SSH, and not with `sudo`):

```bash
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false &&\
gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false
```

## Configure

{% include ssh-config.md %}

{% include ssh-server.md %}

{% include git-config.md %}

## Optional

### Server use: always on, lid closed

For a laptop that runs as a server on constant power: it keeps running with the lid closed (also through reboots), never sleeps on AC, still sleeps after 30 minutes idle on battery, and Wi-Fi stays fully awake. Tested on an HP ProBook 460 G11.

{% include server-power.md part="lid" %}

Idle sleep: never on AC, after 30 minutes on battery. The first block sets it for every user account; the second for the login screen, which is what's running after a reboot when nobody signs in (it takes effect at the next reboot):

```bash
sudo mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' | sudo tee /etc/dconf/profile/user > /dev/null
sudo tee /etc/dconf/db/local.d/50-server-power > /dev/null << 'EOF'
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-type='suspend'
sleep-inactive-battery-timeout=1800
EOF
sudo dconf update
```

```bash
grep -q '^sleep-inactive-ac-type=' /etc/gdm3/greeter.dconf-defaults ||
sudo sed -i "/^\[org\/gnome\/settings-daemon\/plugins\/power\]/a sleep-inactive-ac-type='nothing'\nsleep-inactive-ac-timeout=0\nsleep-inactive-battery-type='suspend'\nsleep-inactive-battery-timeout=1800" /etc/gdm3/greeter.dconf-defaults
```

{% include server-power.md part="wifi" %}

{% include server-power.md part="check" idle="gnome" wifi="yes" %}

{% include server-power.md part="bios" %}

{% include claude-service.md %}

## Verify

{% include os-info.md %}
