---
title: Ubuntu Server
permalink: /ubuntu/server/
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

Run as a user with `sudo`{:.cmd} rights.

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

For a laptop running Ubuntu Server on constant power: it keeps running with the lid closed, also through reboots. Ubuntu Server has no desktop, so it never sleeps on idle.

{% include server-power.md part="lid" %}

Wi-Fi on Ubuntu Server is configured with `netplan`{:.cmd}, not `NetworkManager`{:.cmd}, so the Wi-Fi power-save file from the desktop pages doesn't apply. A wired connection is the better choice for a server anyway.

{% include server-power.md part="check" %}

{% include server-power.md part="bios" %}

{% include claude-service.md %}

## Verify

{% include os-info.md %}
