---
title: About this site
permalink: /about/
---

How these pages are put together, the formatting conventions, and what to keep in mind when editing them by hand. The source is the public GitHub repository [leewiscovitch/wiscovitch-install](https://github.com/leewiscovitch/wiscovitch-install); every push to `main`{:.val} is published by GitHub Pages a minute or two later.

## How pages are built

Each OS page is a Markdown file at the top of the repository (`windows.md`{:.path}, `ubuntu-desktop.md`{:.path}, …), rendered by Jekyll with the shared layout `_layouts/default.html`{:.path}. Nothing is copied between pages; shared pieces live in one place:

| Where | What it holds |
|---|---|
| Front matter of each page | `title`{:.val}, `permalink`{:.val}, `pm`{:.val} (its package manager), `packages`{:.val} (the install list), `os_version`{:.val} (expected Verify result); Windows also has the `remove`{:.val} app groups |
| `_data/pm.yml`{:.path} | update and install commands per package manager (`apt`{:.cmd}, `dnf`{:.cmd}, `pacman`{:.cmd}, `winget`{:.cmd}) |
| `_config.yml`{:.path} | site settings (`user`{:.val}, time zone, GitHub user for SSH keys) and every pinned version with its SHA-256 (OpenSSH and PowerShell MSIs, PowerShell modules) |
| `_includes/*.md`{:.path} | steps shared by several pages: sudoers, time zone, update, install, SSH, `git`{:.cmd}, server use, Claude Code services, app removal, and the no-output note |
| `_layouts/default.html`{:.path} | page frame, colours (light and dark), the section bar, Copy buttons, and small scripts for code-block colouring and output blocks |

Every OS page has the same sections in the same order: Before you start, Time zone, Update, Install, (Windows: Remove apps, PowerShell 7, Settings; Ubuntu Desktop: Settings), Configure, Optional, Verify. The bar at the top is built from those `##` headings automatically.

## Code blocks

Commands go in fenced blocks tagged with their shell, <code>&#96;&#96;&#96;bash</code> or <code>&#96;&#96;&#96;powershell</code>, one command per line. Chained bash commands end each line with ` &&\` so you can paste the whole block; package lists stay on one line. Every command block gets a Copy button.

Code blocks are coloured by the highlighter (Rouge). Its bash support only knows shell builtins, so a small script in the layout also colours the command word of each bash command (`ssh-keygen`{:.cmd}, `timedatectl`{:.cmd}, …) by its position, and makes every `sudo`{:.sudo} bold red. Neither changes the text you copy.

## Inline code tags

Commands, names, paths and values mentioned in normal text are always in backticks, followed by a tag that sets their colour. Untagged inline code shows in plain text colour.

| Markdown | Looks like | Use for |
|---|---|---|
| ``` `nano`{:.cmd} ``` | `nano`{:.cmd} | commands, programs and packages (orange) |
| ``` `tech`{:.user} ``` | `tech`{:.user} | users, hosts and environment names (green) |
| ``` `/opt/claude`{:.path} ``` | `/opt/claude`{:.path} | paths, files, URLs of settings pages, registry hives (blue) |
| ``` `Bypass`{:.val} ``` | `Bypass`{:.val} | values, settings, variables and text a command prints (purple) |
| ``` `sudo`{:.sudo} ``` | `sudo`{:.sudo} | every mention of `sudo`{:.sudo} (bold red, because it runs as root) |

{% raw %}The site's own user is written as `` `{{ site.user }}`{:.user} `` so it follows `_config.yml`.{% endraw %} Product names (Claude Code, PowerShell 7, Windows Terminal) and website names stay plain text. The colours meet contrast guidelines in light and dark mode, and orange and green are kept apart for red-green colour blindness.

## Expected output

What a command prints goes in its own block right after it, tagged <code>&#96;&#96;&#96;output</code>:

~~~markdown
```bash
sudo visudo -cf /etc/sudoers.d/tech
```

```output
/etc/sudoers.d/tech: parsed OK
```
~~~

Output blocks get an "Output" label, the page background with a dashed border, muted text and no Copy button. Output longer than about a dozen lines collapses to its first and last four lines with a "Show all" toggle, so paste the full output. Parts that differ per machine are written as placeholders like `<n>`{:.val} and `<version>`{:.val}, and skipped stretches as `…`{:.val}.

{% raw %}A command that prints nothing gets a one-line note instead: `{% include no-output.md %}` shows "Nothing when it succeeds." Add `text="…"` for anything else worth saying, for example `{% include no-output.md text="Asks for: Git name, Git email." %}`.{% endraw %}

## Editing by hand

1. **Edit the right place.** A command used on several pages lives in an include or `_data/pm.yml`{:.path}; a version lives in `_config.yml`{:.path} (change the version and its SHA-256 together). Only page-specific steps are written in the page itself.
2. **Keep the formatting:** one command per line, ` &&\` between chained bash commands, package lists on one line, and PowerShell lines as they are (no backtick line continuations).
3. **Tag inline code** in any new text with `{:.cmd}`{:.val}, `{:.user}`{:.val}, `{:.path}`{:.val}, `{:.val}`{:.val} or `{:.sudo}`{:.val}, and put command, user and path names in backticks.
4. **Add the expected output** (<code>&#96;&#96;&#96;output</code>) or the no-output note under any new command block, ideally from a real run.
5. **No secrets.** The repository and site are public: no passwords, keys, tokens, Wi-Fi passwords, internal addresses or hostnames. Describe placeholders in text (`<` breaks PowerShell blocks).
6. **Inside includes,** keep Markdown at column 0 and code fences on their own lines.
7. **New files that aren't pages** (notes, docs) go into `exclude:`{:.val} in `_config.yml`{:.path}, or Jekyll publishes them.
8. **Push to `main`{:.val}** and check the live page; there's no local preview. A browser may show a cached copy for a moment, so reload.

## Testing

Every push is tested against the live site: each page's command blocks are taken from the published HTML and run in order.

- **Containers** (GitHub Actions): every Linux page in a fresh container of each distro, and the Windows page on Windows Server. Commands that need a running system (`systemd`{:.cmd}, a desktop) are replaced by stand-ins or skipped with a stated reason.
- **Virtual machines** (a Proxmox homelab): each page on a fresh VM, including a reboot and checks that the settings survived; Windows runs inside a real desktop session.
- **Real hardware** for the steps VMs can't cover, like laptop lids, Wi-Fi and drivers.

Output blocks and notes aren't run. When a step can't run in a test, the test runner gets a skip rule with a reason; the step on the page stays as it is.
