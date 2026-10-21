# wiscovitch-install

Source for https://install.wiscovitch.org: one page of copy/paste steps for setting up a fresh OS. Hosted on GitHub Pages from `main` of the public repo `leewiscovitch/wiscovitch-install`.

## Layout

- `index.md` holds the steps. Add steps as fenced code blocks with a language tag (`powershell`, `bash`); every block gets a Copy button automatically.
- `_layouts/default.html` is the page wrapper: styles (light/dark via `prefers-color-scheme`) and the copy-button script.
- `_config.yml` is Jekyll config; `exclude:` keeps repo-only files off the site.
- `CNAME` sets the custom domain. Don't remove it or Pages drops the domain.

## Rules

- **The repo and site are public.** Never commit passwords, keys, tokens, Wi-Fi PSKs, internal IPs or hostnames. Use placeholders like `<WIFI_PASSWORD>`.
- **Never commit `wiscovitch.org.txt`** (Cloudflare DNS export) or `CLAUDE.local.md`; both are gitignored.
- New repo-only files (docs, notes) must be added to `exclude:` in `_config.yml`, or Jekyll publishes them.
- Pages builds with GitHub's built-in Jekyll (`build_type: legacy`), which adds `jekyll-titles-from-headings`: `page.title` comes from the first `#` heading.

## Copy button

The script tries `navigator.clipboard.writeText`, falls back to a hidden textarea + `execCommand('copy')`, and as a last resort selects the code and shows "Press Ctrl+C". It reads each block's text before inserting the button so the label isn't copied. Keep all three paths: a fresh OS may be on plain http or an old browser.

## Previewing locally

No Ruby/Jekyll on this machine. To preview, render `index.md` with `gh api markdown -f mode=gfm`, substitute it into `{{ content }}` of the layout, write it to `_site/index.html` (gitignored), and serve with `python -m http.server 8765 --bind 127.0.0.1 --directory _site`. Test copy via `http://localhost`, not a `file:`/`data:` URL: those can't reach the system clipboard.

To check the live build after a push:

```bash
gh api repos/leewiscovitch/wiscovitch-install/pages/builds/latest --jq '.status + " " + .commit[0:7]'
```
