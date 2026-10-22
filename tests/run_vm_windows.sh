#!/usr/bin/env bash
# Run the Windows page on a fresh Windows 11 VM (Proxmox template), reboot it, and
# check that the page's changes survived. Runs on the self-hosted runner.
#
# Usage: run_vm_windows.sh TEMPLATE_ID VM_NAME BLOCKDIR
#
# The blocks and tests/run_windows.ps1 are copied to the VM, which runs them in
# Windows PowerShell 5.1 as `tech` (an administrator, via SSH). After a reboot,
# tests/check_windows.ps1 checks the settings. Results land in BLOCKDIR like the
# other runners. The VM is always destroyed.
set -u
tpl=$1 name=$2 dir=$3
here=$(cd "$(dirname "$0")" && pwd)
vm="$here/../proxmox/vm.sh"
results=$dir/results.tsv
: > "$results"
add() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$results"; }

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR -o ServerAliveInterval=30)
# Run PowerShell on the VM from stdin. The SSH default shell is cmd.exe at first (the
# page switches it to pwsh), so send it Base64-encoded to avoid any shell quoting.
# -ExecutionPolicy Bypass: a fresh Windows 11 is Restricted until the page's first step.
PS() {
    local b64
    b64=$(python3 -c 'import sys,base64; print(base64.b64encode(sys.stdin.read().encode("utf-16-le")).decode())')
    ssh -n "${SSH_OPTS[@]}" "tech@$ip" "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $b64"
}
wait_ssh() { for _ in $(seq 1 90); do echo 'exit 0' | PS >/dev/null 2>&1 && return 0; sleep 5; done; return 1; }

id=$("$vm" clone "$tpl" "$name") || { add setup fail "clone of template $tpl failed"; exit 0; }
trap '"$vm" destroy "$id" >/dev/null 2>&1 && echo "destroyed VM $id"' EXIT
echo "VM $id cloned from $tpl"
"$vm" start "$id" >/dev/null
ip=$("$vm" ip "$id" 600) && wait_ssh || { add setup fail "VM $id never became reachable"; exit 0; }
setup_note="VM $id at $ip, $(echo '$o = Get-CimInstance Win32_OperatingSystem; "$($o.Caption) build $($o.BuildNumber)"' | PS 2>/dev/null | tr -d '\r')"

# Copy blocks and the runner script to the VM, run them there, copy results back
echo 'New-Item -ItemType Directory -Force C:\ci | Out-Null' | PS >/dev/null
scp -q "${SSH_OPTS[@]}" -r "$dir" "tech@$ip:C:/ci/blocks"
scp -q "${SSH_OPTS[@]}" "$here/run_windows.ps1" "$here/check_windows.ps1" "tech@$ip:C:/ci/"
echo "running the Windows page on VM $id"
echo '& C:\ci\run_windows.ps1 -Dir C:\ci\blocks -Target vm' | PS > "$dir/run_windows.log" 2>&1
if scp -q "${SSH_OPTS[@]}" "tech@$ip:C:/ci/blocks/*.log" "tech@$ip:C:/ci/blocks/results.tsv" "$dir/"; then
    # Windows wrote UTF-8 with a BOM and CRLF line endings
    sed -i 's/\r$//; s/^\xEF\xBB\xBF//' "$dir/results.tsv"
    sed -i "1i setup\tpass\t$setup_note" "$dir/results.tsv"
else
    : > "$results"; add setup pass "$setup_note"; add copy-results fail "could not copy results back from the VM"
fi

# Reboot, then check that the page's changes stuck
echo "rebooting VM $id"
"$vm" reboot "$id" >/dev/null 2>&1 || true
sleep 60
ip=$("$vm" ip "$id" 600) && wait_ssh || { add reboot fail "did not come back after reboot"; exit 0; }
add reboot pass "back up after reboot"

# With DefaultShell set by the page, a plain SSH command should land in PowerShell 7
shell=$(ssh -n "${SSH_OPTS[@]}" "tech@$ip" '$PSVersionTable.PSVersion.Major' 2>/dev/null | tr -d '\r')
if [ "$shell" = 7 ]; then add check-ssh-session pass "SSH session lands in PowerShell 7"; else add check-ssh-session fail "SSH session shell reported '$shell'"; fi
echo '& C:\ci\check_windows.ps1' | PS 2>/dev/null | tr -d '\r' | grep -P '^check-[^\t]+\t(pass|fail)\t' >> "$results"
exit 0
