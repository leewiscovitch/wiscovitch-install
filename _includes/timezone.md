{%- assign pm = site.data.pm[page.pm] -%}
{% if pm.lang == "powershell" -%}
Set the time zone to US Eastern:

```powershell
Set-TimeZone -Id "{{ site.timezone_windows }}"
```

Make sure the Windows time service runs at startup, then sync the clock now:

```powershell
Set-Service -Name w32time -StartupType Automatic
Start-Service w32time
w32tm /resync /force
```

Check the zone and the last sync:

```powershell
Get-TimeZone
w32tm /query /status
```
{%- else -%}
Set the time zone to US Eastern:

```bash
sudo timedatectl set-timezone {{ site.timezone }}
```

{% include no-output.md %}

Turn on network time sync. Turning it off and on again forces an immediate sync, whichever time service the distro uses:

```bash
sudo timedatectl set-ntp false &&\
sudo timedatectl set-ntp true
```

{% include no-output.md %}

Check the zone and sync status; look for `Time zone: {{ site.timezone }}`{:.val} and `System clock synchronized: yes`{:.val} (it can take a few seconds):

```bash
timedatectl
```

```output
               Local time: Mon 2026-10-26 11:24:35 EDT
           Universal time: Mon 2026-10-26 15:24:35 UTC
                 RTC time: Mon 2026-10-26 15:24:35
                Time zone: {{ site.timezone }} (EDT, -0400)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```
{%- endif %}
