Remove built-in apps with PowerShell's app cmdlets. For each group, the first line removes the apps for every user account, and the second removes their provisioned copies, so Windows doesn't reinstall them for new accounts. Apps that aren't installed are skipped, so any group is safe to re-run (feature updates sometimes bring apps back). Works in Terminal and over SSH.

{% for g in page.remove -%}
{%- assign appx = g.apps | where_exp: "a", "a.id != 'Microsoft.OneDrive'" -%}
**{{ g.group }}:**

```powershell
$apps = @(
{% for a in appx %}    '{{ a.id }}'  # {{ a.name }}
{% endfor %})
Get-AppxPackage -AllUsers | Where-Object Name -in $apps | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -in $apps | Remove-AppxProvisionedPackage -Online | Out-Null
```
{% for a in g.apps %}{% if a.id == 'Microsoft.OneDrive' %}
OneDrive is a regular desktop program, not a Store app, so it has its own uninstaller:

```powershell
Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
$u = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe' -ErrorAction SilentlyContinue).UninstallString
if ($u -match '^"([^"]+)"\s*(.*)$') { Start-Process -FilePath $Matches[1] -ArgumentList $Matches[2] -Wait }
```
{% endif %}{% endfor %}
{% endfor -%}
To find other apps, list the ones installed for you:

```powershell
Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -eq 'Store' } | Sort-Object Name | Format-Table Name, Version
```

Then remove one by putting its name in the `$apps` list of a block above, e.g. `'Microsoft.Paint'`.
