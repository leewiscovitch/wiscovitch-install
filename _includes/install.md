{%- assign pm = site.data.pm[page.pm] -%}
Install packages (list is `packages:` in this page's front matter):

```{{ pm.lang }}
{% if pm.one_per_line %}{% for p in page.packages %}{{ pm.install }} {{ p }}
{% endfor %}{% else %}{{ pm.install }} {{ page.packages | join: " " }}
{% endif %}```
