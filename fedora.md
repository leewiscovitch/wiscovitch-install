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

_No steps yet._

## Verify

{% include os-info.md %}
