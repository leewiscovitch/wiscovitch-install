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
