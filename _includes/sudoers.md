Let `{{ site.user }}`{:.user} use `sudo`{:.cmd} without a password. The last two lines set the permissions `sudo`{:.cmd} expects and check the file's syntax, since a broken `sudoers`{:.path} file locks you out of `sudo`{:.cmd}:

```bash
sudo tee /etc/sudoers.d/{{ site.user }} > /dev/null << 'EOF'
{{ site.user }} ALL=(ALL) NOPASSWD: ALL
EOF
sudo chmod 0440 /etc/sudoers.d/{{ site.user }}
sudo visudo -cf /etc/sudoers.d/{{ site.user }}
```
