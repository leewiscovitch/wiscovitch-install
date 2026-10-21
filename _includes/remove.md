Uninstall built-in apps with winget. Copy the groups you want; a line for an app that isn't installed just reports "No installed package found" and moves on. Feature updates sometimes bring apps back, so this can be re-run.

{% for g in page.remove -%}
**{{ g.group }}:**

```powershell
{% for a in g.apps %}winget uninstall --id {{ a.id }} --silent --accept-source-agreements  # {{ a.name }}
{% endfor %}```

{% endfor -%}
To find other apps, list what's installed and uninstall by the name before the version number in the ID column (e.g. `Microsoft.Paint` from `MSIX\Microsoft.Paint_11.2605.81.0_x64__8wekyb3d8bbwe`):

```powershell
winget list
winget uninstall --id <NAME> --silent --accept-source-agreements
```
