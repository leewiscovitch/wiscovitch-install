{%- assign pm = site.data.pm[page.pm] -%}
{%- if pm.lang == 'powershell' -%}{%- assign sep = '' -%}{%- else -%}{%- assign sep = ' &&\' -%}{%- endif -%}
{{ pm.update_label | default: "Update everything:" }}

```{{ pm.lang }}
{% for cmd in pm.update %}{{ cmd }}{% unless forloop.last %}{{ sep }}
{% endunless %}{% endfor %}
```
{% if page.pm == "apt" %}
```output
Hit:1 http://security.ubuntu.com/ubuntu resolute-security InRelease
Hit:2 http://archive.ubuntu.com/ubuntu resolute InRelease
Hit:3 http://archive.ubuntu.com/ubuntu resolute-updates InRelease
Hit:4 http://archive.ubuntu.com/ubuntu resolute-backports InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
<n> packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
Summary:
  Upgrading: <n>, Installing: <n>, Removing: <n>, Not Upgrading: <n>
  Download size: <size>
Get:1 http://archive.ubuntu.com/ubuntu resolute-updates/main amd64 <package> amd64 <version> [<size>]
…
Setting up <package> (<version>) ...
Processing triggers for man-db (<version>) ...
```

"Not Upgrading" above 0 is normal right after a release: Ubuntu rolls some updates out gradually (phased updates) and `apt`{:.cmd} holds them back until it's this machine's turn.
{% endif %}
