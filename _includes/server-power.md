{%- comment -%}
Linux "server use" steps, shared by the OS pages. part= picks one piece:
  lid    keep running with the lid closed (systemd-logind; same on every distro)
  wifi   NetworkManager Wi-Fi power saving off
  check  check block; wifi=true adds the NetworkManager line, idle="gnome" adds GNOME dconf lines
  bios   firmware tips for a laptop on permanent AC
{%- endcomment -%}
{%- if include.part == "lid" -%}
Closing the lid does nothing, whether on battery, on AC or docked (this also covers rebooting with the lid closed):

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/50-server-lid.conf > /dev/null << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
sudo systemctl reload systemd-logind
```
{%- elsif include.part == "wifi" -%}
Wi-Fi power saving off (it delays replies and can drop idle connections). NetworkManager reads its config files in alphabetical order and the last setting wins, so the file name has to sort after any distro default (Ubuntu ships `default-wifi-powersave-on.conf`). It applies from the next reboot:

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF
```

Wi-Fi reconnects at boot without anyone signing in only if its saved password is available to all users (the default for networks added in the desktop's settings or with `nmcli`). With both Ethernet and Wi-Fi connected, NetworkManager prefers Ethernet and keeps Wi-Fi as a fallback.
{%- elsif include.part == "check" -%}
Check (after a reboot):

```bash
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch HandleLidSwitchExternalPower   # s "ignore" (twice)
{% if include.idle == "gnome" %}dconf read /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type   # 'nothing'
dconf read /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout   # 1800
{% endif %}{% if include.wifi %}NetworkManager --print-config | grep '^wifi.powersave'   # wifi.powersave=2
{% endif %}```
{%- elsif include.part == "bios" -%}
In the firmware setup (F10 at power-on on HP laptops), consider capping battery charging, which greatly extends battery life on permanent AC (HP: **Battery Health Manager → Maximize my battery health**), and turning on power-on when AC power returns after an outage, if the model offers it.
{%- endif -%}
