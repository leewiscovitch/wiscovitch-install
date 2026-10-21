{%- assign pm = site.data.pm[page.pm] -%}
{% if pm.lang == "powershell" -%}
SSH client config for `{{ site.user }}`. Accepts new host keys automatically and doesn't save them (Windows uses `NUL` where Linux uses `/dev/null`):

```powershell
New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
Add-Content -Path "$HOME\.ssh\config" -Value @"
Host *
    StrictHostKeyChecking=accept-new
    UserKnownHostsFile=NUL
"@
```
{%- else -%}
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
{%- endif %}
