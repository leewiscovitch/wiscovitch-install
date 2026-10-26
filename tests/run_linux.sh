#!/usr/bin/env bash
# Run one page's bash blocks, in order, inside a fresh distro container.
#
# Usage (as root in the container): run_linux.sh BLOCKDIR
#
# Blocks run as a regular sudo user, like on a real install. Containers have no
# systemd or desktop, so systemctl/timedatectl/gsettings/chsh are replaced by
# stubs that only log the call; blocks that use them are reported as "stubbed".
# Results go to BLOCKDIR/results.tsv (name, status, note) and BLOCKDIR/NNN.log.
set -u
dir=$1
user=tech
results=$dir/results.tsv
: > "$results"
export DEBIAN_FRONTEND=noninteractive

# Prep: sudo and a sudo user (the page's own sudoers step runs later and is tested too)
if command -v apt-get >/dev/null; then
    apt-get update -qq && apt-get install -y -qq sudo >/dev/null
elif command -v dnf >/dev/null; then
    dnf install -y -q sudo >/dev/null
elif command -v pacman >/dev/null; then
    pacman -Sy --noconfirm --needed sudo >/dev/null
fi
id "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user"
cat > /etc/sudoers.d/00-ci <<EOF
$user ALL=(ALL) NOPASSWD: ALL
Defaults env_keep += "DEBIAN_FRONTEND"
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
chmod 0440 /etc/sudoers.d/00-ci

for cmd in systemctl timedatectl gsettings chsh dconf busctl NetworkManager; do
    printf '#!/bin/sh\necho "[stub] %s $*"\n' "$cmd" > "/usr/local/bin/$cmd"
    chmod +x "/usr/local/bin/$cmd"
done
# Folders systemd and login shells provide on a real install
mkdir -p /etc/systemd/system /etc/profile.d
# GDM's login-screen defaults file, as a desktop install has it (only its power section header)
if command -v apt-get >/dev/null && [ ! -e /etc/gdm3/greeter.dconf-defaults ]; then
    mkdir -p /etc/gdm3 && printf '[org/gnome/settings-daemon/plugins/power]\n' > /etc/gdm3/greeter.dconf-defaults
fi

for f in "$dir"/*.bash; do
    name=$(basename "$f" .bash)
    log=$dir/$name.log
    if grep -qx 'bash' "$f"; then
        printf '%s\tskip\tstarts an interactive shell\n' "$name" >> "$results"
        continue
    fi
    # Claude Code service: signing in is interactive (a person approves it in a browser),
    # and the plugin and the Remote Control check need that sign-in
    if grep -q 'claude --remote-control "$(hostname -s)"\|^claude plugin \|grep -o .rc active' "$f"; then
        printf '%s	skip	needs the one-time claude.ai sign-in
' "$name" >> "$results"
        continue
    fi
    # The server-use check reads a running logind/NetworkManager; the VM tests check it
    if grep -q '^busctl get-property org.freedesktop.login1' "$f"; then
        printf '%s\tskip\treads running logind/NetworkManager (checked in VM tests)\n' "$name" >> "$results"
        continue
    fi
    tmp=/tmp/$name.sh
    cp "$f" "$tmp" && chmod a+r "$tmp"
    # Answer prompts like a person would: test values for read -p, "y" for anything else
    if grep -q 'read -rp' "$f"; then
        printf 'CI Test\nci@example.com\n' | sudo -u "$user" -H bash -c 'cd ~ && bash "$0"' "$tmp" > "$log" 2>&1
    else
        yes 2>/dev/null | sudo -u "$user" -H bash -c 'cd ~ && bash "$0"' "$tmp" > "$log" 2>&1
    fi
    rc=$?
    if [ "$rc" -ne 0 ]; then
        printf '%s\tfail\texit %s\n' "$name" "$rc" >> "$results"
    elif grep -q '^\[stub\]' "$log"; then
        printf '%s\tstubbed\t%s\n' "$name" "$(grep -o '^\[stub\] [a-z]*' "$log" | sort -u | cut -d' ' -f2 | paste -sd, -)" >> "$results"
    else
        printf '%s\tpass\t\n' "$name" >> "$results"
    fi
done

# Extra checks after all blocks: config files the page wrote should be valid
if [ -f /home/$user/.ssh/config ] && ! command -v ssh >/dev/null; then
    printf 'check-ssh-config\tskip\tno ssh client in this container image\n' >> "$results"
elif [ -f /home/$user/.ssh/config ]; then
    if sudo -u "$user" -H ssh -G example.com > "$dir/check-ssh-config.log" 2>&1 && grep -qx 'stricthostkeychecking accept-new' "$dir/check-ssh-config.log"; then
        printf 'check-ssh-config\tpass\tssh -G reads accept-new\n' >> "$results"
    else
        printf 'check-ssh-config\tfail\tssh -G did not read the config\n' >> "$results"
    fi
fi
if command -v sshd >/dev/null || [ -x /usr/sbin/sshd ]; then
    # Host keys and /run/sshd are normally created by the systemd unit, which doesn't run here
    ssh-keygen -A >/dev/null 2>&1
    mkdir -p /run/sshd
    if /usr/sbin/sshd -t > "$dir/check-sshd-config.log" 2>&1; then
        printf 'check-sshd-config\tpass\tsshd -t\n' >> "$results"
    else
        printf 'check-sshd-config\tfail\tsshd -t\n' >> "$results"
    fi
fi
keys=$(grep -c '^ssh-' /home/$user/.ssh/authorized_keys 2>/dev/null || echo 0)
printf 'check-authorized-keys\t%s\t%s keys\n' "$([ "$keys" -gt 0 ] && echo pass || echo fail)" "$keys" >> "$results"
chmod -R a+rw "$dir"
