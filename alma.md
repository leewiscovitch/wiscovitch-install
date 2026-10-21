---
title: AlmaLinux / Rocky Linux
permalink: /alma/
redirect_from:
  - /rocky/
pm: dnf
# No curl: EL ships curl-minimal, which provides the curl command and conflicts
# with the full curl package on EL9 (dnf refuses to install it).
packages:
  - git
  - vim
  - htop
---

## Before you start

Run as a user with `sudo` rights. Same steps for AlmaLinux and Rocky Linux.

{% include sudoers.md %}

## Time zone

{% include timezone.md %}

## Update

{% include update.md %}

## Install

Enable EPEL first (`htop` and many extras come from it):

```bash
sudo dnf install -y epel-release
```

{% include install.md %}

## Configure

{% include ssh-config.md %}

{% include ssh-server.md %}

{% include git-config.md %}

## Optional

_No steps yet._

## Verify

{% include os-info.md %}
