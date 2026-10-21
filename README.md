# wiscovitch-install

Source for <https://install.wiscovitch.org>, copy/paste steps for setting up a fresh OS, one page per OS.

- Each OS has a page (`windows.md`, `ubuntu-desktop.md`, `fedora.md`, ...) with the same sections: Before you start, Update, Install, Configure, Optional, Verify.
- Shared commands live in `_data/pm.yml` (per package manager) and `_includes/` (reusable steps), so a change there updates every OS that uses it.
- Every fenced code block gets a **Copy** button.
- GitHub Pages builds and publishes the site on every push to `main`.
- This repo is public. Never put passwords, keys or tokens in it; use placeholders like `<WIFI_PASSWORD>`.
