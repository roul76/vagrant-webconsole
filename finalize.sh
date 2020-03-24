#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

localdir="/vagrant/include"
# shellcheck source=include/_include.sh
. "${localdir}/_include.sh"

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
  local bridge_subnet; bridge_subnet="$(_retrieveBridgeSubnet)"

  echo "- Configure iptables"
  netdevice=$(route|awk '$1~/^default$/{print($8)}')
  netmask=$(ip route|awk '$3~/^'"${netdevice}"'$/{print($1)}')

# SYN flood protection
  iptables -N SYN_FLOOD
  iptables -A SYN_FLOOD -m limit --limit 5/s --limit-burst 10 -j RETURN
  iptables -A SYN_FLOOD -j DROP

# Allow traffic once a connection has been made
  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Limit incoming traffic to port 3000 and 3001
  iptables -A INPUT -m tcp -p tcp --dport "${WEBCONSOLE_WETTY_PORT}" -m state --state NEW -j ACCEPT
  iptables -A INPUT -m tcp -p tcp --dport "${WEBCONSOLE_NODESTATIC_PORT}" -m state --state NEW -j ACCEPT

  iptables -A INPUT -p tcp --syn -j SYN_FLOOD
  iptables -A INPUT -s "${netmask}" -j ACCEPT
  iptables -P INPUT DROP

  iptables -A OUTPUT -p tcp --sport "${WEBCONSOLE_WETTY_PORT}" -m state --state ESTABLISHED -j ACCEPT
  iptables -A OUTPUT -p tcp --sport "${WEBCONSOLE_NODESTATIC_PORT}" -m state --state ESTABLISHED -j ACCEPT

  iptables -A OUTPUT -d "${bridge_subnet}" -j ACCEPT
  iptables -A OUTPUT -d "${netmask}" -j ACCEPT

# Drop everything else
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
