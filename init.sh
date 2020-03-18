#!/bin/sh

WEBCONSOLE_HOSTNAME="webconsole"
WEBCONSOLE_SSHD_HOSTNAME="webconsole-sshd"

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 6 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: init.sh <webconsole-user> <webconsole-password> <ssh-user> <ssh-password> <accessible networks> <nameservers>">&2
    exit 1
  fi
}

_changeHostname() {
  echo "- Changing hostname to '${WEBCONSOLE_HOSTNAME}'"
  echo "${WEBCONSOLE_HOSTNAME}" > /etc/hostname
  hostname -F /etc/hostname
  sed -i 's/alpine310/'"${WEBCONSOLE_HOSTNAME}"'/g' /etc/hosts
}

_installNecessaryPackages() {
  echo "- Install necessary packages"
  apk add --no-cache jq \
    >/dev/null
}

_secureSSHD() {
  echo "- Securing sshd"
  sed -i '
    s/^[#]*PermitRootLogin.*$/PermitRootLogin no/;
    s/^[#]*PasswordAuthentication.*$/PasswordAuthentication no/ ;
    s/^[#]*LoginGraceTime.*/LoginGraceTime 120/ ;
    s/^[#]*StrictModes.*/StrictModes yes/ ;
    s/^[#]*PubkeyAuthentication.*/PubkeyAuthentication yes/
  ' /etc/ssh/sshd_config

  /etc/init.d/sshd restart >/dev/null
}

_iptables() {
  local netdevice
  local netmask

  echo "- Configuring iptables"
  netdevice=$(route|awk '$1~/^default$/{print($8)}')
  netmask=$(ip route|awk '$3~/^'"${netdevice}"'$/{print($1)}')
  iptables -A INPUT -s "${netmask}" -j ACCEPT
  iptables -A OUTPUT -d "${netmask}" -j ACCEPT
  iptables -P INPUT DROP
  iptables -P OUTPUT DROP
}

_retrieveBridgeSubnet() {
  docker network inspect bridge | jq --raw-output -e '.[0].IPAM.Config[0].Subnet'
}

_waitContainerReady() {
  local timeout
  local x
  local ctrname

  ctrname="$1"
  echo "- Waiting 180 s for container '${ctrname}' to become ready"
  # Wait 3 minutes for container to be running
  timeout=180
  x=""
  while [ ${timeout} -gt 0 -a "${x}" = "" ]; do
    x="$(docker ps --quiet --filter "name=${ctrname}" --filter "status=running")"
    sleep 1
    timeout=$(expr ${timeout} - 1)
  done

  if [ ${timeout} -le 0 ]; then
    echo "Container '${ctrname}' did not come up within 3 minutes.">&2
    exit 1
  fi
}

_startWebconsoleContainer() {
  local pwh
  local shell

  pwh=$(openssl passwd -1 "$2" 2>/dev/null)
  shell="/webconsole/${WEBCONSOLE_SSHD_HOSTNAME}.sh"
  echo "- Starting webconsole wetty-container"
  echo "  user:  '$1'"
  echo "  hash:  '${pwh}'"
  echo "  shell: '${shell}'"
  docker run \
    --restart always \
    --name "${WEBCONSOLE_HOSTNAME}" \
    --network host \
    --cap-add=NET_ADMIN \
    --hostname "${WEBCONSOLE_HOSTNAME}" \
    --mount type=bind,source=/vagrant/shared,target=/webconsole,readonly \
    -e WEBCONSOLE_BRIDGE_SUBNET="$(_retrieveBridgeSubnet)" \
    -e WEBCONSOLE_USER="$1" \
    -e WEBCONSOLE_HASH="${pwh}" \
    -e WEBCONSOLE_SHELL="${shell}" \
    -dt \
    roul76/wetty:latest >/dev/null 2>&1

  _waitContainerReady "${WEBCONSOLE_HOSTNAME}"
}

_startSSHDContainer() {
  local pwh

  pwh=$(openssl passwd -1 "$2" 2>/dev/null)
  echo "- Starting webconsole sshd-container"
  echo "  user: '$1'"
  echo "  hash: '${pwh}'"
  docker run \
    --restart always \
    --name "${WEBCONSOLE_SSHD_HOSTNAME}" \
    --network bridge \
    --cap-add=NET_ADMIN \
    --hostname "${WEBCONSOLE_SSHD_HOSTNAME}" \
    --mount type=bind,source=/vagrant/shared,target=/webconsole \
    -e SSH_SUBNET="$(_retrieveBridgeSubnet)" \
    -e SSH_USER="$1" \
    -e SSH_HASH="${pwh}" \
    -e SSH_ACCESSIBLE_NETWORKS="$3" \
    -e SSH_NAMESERVERS="$4" \
    -dt \
    roul76/sshd:latest >/dev/null 2>&1

  _waitContainerReady "${WEBCONSOLE_SSHD_HOSTNAME}"
}

_main() {
  echo "--- INITIALIZATION  ---"
  _checkParams "$@"
  _changeHostname
  _installNecessaryPackages
  _secureSSHD
  _startSSHDContainer "$3" "$4" "$5" "$6"
  _startWebconsoleContainer "$1" "$2"
  _iptables
  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
