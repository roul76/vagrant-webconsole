#!/bin/ash

set -eo pipefail

WEBCONSOLE_HOSTNAME="webconsole"
WEBCONSOLE_SSHD_HOSTNAME="webconsole-sshd"
WEBCONSOLE_NODESTATIC_HOSTNAME="webconsole-nodestatic"
SSH_USER_ID=10001

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 8 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: $0 \ ">&2
    echo "           <hostname> \ ">&2
    echo "           <webconsole-user> \ ">&2
    echo "           <webconsole-password-hash-b64> \ ">&2
    echo "           <ssh-user> <ssh-password-hash-b64> \ ">&2
    echo "           <ssh-passphrase-b64> \ ">&2
    echo "           <accessible networks> \ ">&2
    echo "           <nameservers>">&2
    exit 1
  fi
}

_changeHostname() {
  echo "- Change hostname to '$1'"
  echo "$1" > /etc/hostname
  hostname -F /etc/hostname
  sed -i 's/alpine310/'"$1"'/g' /etc/hosts
}

_installNecessaryPackages() {
  echo "- Install necessary packages"
  apk add --no-cache jq go curl wget
}

_downloadImageDowloader() {
  # Refer to
  # - https://github.com/moby/moby/blob/master/contrib/download-frozen-image-v2.sh
  # - https://dev.to/tomsfernandez/download-docker-images-without-docker-pull-17e6
  echo "- Download image downloader"
  wget https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh
  chmod 750 ./download-frozen-image-v2.sh
}

_downloadImage() {
  echo "- Download image $1"
  local dir; dir=$(mktemp -d)
  ./download-frozen-image-v2.sh "${dir}" "$1">/dev/null
  tar -cC "${dir}" . | docker load
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

  /etc/init.d/sshd restart
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
  local image_name="roul76/wetty:latest"
  local shell="/webconsole/${WEBCONSOLE_SSHD_HOSTNAME}.sh"
  local pwh; pwh="$(echo "$2"|base64 -d)"

  echo "- Start webconsole wetty-container"
  echo "  user:  '$1'"
  echo "  hash:  '${pwh}'"
  echo "  shell: '${shell}'"

  _downloadImage "${image_name}"
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
    "${image_name}"
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
  local image_name="roul76/sshd:latest"
  local pwh; pwh="$(echo "$2"|base64 -d)"

  echo "- Start webconsole sshd-container"
  echo "  user: '$1'"
  echo "  hash: '${pwh}'"

  _downloadImage "${image_name}"

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
    "${image_name}"

  _waitContainerReady "${WEBCONSOLE_SSHD_HOSTNAME}"
}

_startNodeStaticContainer() {
  local image_name="roul76/node-static:latest"

  echo "- Start webconsole node-static-container"

  _downloadImage "${image_name}"
  docker run \
    --restart always \
    --name "${WEBCONSOLE_NODESTATIC_HOSTNAME}" \
    --network host \
    --cap-add=NET_ADMIN \
    --hostname "${WEBCONSOLE_NODESTATIC_HOSTNAME}" \
    --mount type=bind,source=/sshkeys.pub,target=/sshkeys.pub,readonly \
    -e NODE_STATIC_DIR=/sshkeys.pub \
    -dt \
    "${image_name}"
  _waitContainerReady "${WEBCONSOLE_NODESTATIC_HOSTNAME}"
}

_main() {
  local hostname="$1"
  local wetty_user="$2"
  local wetty_hashed_password_base64="$3"
  local sshd_user="$4"
  local sshd_hashed_password_base64="$5"
  local sshd_key_passphrase_base64="$6"
  local accessible_subnets="$7"
  local additional_nameservers="$8"

  echo "--- INITIALIZATION ---"

  _checkParams "$@"
  _changeHostname "${hostname}"
  _installNecessaryPackages
  _secureSSHD
  _createSSHKeys "${sshd_user}" "${sshd_key_passphrase_base64}"
  _downloadImageDowloader
  _startSSHDContainer "${sshd_user}" "${sshd_hashed_password_base64}" "${accessible_subnets}" "${additional_nameservers}"
  _startNodeStaticContainer
  _startWebconsoleContainer "${wetty_user}" "${wetty_hashed_password_base64}"
  _changeIPTables

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
