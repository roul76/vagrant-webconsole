#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 0 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: $0">&2
    exit 1
  fi
}

_changeIPTables() {
  local netdevice
  local netmask

  echo "- Configure iptables"
  netdevice=$(route|awk '$1~/^default$/{print($8)}')
  netmask=$(ip route|awk '$3~/^'"${netdevice}"'$/{print($1)}')
  iptables -A INPUT -s "${netmask}" -j ACCEPT
  iptables -A OUTPUT -d "${netmask}" -j ACCEPT
  iptables -P INPUT DROP
  iptables -P OUTPUT DROP
}

_main() {
  echo "--- FINALIZATION ---"

  _checkParams "$@"
  _changeIPTables

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
