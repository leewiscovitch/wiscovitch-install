{%- assign pm = site.data.pm[page.pm] -%}
Confirm OS version:

{% if pm.lang == "powershell" -%}
```powershell
Get-ComputerInfo -Property OsName, OsDisplayVersion, OsBuildNumber{% if page.os_version %}   # {{ page.os_version }}{% endif %}
```
{%- else -%}
```bash
cat /etc/os-release{% if page.os_version %}   # PRETTY_NAME: {{ page.os_version }}{% endif %}
```
{%- endif %}
