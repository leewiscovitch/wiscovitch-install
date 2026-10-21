---
title: AlmaLinux / Rocky Linux
permalink: /alma/
redirect_from:
  - /rocky/
pm: dnf
packages:
  - git
  - curl
  - vim
  - htop
---

## Before you start

Run as a user with `sudo` rights. Same steps for AlmaLinux and Rocky Linux.

{% include sudoers.md %}

## Update

{% include update.md %}

## Install

Enable EPEL first (`htop` and many extras come from it):

```bash
sudo dnf install -y epel-release
```

{% include install.md %}

## Configure

{% include git-config.md %}

## Optional

_No steps yet._

## Verify

{% include os-info.md %}
