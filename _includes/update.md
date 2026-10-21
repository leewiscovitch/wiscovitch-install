{%- assign pm = site.data.pm[page.pm] -%}
Update everything:

```{{ pm.lang }}
{% for cmd in pm.update %}{{ cmd }}{% unless forloop.last %} &&\
{% endunless %}{% endfor %}
```
