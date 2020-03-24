_downloadImage() {
  echo "- Download image $1"
  local dir; dir=$(mktemp -d)
  set +e
  if ! x=$(./download-frozen-image-v2.sh "${dir}" "$1" 2>&1); then
    echo "$x">&2
    exit 1
  fi
  set -e
  tar -cC "${dir}" . | docker load
  rm -rf "${dir}"
}

_waitContainerReady() {
  local timeout=180
  local x=""
  local ctrname="$1"

  echo "- Wait 180 s for container '${ctrname}' to become ready"
  # Wait 3 minutes for container to be running
  while [ ${timeout} -gt 0 ] && \
        [ "${x}" = "" ]; do
    x="$(docker ps --quiet --filter "name=^/${ctrname}$" --filter "status=running")"
    sleep 1
    timeout=$(( timeout - 1 ))
  done

  if [ "${timeout}" -le 0 ]; then
    echo "Container '${ctrname}' did not come up within 3 minutes.">&2
    exit 1
  fi
}

_retrieveBridgeSubnet() {
  docker network inspect bridge | jq --raw-output -e '.[0].IPAM.Config[0].Subnet'
}

