#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

export GOMAXPROCS=$(nproc)

. /etc/environment

if [ "$ENABLE_CA_CERT" == "true" ]; then
  curl_ssl="--cacert ${CA_CERT_FILE}"
fi

rm -f /var/vault/config/agent/roleID
rm -f /var/vault/config/agent/secretID

curl $curl_ssl -s -X GET $CONSUL_HTTP_ADDR/v1/kv/cluster/apps/vault-agent/auth/role_id | jq  -r '.[].Value'| base64 -d - > /var/vault/config/agent/roleID

curl $curl_ssl -s -X GET $CONSUL_HTTP_ADDR/v1/kv/cluster/apps/vault-agent/auth/secret_id | jq  -r '.[].Value'| base64 -d - > /var/vault/config/agent/secretID

consul-template -template "/var/vault/config/agent/agent.hcl.tmpl:/var/vault/config/agent/agent.hcl" -once

exec vault agent -config=/var/vault/config/agent/agent.hcl >>/var/log/vault-agent.log 2>&1