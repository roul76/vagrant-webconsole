#!/bin/ash

set -eo pipefail

localdir="/vagrant/include"
# shellcheck source=include/_global-vars.sh
. "${localdir}/_global-vars.sh"

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

_startNodeStaticContainer() {
  local image_name="roul76/node-static:latest"

  echo "- Start webconsole node-static-container"

  _downloadImage "${image_name}"
  docker run \
    --restart always \
    --name "${WEBCONSOLE_NODESTATIC_HOSTNAME}" \
    --network host \
    --hostname "${WEBCONSOLE_NODESTATIC_HOSTNAME}" \
    --mount type=bind,source=/sshkeys.pub,target=/sshkeys.pub,readonly \
    -e NODE_STATIC_DIR=/sshkeys.pub \
    -e NODE_STATIC_PORT="${WEBCONSOLE_NODESTATIC_PORT}" \
    -dt \
    "${image_name}"
  _waitContainerReady "${WEBCONSOLE_NODESTATIC_HOSTNAME}"
}

_main() {

  echo "--- START WEBCONSOLE NODESTATIC CONTAINER ---"

  _checkParams "$@"
  _startNodeStaticContainer

  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################
