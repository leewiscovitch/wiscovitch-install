{%- assign pm = site.data.pm[page.pm] -%}
Set git identity. It asks for your name and email, then sets them:

{% if pm.lang == "powershell" -%}
```powershell
& {
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
