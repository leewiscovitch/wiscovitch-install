{%- assign pm = site.data.pm[page.pm] -%}
Set git identity (replace the placeholders):

```{{ pm.lang }}
git config --global user.name "<NAME>"
git config --global user.email "<EMAIL>"
git config --global init.defaultBranch main
```
