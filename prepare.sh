#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 2 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: $0 <hostname> <ssh-passphrase-b64>">&2
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
  set +e
  if ! x=$(wget https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh 2>&1); then
    echo "$x">&2
    exit 1
  fi
  set -e
  chmod 750 ./download-frozen-image-v2.sh
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

_createSSHKeys() {
  echo "- Create ssh keys"
  mkdir /sshkeys /sshkeys.pub
  ssh-keygen -q \
    -N "$(echo "$1"|base64 -d)" \
    -t rsa \
    -b 4096 \
    -C "${WEBCONSOLE_SSHD_HOSTNAME}" \
    -f "/sshkeys/${WEBCONSOLE_SSHD_HOSTNAME}.key"
  mv /sshkeys/*.pub /sshkeys.pub/
  chown -R "${SSH_USER_ID}:${SSH_USER_ID}" /sshkeys /sshkeys.pub
  chmod 500 /sshkeys
  chmod 550 /sshkeys.pub
  chmod 400 /sshkeys/*
  chmod 440 /sshkeys.pub/*
}


_main() {
  local hostname="$1"
  local sshd_key_passphrase_base64="$2"

  echo "--- PREPARATION ---"

  _checkParams "$@"
  _changeHostname "${hostname}"
  _installNecessaryPackages
  _secureSSHD
  _createSSHKeys "${sshd_key_passphrase_base64}"
  _downloadImageDowloader

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
