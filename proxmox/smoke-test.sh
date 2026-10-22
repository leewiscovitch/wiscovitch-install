#!/usr/bin/env bash
# Check that a template works: clone it, boot, SSH in as tech, reboot, destroy.
# Run on the runner (CT 9050) as the runner user, next to vm.sh.
#
# Usage: smoke-test.sh TEMPLATE_ID [TEMPLATE_ID ...]
set -u
cd "$(dirname "$0")"

S() { ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
         -o ConnectTimeout=5 -o LogLevel=ERROR "tech@$1" "$2"; }
wait_ssh() { for _ in $(seq 1 36); do S "$1" true && return 0; sleep 5; done; return 1; }

rc=0
for tpl in "$@"; do
  t0=$(date +%s)
  echo "=== template $tpl"
  id=$(./vm.sh clone "$tpl" "smoke-$tpl") || { echo "FAIL clone"; rc=1; continue; }
  if ./vm.sh start "$id" && ip=$(./vm.sh ip "$id" 300) && wait_ssh "$ip"; then
    S "$ip" 'echo "os: $(. /etc/os-release; echo $PRETTY_NAME)"
             echo "machine-id: $(cat /etc/machine-id)"
             echo "guest agent: $(systemctl is-active qemu-guest-agent)"
             echo "sudo -n: $(sudo -n true 2>/dev/null && echo works || echo FAILS)"
             echo "site: HTTP $(curl -fsS -o /dev/null -w %{http_code} https://install.wiscovitch.org/)"'
    ./vm.sh reboot "$id"; sleep 15
    if ip2=$(./vm.sh ip "$id" 300) && wait_ssh "$ip2"; then
      echo "reboot: OK"
      echo "PASS $tpl ($(( $(date +%s) - t0 ))s)"
    else
      echo "FAIL $tpl: did not come back after reboot"; rc=1
    fi
  else
    echo "FAIL $tpl: no IP or SSH"; rc=1
  fi
  ./vm.sh destroy "$id" >/dev/null || { echo "WARN could not destroy $id"; rc=1; }
done
exit $rc
