# Proxmox VM tests

Runs the install pages on real VMs in the homelab: fresh Windows 11 and Linux
installs with real systemd, reboots and desktop sessions. It complements the
GitHub-hosted container tests (`.github/workflows/test.yml`), which run on every
push but can't reboot or start services.

```
GitHub ──(job queue)── ◄── outbound HTTPS ──  runner agent (LXC on Proxmox)
                                                  │  Proxmox API: clone, start, destroy
                                                  ▼
                                             test VM (fresh Win 11 / Ubuntu / Fedora / …)
                                                  ▲
                                                  └── SSH as the user: run blocks, reboot, verify
```

- The runner only makes **outbound** connections to GitHub. No ports are opened.
- The VM job runs only on **pushes by `leewiscovitch`** and manual runs. It has no
  `pull_request` trigger, so pull requests from others can never run code on this hardware.
- Test VMs sit on the main LAN (`vmbr0`) for now; move them to a VLAN later.
- Up to 3 test VMs at a time.

Every step below is written so it can be run by hand. Host-specific values
(addresses, node and storage names, token IDs) go in `proxmox/config.env`, which
is gitignored; `proxmox/config.example.env` shows the keys.

## 1. Access from the admin PC

Used while building and maintaining this setup, not by the tests.

1. Make a dedicated key on the admin PC, so it can be removed without touching other keys:

   ```bash
   ssh-keygen -t ed25519 -N "" -C "proxmox-admin@$(uname -n)" -f ~/.ssh/proxmox-ci
   ```

2. Add the public key (`~/.ssh/proxmox-ci.pub`) to the Proxmox host, in the Proxmox shell:

   ```bash
   echo '<PUBLIC KEY>' >> /root/.ssh/authorized_keys
   ```

3. Check it from the admin PC:

   ```bash
   ssh -i ~/.ssh/proxmox-ci root@<PROXMOX HOST> 'pveversion'
   ```

To revoke later, delete that line from `/root/.ssh/authorized_keys` on the host.

## 2. Images

Downloaded on the Proxmox host from each project's own server and checked
against its published SHA-256. Cloud images go to `/var/lib/vz/import`
(`local` storage, "import" content); ISOs to `/var/lib/vz/template/iso`.

| OS | Image | Used for |
|---|---|---|
| Ubuntu 26.04 Server | `resolute-server-cloudimg-amd64.img` (already on the host) | cloud-init template |
| Ubuntu 26.04 Desktop | `ubuntu-26.04-desktop-amd64.iso` (already on the host) | one-time manual install |
| Fedora 44 | `Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2` | cloud-init template |
| Fedora 44 Workstation | `Fedora-Workstation-Live-44-1.7.x86_64.iso` | one-time manual install |
| AlmaLinux 9 | `AlmaLinux-9-GenericCloud-latest.x86_64.qcow2` | cloud-init template |
| AlmaLinux 10 | `AlmaLinux-10-GenericCloud-latest.x86_64.qcow2` | cloud-init template |
| Rocky Linux 9 | `Rocky-9-GenericCloud-Base.latest.x86_64.qcow2` | cloud-init template |
| Rocky Linux 10 | `Rocky-10-GenericCloud-Base.latest.x86_64.qcow2` | cloud-init template |
| CachyOS | `cachyos-desktop-linux-260809.iso` | one-time manual install |
| Windows 11 | multi-edition ISO from microsoft.com | unattended install |
| Runner | `debian-13-standard_13.6-1_amd64.tar.zst` (`pveam download local …`) | GitHub runner container |
| Windows drivers | `virtio-win.iso` (already on the host) | VirtIO disk/network drivers |

Sources:

- Fedora: <https://fedoraproject.org/releases.json> lists each image's URL and SHA-256.
- AlmaLinux: <https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/> and `…/10/…` (`CHECKSUM` file).
- Rocky Linux: <https://dl.rockylinux.org/pub/rocky/9/images/x86_64/> and `…/rocky/10/…` (`<image>.CHECKSUM`).
- CachyOS: <https://cachyos.org/download/> (`<iso>.sha256` next to each ISO).

Download and verify one by hand, e.g. Fedora Cloud:

```bash
cd /var/lib/vz/import
curl -fLO https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
echo "28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f  Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2" | sha256sum -c
```

## 3. Pool, CI user and API token

Everything for the tests lives in pool `ci`. The runner talks to Proxmox as
`ci@pve` with an API token that can only reach that pool, `local-lvm` storage
and the `vmbr0` bridge; it can't see any other guest on the host.

On the Proxmox host:

```bash
pveum pool add ci --comment "install.wiscovitch.org CI: templates, test VMs, runner"
pveum user add ci@pve --comment "GitHub Actions runner for install.wiscovitch.org tests"
pveum acl modify /pool/ci --users ci@pve --roles PVEVMAdmin,PVEPoolUser
pveum acl modify /storage/local-lvm --users ci@pve --roles PVEDatastoreUser
pveum acl modify /sdn/zones/localnetwork/vmbr0 --users ci@pve --roles PVESDNUser
```

Create the token. `--privsep 0` gives it the user's (limited) permissions. The
secret is shown only once, so write it straight to a root-only file:

```bash
umask 077
pveum user token add ci@pve runner --privsep 0 --output-format json \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["full-tokenid"] + "=" + d["value"])' > /root/ci-runner-token
```

Check what it can see:

```bash
pveum user permissions ci@pve
```

Expected: only `/pool/ci`, `/sdn/zones/localnetwork/vmbr0` and `/storage/local-lvm`.

## 4. Runner container

CT 9050 `gh-runner`: Debian 13, unprivileged, 2 vCPU, 2 GB RAM, 16 GB disk, DHCP on
`vmbr0`, starts on boot. It holds the API token and the SSH key the tests use to
log in to test VMs.

On the Proxmox host:

```bash
pct create 9050 local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst \
  --hostname gh-runner --pool ci --unprivileged 1 --features nesting=1 \
  --cores 2 --memory 2048 --swap 512 --rootfs local-lvm:16 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --onboot 1 --timezone America/New_York
pct start 9050
pct exec 9050 -- bash -c 'apt-get update && apt-get install -y curl ca-certificates jq git python3 openssh-client sudo'
```

A `runner` user with its own SSH key (its public key goes into every test template):

```bash
pct exec 9050 -- bash -c 'useradd -m -s /bin/bash runner && sudo -u runner ssh-keygen -t ed25519 -N "" -C "gh-runner@ci" -f /home/runner/.ssh/id_ed25519 && install -d -m 700 -o runner -g runner /home/runner/.config/ci'
pct exec 9050 -- cat /home/runner/.ssh/id_ed25519.pub
```

Move the API token into the container, then remove the host copy:

```bash
pct push 9050 /root/ci-runner-token /home/runner/.config/ci/pve-token --perms 0600
pct exec 9050 -- chown runner:runner /home/runner/.config/ci/pve-token
shred -u /root/ci-runner-token
```

Install the GitHub runner agent. Find the version and its SHA-256 on
<https://github.com/actions/runner/releases/latest> (the release notes list a
checksum per platform; use `linux-x64`):

```bash
pct exec 9050 -- bash -c '
  cd /home/runner && mkdir -p actions-runner && cd actions-runner
  curl -fsSL -o /tmp/runner.tgz https://github.com/actions/runner/releases/download/v<VERSION>/actions-runner-linux-x64-<VERSION>.tar.gz
  echo "<SHA256>  /tmp/runner.tgz" | sha256sum -c
  tar xzf /tmp/runner.tgz && rm /tmp/runner.tgz
  chown -R runner:runner /home/runner/actions-runner
  ./bin/installdependencies.sh'
```

Register it with the repo. The registration token comes from the repo's
**Settings → Actions → Runners → New self-hosted runner** page (or
`gh api -X POST repos/leewiscovitch/wiscovitch-install/actions/runners/registration-token --jq .token`)
and expires after an hour:

```bash
pct exec 9050 -- sudo -u runner bash -c 'cd ~/actions-runner && ./config.sh --unattended --replace \
  --url https://github.com/leewiscovitch/wiscovitch-install --token <REGISTRATION TOKEN> \
  --name wiscotrash-ci --labels proxmox --work _work'
pct exec 9050 -- bash -c 'cd /home/runner/actions-runner && ./svc.sh install runner && ./svc.sh start'
```

The runner then shows as **Idle** under Settings → Actions → Runners. Only
workflow jobs with `runs-on: [self-hosted, proxmox]` go to it.

To remove it: `./svc.sh stop && ./svc.sh uninstall` and `./config.sh remove --token <REMOVAL TOKEN>`
in the container, then `pct destroy 9050`.

## 5. Cloud-image templates

| VMID | Name | Image |
|---|---|---|
| 9000 | `tpl-ubuntu-2604` | Ubuntu 26.04 Server cloud image |
| 9001 | `tpl-fedora-44` | Fedora 44 Cloud Base |
| 9002 | `tpl-alma-9` | AlmaLinux 9 GenericCloud |
| 9003 | `tpl-alma-10-v2` | AlmaLinux 10 GenericCloud, **x86_64_v2** build |
| 9004 | `tpl-rocky-9` | Rocky Linux 9 GenericCloud |

**CPU note:** this host's Xeon E5-2697 v2 (Ivy Bridge) supports x86-64-v2 but
not v3 (no AVX2). The RHEL 10 family requires v3, so the standard AlmaLinux 10
and Rocky Linux 10 images can't boot here. AlmaLinux publishes an x86_64_v2
build, used above; Rocky 10 has none, so it's only tested in the GitHub
container job (GitHub's CPUs support v3). On a newer host, use the standard
images.

Each template is the distro's cloud image as the disk (resized to 20 GB), with
cloud-init creating user `tech` (passwordless sudo) and the runner's SSH key.
On a first boot it installs the QEMU guest agent, so the runner can read a
clone's IP, then clears `/etc/machine-id`, so clones running side by side get
distinct DHCP leases, and powers off. The first-boot script is removed before
the VM is converted to a template.

[`build-templates.sh`](build-templates.sh) does all of this. Copy it to the host
and run it as root; with no arguments it builds every template, or pass VMIDs.
It never overwrites an existing VMID; `qm destroy <VMID>` first to rebuild.

```bash
scp proxmox/build-templates.sh root@<PROXMOX HOST>:/root/
ssh root@<PROXMOX HOST> /root/build-templates.sh
```

It also enables the `snippets` content type on `local` storage, where the
first-boot cloud-init file (`ci-template-firstboot.yaml`) lives.

The same steps by hand, for one template:

```bash
qm create 9002 --name tpl-alma-9 --pool ci --ostype l26 --machine q35 --cpu host \
  --cores 4 --memory 8192 --balloon 0 --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 --agent enabled=1 --serial0 socket --vga serial0
qm set 9002 --scsi0 local-lvm:0,import-from=/var/lib/vz/import/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2,discard=on,ssd=1
qm disk resize 9002 scsi0 20G
qm set 9002 --ide2 local-lvm:cloudinit --boot order=scsi0 --ciuser tech \
  --sshkeys /root/ci-runner.pub --ipconfig0 ip=dhcp --ciupgrade 0 \
  --cicustom vendor=local:snippets/ci-template-firstboot.yaml
qm start 9002          # wait until `qm status 9002` says stopped
qm set 9002 --delete cicustom
qm template 9002
```

### Checking a template

[`vm.sh`](vm.sh) manages test VMs through the API with the runner's limited
token (clone, start, IP, reboot, destroy). [`smoke-test.sh`](smoke-test.sh)
uses it to clone each template, boot it, SSH in as `tech`, reboot, and destroy
it. Both live in `/home/runner` on the runner:

```bash
pct exec 9050 -- sudo -u runner /home/runner/smoke-test.sh 9000 9001 9002 9003 9004
```

A clone takes about 2 s, boots to SSH in about 25 s, and a full check with a
reboot takes under a minute.
