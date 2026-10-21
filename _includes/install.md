{%- assign pm = site.data.pm[page.pm] -%}
Install packages:

```{{ pm.lang }}
{% if pm.one_per_line %}{% for p in page.packages %}{{ pm.install }} {{ p }}
{% endfor %}{% else %}{{ pm.install }} {{ page.packages | join: " " }}
{% endif %}```
