# vagrant-webconsole
Vagrant setup for running a Docker container containing wetty (https://github.com/butlerx/wetty)

Startup:
```
INIT_ARGS="<webconsole-user> <password>" vagrant up
```
The given password will be hashed while provisioning.
