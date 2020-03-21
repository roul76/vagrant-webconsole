#!/bin/sh

set -o pipefail

WEBCONSOLE_HOSTNAME="webconsole"
WEBCONSOLE_SSHD_HOSTNAME="webconsole-sshd"
SSH_USER_ID=10001

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 7 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: init.sh <webconsole-user> <webconsole-password-hash-b64> <ssh-user> <ssh-password-hash-b64> <ssh-passphrase-b64> <accessible networks> <nameservers>">&2
    exit 1
  fi
}

_changeHostname() {
  echo "- Change hostname to '${WEBCONSOLE_HOSTNAME}'"
  echo "${WEBCONSOLE_HOSTNAME}" > /etc/hostname
  hostname -F /etc/hostname
  sed -i 's/alpine310/'"${WEBCONSOLE_HOSTNAME}"'/g' /etc/hosts
}

_installNecessaryPackages() {
  echo "- Install necessary packages"
  apk add --no-cache jq go curl wget\
    >/dev/null
}

_downloadImageDowloader() {
  echo "- Download image downloader"
  wget https://github.com/moby/moby/blob/master/contrib/download-frozen-image-v2.sh && \
  chmod 750 ./download-frozen-image-v2.sh
}

_downloadImage() {
  echo "- Download image $1"
  local dir=$(mktemp -d)
  ./download-frozen-image-v2.sh "${dir}" "$1" && \
  tar -cC "${dir}" . | docker load && \
  rm -rf "${dir}"
}

_secureSSHD() {
  echo "- Secure sshd"
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

  echo "- Configure iptables"
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
  echo "- Wait 180 s for container '${ctrname}' to become ready"
  # Wait 3 minutes for container to be running
  timeout=180
  x=""
  while [ ${timeout} -gt 0 -a "${x}" = "" ]; do
    x="$(docker ps --quiet --filter "name=^/${ctrname}$" --filter "status=running")"
    sleep 1
    timeout=$(expr ${timeout} - 1)
  done

  if [ ${timeout} -le 0 ]; then
    echo "Container '${ctrname}' did not come up within 3 minutes.">&2
    exit 1
  fi
}

_startWebconsoleContainer() {
  local image_name="$1"
  shift

  local pwh="$(echo "$2"|base64 -d)"
  local shell="/webconsole/${WEBCONSOLE_SSHD_HOSTNAME}.sh"

  echo "- Start webconsole wetty-container"
  echo "  user:  '$1'"
  echo "  hash:  '${pwh}'"
  echo "  shell: '${shell}'"

  _downloadImage "${image_name}" && \
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
    "${image_name}" >/dev/null 2>&1 && \
  _waitContainerReady "${WEBCONSOLE_HOSTNAME}"
}

_createSSHKeys() {
  echo "- Create ssh keys"
  mkdir /sshkeys /sshkeys.pub
  ssh-keygen -q \
    -N "$(echo "$2"|base64 -d)" \
    -t rsa \
    -b 4096 \
    -C "/sshkeys/$1@${WEBCONSOLE_SSHD_HOSTNAME}" \
    -f "/sshkeys/$1@${WEBCONSOLE_SSHD_HOSTNAME}.key"
  mv /sshkeys/*.pub /sshkeys.pub/
  chgrp -R "${SSH_USER_ID}" /sshkeys /sshkeys.pub
  chmod 550 /sshkeys /sshkeys.pub
  chmod 440 /sshkeys/* /sshkeys.pub/*
}

_startSSHDContainer() {
  local image_name="$1"
  shift

  local pwh="$(echo "$2"|base64 -d)"

  echo "- Start webconsole sshd-container"
  echo "  user: '$1'"
  echo "  hash: '${pwh}'"

  _downloadImage "${image_name}" && \
  docker run \
    --restart always \
    --name "${WEBCONSOLE_SSHD_HOSTNAME}" \
    --network bridge \
    --cap-add=NET_ADMIN \
    --hostname "${WEBCONSOLE_SSHD_HOSTNAME}" \
    --mount type=bind,source=/vagrant/shared,target=/webconsole \
    --mount type=bind,source=/sshkeys,target=/sshkeys,readonly \
    --mount type=bind,source=/sshkeys.pub,target=/sshkeys.pub,readonly \
    -e SSH_SUBNET="$(_retrieveBridgeSubnet)" \
    -e SSH_USER_ID="${SSH_USER_ID}" \
    -e SSH_USER="$1" \
    -e SSH_HASH="${pwh}" \
    -e SSH_KEY_DIRECTORY="/sshkeys" \
    -e SSH_ACCESSIBLE_NETWORKS="$3" \
    -e SSH_NAMESERVERS="$4" \
    -dt \
    "${image_name}" >/dev/null 2>&1 && \
  _waitContainerReady "${WEBCONSOLE_SSHD_HOSTNAME}"
}

_main() {
  echo "--- INITIALIZATION  ---"
  _checkParams "$@"
  _changeHostname
  _installNecessaryPackages
  _secureSSHD
  _createSSHKeys "$3" "$5"
  _downloadImageDowloader
  _startSSHDContainer "roul76/sshd:latest" "$3" "$4" "$6" "$7"
  _startWebconsoleContainer "roul76/wetty:latest" "$1" "$2"
  _iptables
  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
