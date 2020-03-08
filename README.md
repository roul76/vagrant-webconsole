# vagrant-webconsole
Vagrant setup for running a Docker container containing wetty (https://hub.docker.com/repository/docker/roul76/wetty)

Startup:
```
INIT_ARGS="<webconsole-user> <password>" vagrant up
```
The given password will be hashed while provisioning.
