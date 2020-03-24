vagrant-webconsole
==================
Vagrant setup for running a Docker container containing wetty (https://hub.docker.com/repository/docker/roul76/wetty)

Startup
-------
Before startup make sure to export your desired bridged network adapter:
```
export VAGRANT_BRIDGE_NETWORK_ADAPTER="enp1s0"
```
If the network adapter is not available you will be asked to pick the right one during startup.

The box itself can be started in two ways.
Either full provisioning:
```
export INIT_ARGS_PREPARATION="<vm hostname> <webconsole-user> <ssh-key-passphrase-base64>"
export INIT_ARGS_WEBCONSOLE_SSHD="<ssh-user> <password-hash-base64> <allowed networks> <additional nameservers>"
export INIT_ARGS_WEBCONSOLE_WETTY="<webconsole-user> <password-hash-base64>"
export INIT_ARGS_WEBCONSOLE_NODESTATIC=""
export INIT_ARGS_FINALIZATION="" 
vagrant up --provider="virtualbox"
```
or step-by-step-provisioning:
```
vagrant up --no-provision --provider="virtualbox"

INIT_ARGS_PREPARATION="<vm hostname> <webconsole-user> <ssh-key-passphrase-base64>" vagrant provision --provision-with peparation
INIT_ARGS_WEBCONSOLE_SSHD="<ssh-user> <password-hash-base64> <allowed networks> <additional nameservers>" vagrant provision --provision-with start-webconsole-sshd  
INIT_ARGS_WEBCONSOLE_WETTY="<webconsole-user> <password-hash-base64>" vagrant provision --provision-with start-webconsole-wetty
INIT_ARGS_WEBCONSOLE_NODESTATIC="" vagrant provision --provision-with start-webconsole-nodestatic
INIT_ARGS_FINALIZATION="" vagrant provision --provision-with finalization
```

Example:
```
export INIT_ARGS_PREPARATION="mywebconsolehost '$(echo "55HPassphrase"|base64)'"
export INIT_ARGS_WEBCONSOLE_SSHD="lisa '$(openssl passwd -1 "LisaDO3%"|base64)' '0.0.0.0/0' '1.1.1.1|1.0.0.1|8.8.8.8|8.8.4.4'"
export INIT_ARGS_WEBCONSOLE_WETTY="john '$(openssl passwd -1 "JohnDO3%"|base64)'"
export INIT_ARGS_WEBCONSOLE_NODESTATIC=""
export INIT_ARGS_FINALIZATION="" 
vagrant up
```
Afterwards the webconsole will be available at `http://mywebconsolehost:3000/wetty/`:
```
webconsole login: john
Password: JohnDO3% (<-- not visible)
lisa@webconsole-sshd's password: LisaDO3% (<-- not visible)


*** SSH key files stored in /sshkeys ***

20-03-24 6:49 /home/lisa
$ ls -l /sshkeys*
/sshkeys:
total 4
-r--------    1 lisa     webconso      3454 Mar 23 17:49 webconsole-sshd.key

/sshkeys.pub:
total 4
-r--r-----    1 lisa     webconso       757 Mar 23 17:49 webconsole-sshd.key.pub
```
The public key for passwordless / key based ssh authentication can be obtained at `http://mywebconsolehost:3001/webconsole-sshd.key.pub`.
You might add it to your `~/.ssh/authorized_keys` file on your target host:
```
$ curl http://mywebconsolehost:3001/webconsole-sshd.key.pub >> ~/.ssh/authorized_keys
```
