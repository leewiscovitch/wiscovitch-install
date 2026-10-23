{%- comment -%}
Second Remove-apps pass for the end of setup: every app from the page's `remove:` groups
in one block (OneDrive has its own uninstaller and is left to its block).
{%- endcomment -%}
Remove apps that came back during setup. Windows finishes some apps in the background after the first sign-in (a fresh install's Teams placeholder turns into the full app), and updates can reinstall others, so this repeats the **Remove apps** step for the whole list:

```powershell
$apps = @(
{% for g in page.remove %}{% for a in g.apps %}{% unless a.id == 'Microsoft.OneDrive' %}    '{{ a.id }}'  # {{ a.name }}
{% endunless %}{% endfor %}{% endfor %})
Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $apps -and $_.InstallLocation -and (Test-Path $_.InstallLocation) } | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -in $apps | Remove-AppxProvisionedPackage -Online | Out-Null
```
