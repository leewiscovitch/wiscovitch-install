---
title: CachyOS
permalink: /cachyos/
os_version: CachyOS (rolling release)   # shown as the expected result of the Verify step
pm: pacman
packages:
  - git
  - curl
  - vim
  - htop
---

## Before you start

Run as a user with `sudo` rights.

CachyOS defaults to fish, but these steps use bash syntax. Make bash the login shell (asks for your password):

```bash
chsh -s /bin/bash
```

Then switch to bash in the current terminal:

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

_No steps yet._

## Verify

{% include os-info.md %}
