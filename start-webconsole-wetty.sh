#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

# shellcheck source=include/_include.sh
. "${localdir}/_include.sh"

_checkParams() {
  echo "- Validate parameters"
  if [ $# -ne 2 ]; then
    echo "FAILURE! Missing parameter">&2
    echo "- Usage: $0 <webconsole-user> <webconsole-password-hash-b64>">&2
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

_main() {
  local wetty_user="$1"
  local wetty_hashed_password_base64="$2"

  echo "--- START WEBCONSOLE WETTY CONTAINER ---"

  _checkParams "$@"
  _startWebconsoleContainer "${wetty_user}" "${wetty_hashed_password_base64}"

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
