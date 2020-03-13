# vagrant-webconsole
Vagrant setup for running a Docker container containing wetty (https://hub.docker.com/repository/docker/roul76/wetty)

Startup:
```
INIT_ARGS="<webconsole-user> <password> <ssh-user> <password> <allowed networks>" vagrant up
```
The given passwords will be hashed while provisioning.
Example:
```
INIT_ARGS="john JohnD03% lisa LisaD03% 192.168.1.0/24|10.0.1.0/24" vagrant up
```

