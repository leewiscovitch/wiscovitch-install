---
title: CachyOS
permalink: /cachyos/
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
