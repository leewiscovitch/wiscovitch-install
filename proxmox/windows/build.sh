#!/usr/bin/env bash
# Build the Windows 11 VM-test template (VMID 9010). Run as root on the Proxmox host
# from a directory containing autounattend.xml and setup.ps1.
#
# Usage: build.sh WINDOWS_ISO_FILENAME     (an ISO in local:iso)
#
# Fully unattended: Windows 11 Pro installs from the ISO with VirtIO drivers from
# virtio-win.iso, creates local admin `tech` with a random password (stored only in
# the runner container), then setup.ps1 installs the guest agent and OpenSSH with the
# runner's key and shuts down. Takes 30-60 minutes. Never overwrites VMID 9010.
set -euo pipefail
cd "$(dirname "$0")"

ID=9010
NAME=tpl-win11
WIN_ISO=${1:?usage: build.sh WINDOWS_ISO_FILENAME}
ISO_DIR=/var/lib/vz/template/iso
ANSWER_ISO=ci-win11-answer.iso
RUNNER_CT=9050
log() { echo "[$(date +%H:%M:%S)] $*"; }

[ -f "$ISO_DIR/$WIN_ISO" ] || { log "not found: $ISO_DIR/$WIN_ISO"; exit 1; }
[ -f "$ISO_DIR/virtio-win.iso" ] || { log "not found: $ISO_DIR/virtio-win.iso"; exit 1; }
if qm status $ID >/dev/null 2>&1; then log "VMID $ID exists; destroy it first to rebuild"; exit 1; fi

# Random password for tech, kept only in the runner container (for console/RDP logins)
pw="Ci-$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)"
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sed "s|__PASSWORD__|$pw|g" autounattend.xml > "$work/autounattend.xml"
sed "s|__PASSWORD__|$pw|g" setup.ps1 > "$work/setup.ps1"   # auto-login
pct exec $RUNNER_CT -- cat /home/runner/.ssh/id_ed25519.pub > "$work/runner.pub"
genisoimage -quiet -J -r -V CI_ANSWER -o "$ISO_DIR/$ANSWER_ISO" "$work"
printf '%s\n' "$pw" > "$work/win-password"
pct push $RUNNER_CT "$work/win-password" /home/runner/.config/ci/win-password --perms 0600
pct exec $RUNNER_CT -- chown runner:runner /home/runner/.config/ci/win-password
log "answer-file ISO built; tech password stored in CT $RUNNER_CT:/home/runner/.config/ci/win-password"

qm create $ID --name $NAME --pool ci --ostype win11 --machine q35 --bios ovmf --cpu host \
  --cores 4 --memory 8192 --balloon 0 --scsihw virtio-scsi-single \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=1 --tpmstate0 local-lvm:1,version=v2.0 \
  --scsi0 local-lvm:64,discard=on,ssd=1 --net0 virtio,bridge=vmbr0 --agent enabled=1 \
  --ide0 "local:iso/$WIN_ISO,media=cdrom" --ide1 local:iso/virtio-win.iso,media=cdrom \
  --ide3 "local:iso/$ANSWER_ISO,media=cdrom" --boot 'order=ide0;scsi0' \
  --description "Windows 11 template for install.wiscovitch.org VM tests (proxmox/windows/build.sh)"
log "VM $ID created; starting install"
qm start $ID
# The Windows ISO's UEFI loader waits for a key press ("Press any key to boot from CD"),
# shown for a few seconds after power-on. Only press during that window: later presses
# reach Windows Setup, where Enter hits the focused Cancel button and Setup stops at
# "Are you sure you want to quit?" (it happened once; answering No resumes it).
for _ in $(seq 1 10); do qm sendkey $ID ret >/dev/null 2>&1 || true; sleep 1; done

log "waiting for setup to finish and power off (up to 90 min)"
for _ in $(seq 1 540); do
  [ "$(qm status $ID | awk '{print $2}')" = stopped ] && break
  sleep 10
done
if [ "$(qm status $ID | awk '{print $2}')" != stopped ]; then
  log "VM $ID still running after 90 min; left running for inspection (console in the web UI)"; exit 1
fi

qm set $ID --delete ide0,ide1,ide3 --boot order=scsi0 >/dev/null
rm -f "$ISO_DIR/$ANSWER_ISO"   # contains the password
qm template $ID
log "template $ID ready"
