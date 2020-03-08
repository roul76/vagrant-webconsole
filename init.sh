#!/bin/sh

_changeHostname() {
  echo "- Changing hostname to 'webconsole'"
  echo "webconsole" > /etc/hostname
  hostname -F /etc/hostname
  sed -i 's/alpine310/webconsole/g' /etc/hosts
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

_waitContainerReady() {
  local timeout
  local x
  local ctrname

  ctrname="$1"
  echo "- Waiting for container '${ctrname}' to become ready"
  # Wait 3 minutes for container to be running
  timeout=180
  x=""
  while [ ${timeout} -gt 0 -a "${x}" = "" ]; do
    x="$(docker ps --quiet --filter "name=${ctrname}" --filter "status=running")"
    sleep 1
    x=$(expr ${timeout} - 1)
  done

  if [ ${timeout} -le 0 ]; then
    echo "Container '${ctrname}' did not come up within 3 minutes.">&2
    exit 1
  fi
}

_startWebconsoleContainer() {
  local pwh

  pwh=$(openssl passwd -1 "$2" 2>/dev/null)
  echo "- Starting webconsole wetty-container"
  echo "  user: '$1'"
  echo "  hash: '${pwh}'"
  docker run \
    --restart always \
    --name webconsole \
    --network host \
    --hostname webconsole \
    --mount type=bind,source=/vagrant/bin,target=/webconsole,readonly \
    -e WEBCONSOLE_USER="$1" \
    -e WEBCONSOLE_HASH="${pwh}" \
    -e WEBCONSOLE_SHELL="/webconsole/ssh.sh" \
    -dt \
    roul76/wetty:latest >/dev/null 2>&1

  _waitContainerReady "webconsole"
}

_main() {
  echo "--- INITIALIZATION  ---"
  _changeHostname
  _secureSSHD
  _startWebconsoleContainer "$1" "$2"
  echo "--- FINISHED ---"
}

# ###############################
_main "$@"
# ###############################



