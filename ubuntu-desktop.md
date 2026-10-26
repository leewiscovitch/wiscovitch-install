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

Closing the lid does nothing, whether on battery, on AC or docked:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/50-server-lid.conf > /dev/null << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl reload systemd-logind
```

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

Wi-Fi power saving off (it delays replies and can drop idle connections). The file name matters: NetworkManager reads its config files in alphabetical order, and this one has to come after Ubuntu's `default-wifi-powersave-on.conf`. It applies from the next reboot:

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF
```

Check (after a reboot):

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch HandleLidSwitchExternalPower   # s "ignore" (twice)
dconf read /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type   # 'nothing'
dconf read /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout   # 1800
NetworkManager --print-config | grep '^wifi.powersave'   # wifi.powersave=2
```

Wi-Fi reconnects at boot without anyone signing in only if its saved password is available to all users, which is the default for networks joined in Settings. With both Ethernet and Wi-Fi connected, NetworkManager prefers Ethernet automatically and keeps Wi-Fi as a fallback.

In the BIOS (F10 at power-on on HP laptops), consider capping battery charging for life on permanent AC (HP: **Battery Health Manager → Maximize my battery health**), and turning on power-on after AC power returns, if the model offers it.

## Verify

{% include os-info.md %}
