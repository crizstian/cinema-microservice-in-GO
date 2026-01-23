#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export GOMAXPROCS=$(nproc)

. /etc/environment

consul-template -template "/var/vault/config/vault.hcl.tmpl:/var/vault/config/vault.hcl" -once

exec vault server -config=/var/vault/config/vault.hcl >>/var/log/vault.log 2>&1