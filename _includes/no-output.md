{%- comment -%}
Note under a command block whose command prints nothing (or nothing worth showing).
text= replaces the default wording, e.g. text="Asks for: Git name, Git email".
{%- endcomment -%}
<p class="no-output">{{ include.text | default: "Nothing when it succeeds." }}</p>
