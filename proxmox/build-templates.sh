#!/usr/bin/env bash
# Build the cloud-init VM templates for the VM tests. Run as root on the Proxmox host.
#
# Usage: build-templates.sh [VMID ...]     (no args = all templates below)
#
# Each template: the distro's official cloud image as the disk, cloud-init user
# `tech` with the runner's SSH key, and the QEMU guest agent installed (so the
# runner can find a clone's IP). The machine ID is cleared before the template
# is sealed, so clones running side by side get distinct DHCP leases.
# An existing VMID is never overwritten; destroy it first to rebuild.
set -euo pipefail

STORAGE=local-lvm
BRIDGE=vmbr0
POOL=ci
DISK_SIZE=20G
IMPORT=/var/lib/vz/import
ISO=/var/lib/vz/template/iso
SNIPPET=ci-template-firstboot.yaml
RUNNER_CT=9050

# VMID  name              image path
TEMPLATES=(
  "9000 tpl-ubuntu-2604   $ISO/resolute-server-cloudimg-amd64.img"
  "9001 tpl-fedora-44     $IMPORT/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"
  "9002 tpl-alma-9        $IMPORT/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
  "9003 tpl-alma-10-v2    $IMPORT/AlmaLinux-10-GenericCloud-latest.x86_64_v2.qcow2"
  "9004 tpl-rocky-9       $IMPORT/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
)

log() { echo "[$(date +%H:%M:%S)] $*"; }

# First-boot vendor-data: install the guest agent, clear the machine ID, power off.
# Only attached while building; removed before the VM becomes a template.
pvesm set local --content "$(pvesh get /storage/local --output-format json | python3 -c 'import sys,json; c=set(json.load(sys.stdin)["content"].split(",")); c.add("snippets"); print(",".join(sorted(c)))')"
mkdir -p /var/lib/vz/snippets
cat > /var/lib/vz/snippets/$SNIPPET <<'YAML'
#cloud-config
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent
runcmd:
  - systemctl enable qemu-guest-agent
  - truncate -s 0 /etc/machine-id
  - rm -f /var/lib/dbus/machine-id
power_state:
  mode: poweroff
  timeout: 120
  condition: true
YAML

pct exec $RUNNER_CT -- cat /home/runner/.ssh/id_ed25519.pub > /root/ci-runner.pub

build() {
  local id=$1 name=$2 img=$3
  if qm status "$id" >/dev/null 2>&1; then log "$id $name: VMID exists, skipping"; return; fi
  [ -f "$img" ] || { log "$id $name: image not found: $img"; return 1; }
  log "$id $name: creating from $(basename "$img")"
  qm create "$id" --name "$name" --pool $POOL --ostype l26 --machine q35 --cpu host \
    --cores 4 --memory 8192 --balloon 0 --scsihw virtio-scsi-single \
    --net0 virtio,bridge=$BRIDGE --agent enabled=1 --serial0 socket --vga serial0 \
    --description "Template for install.wiscovitch.org VM tests (proxmox/build-templates.sh)"
  qm set "$id" --scsi0 "$STORAGE:0,import-from=$img,discard=on,ssd=1" >/dev/null
  qm disk resize "$id" scsi0 $DISK_SIZE >/dev/null
  qm set "$id" --ide2 $STORAGE:cloudinit --boot order=scsi0 \
    --ciuser tech --sshkeys /root/ci-runner.pub --ipconfig0 ip=dhcp --ciupgrade 0 \
    --cicustom "vendor=local:snippets/$SNIPPET" >/dev/null
  log "$id $name: first boot (installs guest agent, then powers off)"
  qm start "$id"
  for _ in $(seq 1 90); do
    [ "$(qm status "$id" | awk '{print $2}')" = stopped ] && break
    sleep 10
  done
  if [ "$(qm status "$id" | awk '{print $2}')" != stopped ]; then
    log "$id $name: did not power off within 15 minutes; left running for inspection"; return 1
  fi
  qm set "$id" --delete cicustom >/dev/null
  qm template "$id"
  log "$id $name: template ready"
}

want=("$@")
for t in "${TEMPLATES[@]}"; do
  read -r id name img <<<"$t"
  if [ ${#want[@]} -eq 0 ] || [[ " ${want[*]} " == *" $id "* ]]; then
    build "$id" "$name" "$img" || log "$id $name: FAILED"
  fi
done
rm -f /root/ci-runner.pub
