#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

# shellcheck source=include/_include.sh
. "${localdir}/_include.sh"

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 4 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: $0 <ssh-user> <ssh-password-hash-b64> <accessible networks> <nameservers>">&2
    exit 1
  fi
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

_main() {
  local sshd_user="$1"
  local sshd_hashed_password_base64="$2"
  local accessible_subnets="$3"
  local additional_nameservers="$4"

  echo "--- START WEBCONSOLE SSHD CONTAINER ---"

  _checkParams "$@"
  _startSSHDContainer "${sshd_user}" "${sshd_hashed_password_base64}" "${accessible_subnets}" "${additional_nameservers}"

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
