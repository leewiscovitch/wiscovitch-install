{%- assign pm = site.data.pm[page.pm] -%}
{%- if pm.lang == 'powershell' -%}{%- assign sep = '' -%}{%- else -%}{%- assign sep = ' &&\' -%}{%- endif -%}
{{ pm.update_label | default: "Update everything:" }}

```{{ pm.lang }}
{% for cmd in pm.update %}{{ cmd }}{% unless forloop.last %}{{ sep }}
{% endunless %}{% endfor %}
```
