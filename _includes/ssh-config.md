SSH client config for `{{ site.user }}` (run as `{{ site.user }}`, not root). Accepts new host keys automatically and doesn't save them:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
tee -a ~/.ssh/config > /dev/null << 'EOF'
Host *
    StrictHostKeyChecking=accept-new
    UserKnownHostsFile=/dev/null
EOF
chmod 600 ~/.ssh/config
```
