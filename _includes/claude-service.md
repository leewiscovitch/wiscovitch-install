{%- assign pm = site.data.pm[page.pm] -%}
### Claude Code as a service

Keeps [Claude Code](https://code.claude.com/docs) running as `{{ site.user }}`{:.user} from boot (nobody needs to sign in) and reachable from the Claude desktop app, claude.ai/code and the phone app through **Remote Control**. Claude runs inside a detached `tmux`{:.cmd} session, because it needs a terminal that `systemd`{:.cmd} doesn't provide, so you can also attach to it over SSH. Each service has its own `tmux`{:.cmd} server (`tmux -L <service>`{:.cmd}), so the two never interfere. The units start `tmux`{:.cmd} through `/bin/sh`{:.path}, because SELinux (on by default on Fedora, AlmaLinux and Rocky) doesn't let `systemd`{:.cmd} start `tmux`{:.cmd} directly. Each service works in its own folder under `/opt/claude/`{:.path}: Claude never remembers folder trust for a home folder, and keeps conversation history per folder. Tested on Ubuntu Desktop 26.04.

There are two services. Pick either, or run both side by side:

| | **Session service** (`claude-session`{:.cmd}) | **Server service** (`claude-server`{:.cmd}) |
|---|---|---|
| What runs | one long conversation | a Remote Control server that starts sessions on demand |
| In the Remote Control list | a session named after the hostname | an **environment** named after its folder (here `homelab`{:.user}), with a pre-created session named after the hostname |
| Start new sessions from claude.ai/code or the phone | no | yes, up to 4 at once |
| Desktop app | attach to the session | attach to running sessions (its **New** picker doesn't list other machines' servers) |
| After a restart or reboot | resumes the same conversation | starts a fresh session; earlier ones stay in history (the CLI can't resume in server mode) |
| Folder | `/opt/claude/<hostname>`{:.path} | `/opt/claude/homelab`{:.path} (the folder name is the environment's name) |

Remote Control needs a sign-in with your **claude.ai subscription account**. It doesn't work with an API key or a `claude setup-token`{:.cmd} token, and setting `ANTHROPIC_API_KEY`{:.val}, `ANTHROPIC_AUTH_TOKEN`{:.val} or `CLAUDE_CODE_OAUTH_TOKEN`{:.val} for this account silently switches it to the wrong kind of sign-in. Everything below runs as `{{ site.user }}`{:.user}.

Install `tmux`{:.cmd} and Claude Code, and create both folders. The official installer puts Claude in `~/.local/bin`{:.path} (on the PATH from your next login), verifies the download's checksum, and keeps Claude updated:

```bash
{{ pm.install }} tmux
curl -fsSL https://claude.ai/install.sh | bash
sudo install -d -o {{ site.user }} -g {{ site.user }} /opt/claude "/opt/claude/$(hostname -s)" /opt/claude/homelab
```

Sign in once, in a **new** SSH session (so `claude`{:.cmd} is on the PATH). Accept the folder trust prompt, pick your **Claude account with subscription**, open the link it prints in a browser on any computer, paste back the code, and accept Remote Control if asked. Check that the machine appears under Remote Control, then leave with `/exit`{:.cmd}:

```bash
cd "/opt/claude/$(hostname -s)" && claude --remote-control "$(hostname -s)"
```

Optional: the [superpowers](https://github.com/obra/superpowers) plugin for every session:

```bash
claude plugin marketplace add obra/superpowers-marketplace
claude plugin install superpowers@superpowers-marketplace
```

**Session service.** One conversation that `--continue`{:.cmd} reopens after every restart or reboot (it starts fresh if there's none); the loop restarts Claude if it exits. The unit is written with this machine's hostname and paths filled in:

```bash
n=$(hostname -s)
sudo tee /etc/systemd/system/claude-session.service > /dev/null << EOF
[Unit]
Description=Claude Code Remote Control session ($n) in /opt/claude/$n
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User={{ site.user }}
WorkingDirectory=/opt/claude/$n
Environment=HOME=$HOME
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/sh -c 'exec tmux -L claude-session new-session -d -s claude-session -c /opt/claude/$n "while true; do claude --continue --remote-control $n || claude --remote-control $n; sleep 5; done"'
ExecStop=/bin/sh -c 'exec tmux -L claude-session kill-server'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload &&\
sudo systemctl enable --now claude-session
```

**Server service.** Sessions started from claude.ai/code or the phone run in `/opt/claude/homelab`{:.path} in `auto`{:.val} permission mode (change `--permission-mode`{:.cmd} to `default`{:.val} to have them ask first). The first start asks two questions in its `tmux`{:.cmd} session, trusting the folder and enabling Remote Control, so attach once and answer `y`{:.val} to both (see below):

```bash
n=$(hostname -s)
sudo tee /etc/systemd/system/claude-server.service > /dev/null << EOF
[Unit]
Description=Claude Code Remote Control server (environment: homelab) in /opt/claude/homelab
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User={{ site.user }}
WorkingDirectory=/opt/claude/homelab
Environment=HOME=$HOME
Environment=PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/bin/sh -c 'exec tmux -L claude-server new-session -d -s claude-server -c /opt/claude/homelab "while true; do claude remote-control --name $n --spawn same-dir --capacity 4 --permission-mode auto; sleep 5; done"'
ExecStop=/bin/sh -c 'exec tmux -L claude-server kill-server'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload &&\
sudo systemctl enable --now claude-server
```

A reminder at every login on how to reach them:

```bash
sudo tee /etc/profile.d/claude-service.sh > /dev/null << 'EOF'
for s in claude-session claude-server; do
  systemctl is-enabled --quiet $s 2>/dev/null || continue
  systemctl is-active --quiet $s || echo "$s.service is NOT running (systemctl status $s)"
  echo "Claude Code $s: as {{ site.user }}, attach with \`tmux -L $s attach\`, detach with Ctrl+b then d."
done
EOF
```

Check whichever you set up:

```bash
systemctl is-active claude-session claude-server   # active (one line per service)
tmux -L claude-session capture-pane -p | grep -o 'rc active'   # rc active (Remote Control, in the status bar)
tmux -L claude-server capture-pane -p | grep -o 'Connected · homelab'   # Connected · homelab
```

To attach: `tmux -L claude-session attach`{:.cmd} or `tmux -L claude-server attach`{:.cmd}; detach with Ctrl+b then d. Inside, don't use `/exit`{:.cmd} (the loop just starts Claude again); detach instead. A one-time dialog (like a "try the new renderer" offer) can wait on screen after an update: attach and answer it. Sessions use the permission mode set for them (the session service: this account's setting); with passwordless `sudo`{:.cmd}, a remote message can change the whole system, so choose the mode deliberately.

**Optional: new sessions from the desktop app over SSH.** The desktop app's **New** button can't start sessions through either service. To start fresh ones from it, add this machine as an SSH environment in the app (**New → environment picker → + New environment**) with this host, user `{{ site.user }}`{:.user}, a key the machine trusts (any key on your GitHub account, see [SSH keys]({{ '/ssh/' | relative_url }})), and a folder of its own:

```bash
sudo install -d -o {{ site.user }} -g {{ site.user }} /opt/claude/work
```

Use `/opt/claude/work`{:.path} (or any folder other than the services'): the session service reopens the most recent conversation **in its folder**, so sessions started there would be picked up instead of its own. SSH sessions use the desktop computer's plugins (without their hooks) and end when you close them; the services keep running alongside.
