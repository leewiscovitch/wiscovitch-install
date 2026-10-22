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
| AlmaLinux 10 | `AlmaLinux-10-GenericCloud-latest.x86_64.qcow2` | cloud-init template |
| Rocky Linux 9 | `Rocky-9-GenericCloud-Base.latest.x86_64.qcow2` | cloud-init template |
| CachyOS | `cachyos-desktop-linux-260809.iso` | one-time manual install |
| Windows 11 | multi-edition ISO from microsoft.com | unattended install |
| Runner | `debian-13-standard_13.6-1_amd64.tar.zst` (`pveam download local …`) | GitHub runner container |
| Windows drivers | `virtio-win.iso` (already on the host) | VirtIO disk/network drivers |

Sources:

- Fedora: <https://fedoraproject.org/releases.json> lists each image's URL and SHA-256.
- AlmaLinux: <https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/> (`CHECKSUM` file).
- Rocky Linux: <https://dl.rockylinux.org/pub/rocky/9/images/x86_64/> (`<image>.CHECKSUM`). Rocky 10 images are in `…/rocky/10/…`.
- CachyOS: <https://cachyos.org/download/> (`<iso>.sha256` next to each ISO).

Download and verify one by hand, e.g. Fedora Cloud:

```bash
cd /var/lib/vz/import
curl -fLO https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
echo "28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f  Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2" | sha256sum -c
```
