export HOST_IP="172.20.20.11"
export DATACENTER=dc1

export VAULT_CACERT=/var/vault/config/ca.crt.pem
export VAULT_CLIENT_CERT=/var/vault/config/server.crt.pem
export VAULT_CLIENT_KEY=/var/vault/config/server.key.pem
export VAULT_ADDR=https://${HOST_IP}:8200

export NOMAD_ADDR=https://${HOST_IP}:4646
export NOMAD_CACERT=/var/vault/config/ca.crt.pem
export NOMAD_CLIENT_CERT=/var/vault/config/server.crt.pem
export NOMAD_CLIENT_KEY=/var/vault/config/server.key.pem

export CONSUL_SCHEME=http
export CONSUL_PORT=8500
export CONSUL_HTTP_ADDR=${CONSUL_SCHEME}://${HOST_IP}:${CONSUL_PORT}
# export CONSUL_CACERT=/var/vault/config/ca.crt.pem
# export CONSUL_CLIENT_CERT=/var/vault/config/server.crt.pem
# export CONSUL_CLIENT_KEY=/var/vault/config/server.key.pem