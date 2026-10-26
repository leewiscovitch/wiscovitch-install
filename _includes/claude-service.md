{%- assign pm = site.data.pm[page.pm] -%}
### Claude Code as a service

Runs one long-lived [Claude Code](https://code.claude.com/docs) session as `{{ site.user }}` that starts at boot (nobody needs to sign in), survives restarts and reboots, and is reachable from the Claude desktop app and phone through **Remote Control**. It runs inside a detached `tmux` session, because interactive Claude needs a terminal that systemd doesn't provide, so you can also attach to it over SSH. The session is named after the machine's short hostname and works in `/opt/claude/<hostname>`, since Claude never remembers folder trust for a home folder. Tested on Ubuntu Desktop 26.04.

Remote Control needs a sign-in with your **claude.ai subscription account**. It doesn't work with an API key or a `claude setup-token` token, and setting `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` or `CLAUDE_CODE_OAUTH_TOKEN` for this account silently switches it to the wrong kind of sign-in. Everything below runs as `{{ site.user }}`.

Install tmux and Claude Code. The official installer puts Claude in `~/.local/bin` (on the PATH from your next login), verifies the download's checksum, and keeps Claude updated:

```bash
{{ pm.install }} tmux
curl -fsSL https://claude.ai/install.sh | bash
sudo install -d -o {{ site.user }} -g {{ site.user }} /opt/claude "/opt/claude/$(hostname -s)"
```

Sign in once, in a **new** SSH session (so `claude` is on the PATH). Accept the folder trust prompt, pick your **Claude account with subscription**, open the link it prints in a browser on any computer, paste back the code, and accept Remote Control if asked. Check that the machine appears in the desktop app, then leave with `/exit`:

```bash
cd "/opt/claude/$(hostname -s)" && claude --remote-control "$(hostname -s)"
```

Optional: the [superpowers](https://github.com/obra/superpowers) plugin for every session:

```bash
claude plugin marketplace add obra/superpowers-marketplace
claude plugin install superpowers@superpowers-marketplace
```

The service. `--continue` reopens the last conversation after a restart or reboot (and starts fresh if there's none); the loop restarts Claude if it exits. The unit is written with this machine's hostname and paths filled in:

```bash
n=$(hostname -s)
sudo tee /etc/systemd/system/claude.service > /dev/null << EOF
[Unit]
Description=Claude Code (Remote Control: $n) in /opt/claude/$n
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User={{ site.user }}
WorkingDirectory=/opt/claude/$n
Environment=HOME=$HOME
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/tmux new-session -d -s claude -c /opt/claude/$n "while true; do claude --continue --remote-control $n || claude --remote-control $n; sleep 5; done"
ExecStop=/usr/bin/tmux kill-session -t claude
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload &&\
sudo systemctl enable --now claude
```

A reminder at every login on how to reach it:

```bash
sudo tee /etc/profile.d/claude-service.sh > /dev/null << 'EOF'
systemctl is-active --quiet claude 2>/dev/null || echo 'claude.service is NOT running (systemctl status claude)'
echo 'Claude Code service: as {{ site.user }}, attach with `tmux attach -t claude`, detach with Ctrl+b then d.'
EOF
```

Check:

```bash
systemctl is-active claude   # active
tmux capture-pane -p -t claude | grep -o 'rc active'   # rc active (Remote Control, in the status bar)
```

**Optional: new sessions from the desktop app over SSH.** The service is one long-lived session that the app attaches to under **Remote Control**; the app can't start more sessions through it. To start fresh ones on this machine from **New**, add it as an SSH environment in the Claude desktop app (**New → environment picker → + New environment**) with this host, user `{{ site.user }}`, a key the machine trusts (any key on your GitHub account, see [SSH keys]({{ '/ssh/' | relative_url }})), and a folder of its own:

```bash
sudo install -d -o {{ site.user }} -g {{ site.user }} /opt/claude/work
```

Use `/opt/claude/work` (or any folder other than the service's): after a restart the service reopens the most recent conversation **in its folder**, so sessions started there would be picked up instead of its own. SSH sessions use the desktop computer's plugins (without their hooks) and end when you close them; the service keeps running alongside.

Inside the session, don't use `/exit` (the loop just starts Claude again); detach instead. A one-time dialog (like a "try the new renderer" offer) can wait on screen after an update: attach and answer it. The session uses this account's permission mode; with passwordless sudo, a remote message can change the whole system, so consider keeping the mode on asking.
