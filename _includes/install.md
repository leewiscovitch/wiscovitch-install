{%- assign pm = site.data.pm[page.pm] -%}
Install packages:

```{{ pm.lang }}
{% if pm.one_per_line %}{% for p in page.packages %}{{ pm.install }} {{ p }}
{% endfor %}{% else %}{{ pm.install }} {{ page.packages | join: " " }}
{% endif %}```
{% if page.pm == "apt" %}
```output
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Installing:
  {{ page.packages | join: "  " }}

Summary:
  Upgrading: 0, Installing: <n>, Removing: 0, Not Upgrading: <n>
  Download size: <size>
…
Setting up {{ page.packages | last }} (<version>) ...
Processing triggers for man-db (<version>) ...
```

On a machine that already has them, each package reports `is already the newest version`{:.val} instead.
{% endif %}
