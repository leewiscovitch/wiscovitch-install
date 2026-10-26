# wiscovitch-install

Source for https://install.wiscovitch.org: copy/paste steps for setting up a fresh OS, one page per OS. Hosted on GitHub Pages from `main` of the public repo `leewiscovitch/wiscovitch-install`. There's no local preview; changes are checked by pushing and loading the live site.

## Layout

- `index.md` links to each OS page. OS pages are top-level `<os>.md` files with a `permalink:` (e.g. `ubuntu-desktop.md` → `/ubuntu/desktop/`). `alma.md` also serves `/rocky/` via `redirect_from`.
- Every OS page has the same `##` sections in this order: Before you start, Time zone, Update, Install, Configure, Optional, Verify. Time zone comes before Update because a wrong clock breaks package signature and TLS checks. Windows also has **Remove apps** (before Update, so updates don't upgrade apps about to be removed), and **PowerShell 7** and **Settings** (after Install), and Ubuntu Desktop has **Settings** (GNOME `gsettings`) before Configure. Windows Settings holds registry/powercfg tweaks written inline in `windows.md`. Remove apps is driven by the `remove:` groups in `windows.md` front matter and `_includes/remove.md`; app `id`s are version-free package names, since Store app IDs in `winget list` include the version. The layout builds the sticky section bar from the `##` headings, so don't add a manual table of contents.
- Front matter: `title` (rendered as the h1 by the layout; don't add a `#` heading), `pm` (key in `_data/pm.yml`), `packages` (list for the install step), and optional `parent` / `parent_title` for the back link on sub-pages.
- `_data/pm.yml` holds the update/install command for each package manager (apt, dnf, pacman, winget). Change a command there to change it for every OS that uses it. `update` is a list of commands, not one `&&` string.
- Code blocks are line by line: chained bash commands go one per line ending in ` &&\` (e.g. `sudo apt update &&\` then `sudo apt full-upgrade -y`). Package lists stay on one line after the install command. Follow the same style for steps written inline in pages. Leave PowerShell/winget lines as they are (no backtick continuations).
- `_includes/*.md` are shared step blocks (`sudoers.md`, `timezone.md`, `ssh-config.md`, `ssh-server.md`, `update.md`, `install.md`, `git-config.md`, `os-info.md`, `server-power.md` (Linux Optional "server use": `part=` lid, wifi, check, bios), `claude-service.md` (Linux Optional: Claude Code as a systemd+tmux service with Remote Control); Windows-only: `remove.md`, `remove-again.md`, `ps-module.md`) that read `page.pm` / `page.packages`, and site settings from `_config.yml`: `site.user` (account name), `site.timezone` / `site.timezone_windows`, and `site.github_user` (whose `github.com/<user>.keys` are trusted for SSH). Versions live in one place, `_config.yml`: the MSIs (`openssh_msi`, `pwsh_msi`: version, release tag where needed, SHA-256; download URLs are built from them) and PowerShell Gallery modules (`ps_modules`, installed by `_includes/ps-module.md` from the Gallery's direct `.nupkg` link instead of `Install-Module`), plus `winget_version` (last tested, for notes only). Check steps end with a `# <expected value>` comment built from these; each OS page's `os_version` front matter is the expected result of its Verify step. `proxmox/windows/build.sh` and `test.yml` read the same values. `ssh.md` (`/ssh/`) is a cross-OS guide page linked from the index, not an OS page. `about.md` (`/about/`) explains the conventions for people editing by hand (structure, tags, output blocks, checklist, testing) and is linked from a quiet footer on every page; update it when a convention changes. Steps used by more than one OS belong here, not copy-pasted; OS-specific steps go inline in the page.
- Inline code in prose is always tagged with its kind, which the layout colours (light and dark shades in `_layouts/default.html`): `` `nano`{:.cmd} `` commands, programs and packages (orange), `` `tech`{:.user} `` users, hosts and environment names (green; `` `{{ site.user }}`{:.user} ``), `` `/opt/claude`{:.path} `` paths, files and registry hives (blue), `` `Bypass`{:.val} `` values, settings, variables and output text (purple), and `` `sudo`{:.sudo} `` for every mention of `sudo` (bold bright red; the layout script also marks `sudo` in code blocks). Command, user and path names mentioned in prose always go in backticks. Code blocks are not tagged.
- Expected output: after a command block, add a ```` ```output ```` block with what it prints (real output from a test run where possible; `<n>`/`<version>` for parts that vary, `…` for skipped lines; long output is collapsed by the layout), or `{% include no-output.md %}` when it prints nothing (`text="..."` for prompts and other notes). Output blocks get no Copy button and aren't run by the tests (`tests/extract.py` skips them).
- `about.md` (`/about/`) is the human-readable version of these conventions (structure, code blocks, inline tags, `sudo`, expected output, manual-edit checklist, testing). Follow it, and update it in the same commit whenever a convention changes or a new one is added.
- Inside includes, keep Markdown at column 0 and fenced blocks on their own lines, since Liquid output is fed to kramdown as-is.
- `_layouts/default.html` is the page wrapper: styles (light/dark via `prefers-color-scheme`), back link, h1, section bar and the copy-button script.
- `_config.yml` is Jekyll config: default layout for every page, the `jekyll-redirect-from` plugin, and `exclude:` to keep repo-only files off the site.
- `CNAME` sets the custom domain. Don't remove it or Pages drops the domain.

## Rules

- **The repo and site are public.** Never commit passwords, keys, tokens, Wi-Fi PSKs, internal IPs or hostnames. Use placeholders like `<WIFI_PASSWORD>`.
- **Never commit `wiscovitch.org.txt`** (Cloudflare DNS export) or `CLAUDE.local.md`; both are gitignored.
- New repo-only files (docs, notes) must be added to `exclude:` in `_config.yml`, or Jekyll publishes them.
- Pages builds with GitHub's built-in Jekyll (`build_type: legacy`), which adds `jekyll-titles-from-headings`: `page.title` comes from the first `#` heading.

## Copy button

The script tries `navigator.clipboard.writeText`, falls back to a hidden textarea + `execCommand('copy')`, and as a last resort selects the code and shows "Press Ctrl+C". It reads each block's text before inserting the button so the label isn't copied. Keep all three paths: a fresh OS may be on plain http or an old browser.

## CI tests

`.github/workflows/test.yml` runs after every GitHub Pages build (`page_build`; also manual via `workflow_dispatch`). It waits until the live site's `<meta name="revision">` matches the commit, extracts each page's code blocks from the **live** HTML (`tests/extract.py`), and runs them in page order:

- Linux pages in fresh containers (`tests/run_linux.sh`) as a sudo user `tech`. `systemctl`, `timedatectl`, `gsettings`, `chsh` are stubs (no systemd/desktop), so those blocks report "stubbed"; a block that is just `bash` is skipped. Prompts get test answers.
- The Windows page on `windows-latest` (Windows Server) via `tests/run_windows.ps1`, in Windows PowerShell 5.1 (a pwsh step shell gets killed when the page upgrades PowerShell 7). Each block's statements are checked for native exit codes; benign winget codes pass. Skipped there: Windows Update install, Store scan, `winget upgrade --all`, Explorer restart. The SSH check passes when sshd accepts the key; GitHub runners can't start the SSH session itself.
- `tests/summarize.py` writes a per-block table to the job summary; blocks and logs are uploaded as artifacts.

When adding a step that can't run in CI, add a skip rule in the runner with a reason rather than weakening the step on the page. Placeholders like `<NAME>` break PowerShell parsing (`<` is reserved); describe them in text instead of inside a PowerShell block.

## Proxmox VM tests

`proxmox/` holds the homelab VM-test setup (self-hosted runner + cloud-init templates); `proxmox/README.md` is the step-by-step build log, kept runnable by hand. Host-specific values go in gitignored `proxmox/config.env` and `CLAUDE.local.md`, never in the repo. `proxmox/vm.sh` (clone/start/ip/reboot/destroy via the API) and `proxmox/smoke-test.sh` run on the runner container; copy them there after changing them.

Windows VM tests (`tests/run_vm_windows.sh`) run the page **inside tech's desktop session** (`-Target desktop`) via `tests/windows_desktop_task.ps1`: the template auto-logs in, and the helper runs a script through a scheduled task with an Interactive principal. That's required for the `winget` command, MSIX installs and Explorer, none of which work from an SSH (network) logon. If no session is active it falls back to plain SSH (`-Target vm`), which skips plain `winget` blocks in favour of the page's "Over SSH" block. The same script tests a physical machine with `host:<IP>` while someone is logged in (console or RDP). Windows Update install and `Restart-Computer` are skipped in every mode; the test reboots separately.

## Checking changes

Ruby/Jekyll isn't installed locally and includes/data only render under real Jekyll, so push and check the live site. Test copy over `http(s)://`, not a `file:`/`data:` URL: those can't reach the system clipboard.

To check the live build after a push:

```bash
gh api repos/leewiscovitch/wiscovitch-install/pages/builds/latest --jq '.status + " " + .commit[0:7]'
```
