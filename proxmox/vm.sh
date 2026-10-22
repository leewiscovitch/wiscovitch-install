#!/usr/bin/env bash
# Manage disposable test VMs through the Proxmox API. Runs on the runner (CT 9050)
# with the ci@pve token, so it can only touch the `ci` pool.
#
# Usage:
#   vm.sh clone TEMPLATE_ID NAME   -> prints the new VMID (linked clone in 9100-9199)
#   vm.sh start VMID
#   vm.sh ip VMID [TIMEOUT_S]      -> waits for the guest agent, prints the first LAN IPv4
#   vm.sh reboot VMID
#   vm.sh destroy VMID             -> stops and deletes the VM and its disks
#   vm.sh list                     -> "VMID NAME STATUS" for test VMs (not templates) in the pool
#
# Settings: PVE_HOST (default 192.168.1.11), PVE_NODE (default wiscotrash),
# PVE_TOKEN_FILE (default ~/.config/ci/pve-token, containing TOKENID=SECRET).
set -euo pipefail

PVE_HOST=${PVE_HOST:-192.168.1.11}
PVE_NODE=${PVE_NODE:-wiscotrash}
PVE_TOKEN_FILE=${PVE_TOKEN_FILE:-$HOME/.config/ci/pve-token}
API="https://$PVE_HOST:8006/api2/json"
AUTH="Authorization: PVEAPIToken=$(cat "$PVE_TOKEN_FILE")"

api() {   # api METHOD PATH [curl args...]  -> prints .data
  local method=$1 path=$2; shift 2
  local out
  out=$(curl -sk -X "$method" -H "$AUTH" "$API$path" "$@" -w '\n%{http_code}')
  local code=${out##*$'\n'} body=${out%$'\n'*}
  if [[ $code != 2* ]]; then echo "API $method $path -> HTTP $code: $body" >&2; return 1; fi
  jq -r '.data // empty' <<<"$body"
}

wait_task() {   # wait_task UPID
  local upid=$1 status
  for _ in $(seq 1 300); do
    status=$(api GET "/nodes/$PVE_NODE/tasks/$(jq -rn --arg u "$upid" '$u|@uri')/status")
    if [ "$(jq -r .status <<<"$status")" = stopped ]; then
      [ "$(jq -r .exitstatus <<<"$status")" = OK ] && return 0
      echo "task failed: $(jq -r .exitstatus <<<"$status")" >&2; return 1
    fi
    sleep 2
  done
  echo "task timed out: $upid" >&2; return 1
}

cmd=${1:-}; shift || true
case $cmd in
  clone)
    tpl=$1 name=$2
    # Parallel jobs can pick the same free VMID; the loser's clone task fails,
    # so try the next one. A random start makes collisions rare.
    start=$((RANDOM % 100))
    for n in $(seq 0 99); do
      id=$((9100 + (start + n) % 100))
      upid=$(api POST "/nodes/$PVE_NODE/qemu/$tpl/clone" -d newid=$id -d "name=$name" -d pool=ci -d full=0 2>/dev/null) || continue
      if wait_task "$upid" 2>/dev/null; then echo "$id"; exit 0; fi
    done
    echo "no free VMID in 9100-9199" >&2; exit 1 ;;
  start)
    wait_task "$(api POST "/nodes/$PVE_NODE/qemu/$1/status/start")" ;;
  reboot)
    wait_task "$(api POST "/nodes/$PVE_NODE/qemu/$1/status/reboot")" ;;
  ip)
    id=$1 timeout=${2:-300}
    for _ in $(seq 1 $((timeout / 5))); do
      ip=$(api GET "/nodes/$PVE_NODE/qemu/$id/agent/network-get-interfaces" 2>/dev/null \
        | jq -r '.result[]? | ."ip-addresses"[]? | select(."ip-address-type" == "ipv4") | ."ip-address"' \
        | grep -vE '^(127|169\.254)\.' | head -1) || true   # skip loopback (Windows doesn't call it "lo") and link-local
      [ -n "${ip:-}" ] && { echo "$ip"; exit 0; }
      sleep 5
    done
    echo "no IP from guest agent after ${timeout}s" >&2; exit 1 ;;
  destroy)
    id=$1
    api POST "/nodes/$PVE_NODE/qemu/$id/status/stop" >/dev/null 2>&1 && sleep 3 || true
    wait_task "$(api DELETE "/nodes/$PVE_NODE/qemu/$id?purge=1&destroy-unreferenced-disks=1")" ;;
  list)
    api GET "/pools/ci" | jq -r '.members[] | select(.type == "qemu" and .template != 1) | "\(.vmid) \(.name) \(.status)"' ;;
  *)
    sed -n '2,13p' "$0"; exit 2 ;;
esac
