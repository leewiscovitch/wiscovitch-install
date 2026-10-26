#!/usr/bin/env bash
# Run one page's bash blocks, in order, on a fresh Proxmox VM; then reboot it and
# check that the page's changes survived. Runs on the self-hosted runner.
#
# Usage: run_vm.sh TEMPLATE_ID VM_NAME BLOCKDIR
#
# The VM is a linked clone of TEMPLATE_ID and is always destroyed at the end.
# Blocks run over SSH as `tech`, with real systemd (no stubs). Results go to
# BLOCKDIR/results.tsv (name, status, note) and BLOCKDIR/NNN.log, like the
# container runner, so tests/summarize.py reports them the same way.
set -u
tpl=$1 name=$2 dir=$3
vm="$(dirname "$0")/../proxmox/vm.sh"
results=$dir/results.tsv
: > "$results"
add() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$results"; }

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR)
S() { ssh -n "${SSH_OPTS[@]}" "tech@$ip" "$@"; }
wait_ssh() { for _ in $(seq 1 60); do S true 2>/dev/null && return 0; sleep 5; done; return 1; }

id=$("$vm" clone "$tpl" "$name") || { add setup fail "clone of template $tpl failed"; exit 0; }
trap '"$vm" destroy "$id" >/dev/null 2>&1 && echo "destroyed VM $id"' EXIT
echo "VM $id cloned from $tpl"
"$vm" start "$id" >/dev/null
ip=$("$vm" ip "$id" 300) && wait_ssh || { add setup fail "VM $id never became reachable"; exit 0; }
# Like a person waiting for first boot to settle (cloud-init can hold the package lock)
S 'cloud-init status --wait >/dev/null 2>&1; true'
add setup pass "VM $id at $ip, $(S '. /etc/os-release; echo $PRETTY_NAME')"

scp -q "${SSH_OPTS[@]}" -r "$dir" "tech@$ip:/tmp/blocks"
for f in "$dir"/*.bash; do
    name=$(basename "$f" .bash)
    if grep -qx 'bash' "$f"; then add "$name" skip "starts an interactive shell"; continue; fi
    # Claude Code service: signing in is interactive, and the plugin and Remote Control check need it
    if grep -q 'claude --remote-control "$(hostname -s)"\|^claude plugin \|grep -o .rc active' "$f"; then add "$name" skip "needs the one-time claude.ai sign-in"; continue; fi
    # GNOME idle-sleep steps need a desktop; the cloud templates have none
    if grep -q 'dconf update' "$f" && ! S 'command -v dconf' >/dev/null 2>&1; then add "$name" skip "no GNOME desktop (dconf) on this VM"; continue; fi
    # Answer prompts like a person would: test values for read -p, "y" for anything else
    if grep -q 'read -rp' "$f"; then
        S "cd ~ && printf 'CI Test\nci@example.com\n' | bash /tmp/blocks/$name.bash" > "$dir/$name.log" 2>&1
    else
        S "cd ~ && yes 2>/dev/null | bash /tmp/blocks/$name.bash" > "$dir/$name.log" 2>&1
    fi
    rc=$?
    if [ $rc -eq 0 ]; then add "$name" pass ""; else add "$name" fail "exit $rc"; fi
done

# Reboot, then check that what the page set up is still in place
echo "rebooting VM $id"
S 'sudo systemctl reboot' >/dev/null 2>&1 || true
sleep 20
ip=$("$vm" ip "$id" 300) && wait_ssh || { add reboot fail "did not come back after reboot"; exit 0; }
add reboot pass "back up, uptime $(S 'cut -d. -f1 /proc/uptime')s"

check() {   # check NAME DESCRIPTION REMOTE_COMMAND
    if S "$3" > "$dir/check-$1.log" 2>&1; then add "check-$1" pass "$2"; else add "check-$1" fail "$2"; fi
}
check sudoers      "passwordless sudo from /etc/sudoers.d/tech" 'sudo -n test -f /etc/sudoers.d/tech'   # /etc/sudoers.d is root-only
check timezone     "time zone is America/New_York"              'test "$(timedatectl show -p Timezone --value)" = America/New_York'
check ntp          "network time sync on"                        'test "$(timedatectl show -p NTP --value)" = yes'
check sshd         "SSH server enabled and running"              'systemctl is-enabled ssh 2>/dev/null || systemctl is-enabled sshd; systemctl is-active ssh 2>/dev/null || systemctl is-active sshd'
check github-keys  "GitHub keys in authorized_keys"              'test "$(curl -fsSL https://github.com/'"${GITHUB_KEYS_USER:-leewiscovitch}"'.keys | grep -c .)" -le "$(grep -c "^ssh-" ~/.ssh/authorized_keys)"'
check ssh-config   "ssh client config: accept-new"               'ssh -G example.com | grep -qx "stricthostkeychecking accept-new"'
check git-identity "git name/email from the prompts"             'test "$(git config --global user.name)" = "CI Test" && test "$(git config --global user.email)" = ci@example.com'
check packages     "page packages installed (git, micro, htop)"  'command -v git && command -v micro && command -v htop'
if grep -qs 'HandleLidSwitch=ignore' "$dir"/*.bash; then   # the page's Optional server-use section
    check lid-ignore "logind ignores the lid (battery and AC)" 'busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch HandleLidSwitchExternalPower | grep -c "\"ignore\"" | grep -qx 2'
fi
for svc in claude-session claude-server; do   # the page's Claude Code services (they run until signed in)
    if grep -qs "$svc.service" "$dir"/*.bash; then
        check "$svc" "$svc.service enabled and running (tmux session)" "systemctl is-enabled $svc && systemctl is-active $svc && tmux has-session -t $svc"
    fi
done
if grep -qs 'wifi.powersave = 2' "$dir"/*.bash; then
    check wifi-powersave "NetworkManager Wi-Fi power save off" 'sudo NetworkManager --print-config | grep -qx "wifi.powersave=2"'
fi
exit 0
