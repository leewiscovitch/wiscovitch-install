{%- comment -%}
Lines (no fences) that install a pinned PowerShell Gallery module for all users, for use
inside a powershell block, with name="PSWindowsUpdate" (any key of ps_modules).
Version and checksum come from `ps_modules` in _config.yml.
{%- endcomment -%}
{%- assign m = site.ps_modules[include.name] -%}
$zip = "$env:TEMP\{{ include.name }}.{{ m.version }}.zip"
Invoke-WebRequest 'https://www.powershellgallery.com/api/v2/package/{{ include.name }}/{{ m.version }}' -OutFile $zip -UseBasicParsing
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne '{{ m.sha256 }}') { throw '{{ include.name }} checksum mismatch; not installing.' }
$dir = "$env:ProgramFiles\WindowsPowerShell\Modules\{{ include.name }}\{{ m.version }}"
Expand-Archive $zip -DestinationPath $dir -Force
Remove-Item -LiteralPath "$dir\_rels", "$dir\package", "$dir\[Content_Types].xml" -Recurse -Force -ErrorAction Ignore