# wiscovitch-install

Source for https://install.wiscovitch.org: copy/paste steps for setting up a fresh OS, one page per OS. Hosted on GitHub Pages from `main` of the public repo `leewiscovitch/wiscovitch-install`. There's no local preview; changes are checked by pushing and loading the live site.

## Layout

- `index.md` links to each OS page. OS pages are top-level `<os>.md` files with a `permalink:` (e.g. `ubuntu-desktop.md` → `/ubuntu/desktop/`). `alma.md` also serves `/rocky/` via `redirect_from`.
- Every OS page has the same `##` sections in this order: Before you start, Update, Install, Configure, Optional, Verify. The layout builds the sticky section bar from the `##` headings, so don't add a manual table of contents.
- Front matter: `title` (rendered as the h1 by the layout; don't add a `#` heading), `pm` (key in `_data/pm.yml`), `packages` (list for the install step), and optional `parent` / `parent_title` for the back link on sub-pages.
- `_data/pm.yml` holds the update/install command for each package manager (apt, dnf, pacman, winget). Change a command there to change it for every OS that uses it. `update` is a list of commands, not one `&&` string.
- Code blocks are line by line: chained bash commands go one per line ending in ` &&\` (e.g. `sudo apt update &&\` then `sudo apt full-upgrade -y`), and bash package lists put one package per indented line with `\` continuations. Follow the same style for steps written inline in pages.
- `_includes/*.md` are shared step blocks (`sudoers.md`, `update.md`, `install.md`, `git-config.md`, `os-info.md`) that read `page.pm` / `page.packages`, and `site.user` (the account name, set in `_config.yml`). Steps used by more than one OS belong here, not copy-pasted; OS-specific steps go inline in the page.
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

## Checking changes

Ruby/Jekyll isn't installed locally and includes/data only render under real Jekyll, so push and check the live site. Test copy over `http(s)://`, not a `file:`/`data:` URL: those can't reach the system clipboard.

To check the live build after a push:

```bash
gh api repos/leewiscovitch/wiscovitch-install/pages/builds/latest --jq '.status + " " + .commit[0:7]'
```
