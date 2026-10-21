{%- assign pm = site.data.pm[page.pm] -%}
Confirm OS version:

{% if pm.lang == "powershell" -%}
```powershell
Get-ComputerInfo -Property OsName, OsDisplayVersion, OsBuildNumber
```
{%- else -%}
```bash
cat /etc/os-release
```
{%- endif %}
