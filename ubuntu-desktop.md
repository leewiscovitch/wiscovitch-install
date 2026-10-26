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
  - vim
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

_No steps yet._

## Verify

{% include os-info.md %}
