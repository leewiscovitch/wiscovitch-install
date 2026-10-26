{%- assign pm = site.data.pm[page.pm] -%}
Set `git`{:.cmd} identity. It asks for your name and email, then sets them:

{% if pm.lang == "powershell" -%}
```powershell
& {
    # Pick up Git if it was installed earlier in this same window
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $name = Read-Host "Git name"
    $email = Read-Host "Git email"
    git config --global user.name $name
    git config --global user.email $email
    git config --global init.defaultBranch main
}
```
{%- else -%}
```bash
read -rp "Git name: " name &&\
read -rp "Git email: " email &&\
git config --global user.name "$name" &&\
git config --global user.email "$email" &&\
git config --global init.defaultBranch main
```
{%- endif %}

{% include no-output.md text="Asks for: Git name, Git email. Nothing else when it succeeds." %}
