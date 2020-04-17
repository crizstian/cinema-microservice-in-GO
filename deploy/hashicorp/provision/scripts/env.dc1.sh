# General vars
export HOST_IP="172.20.20.11"
export PRIMARY_HOST_IP="172.20.20.11"
export DATACENTER=dc1
export PRIMARY_DATACENTER=dc1
export SECONDARY_DATACENTER=dc2

# Vault env vars
export VAULT_CACERT=/var/vault/config/ca.crt.pem
export VAULT_CLIENT_CERT=/var/vault/config/server.crt.pem
export VAULT_CLIENT_KEY=/var/vault/config/server.key.pem
export VAULT_ADDR=https://${HOST_IP}:8200

# Nomad env vars
export NOMAD_ADDR=https://${HOST_IP}:4646
export NOMAD_CACERT=/var/vault/config/ca.crt.pem
export NOMAD_CLIENT_CERT=/var/vault/config/server.crt.pem
export NOMAD_CLIENT_KEY=/var/vault/config/server.key.pem

# Consul env vars
export CONSUL_SCHEME=https
export CONSUL_PORT=8500
export CONSUL_HTTP_ADDR=${CONSUL_SCHEME}://${HOST_IP}:${CONSUL_PORT}
export CONSUL_CACERT=/var/vault/config/ca.crt.pem
export CONSUL_CLIENT_CERT=/var/vault/config/server.crt.pem
export CONSUL_CLIENT_KEY=/var/vault/config/server.key.pem
export CONSUL_HTTP_SSL=true
export CONSUL_ENCRYPT_KEY="apEfb4TxRk3zGtrxxAjIkwUOgnVkaD88uFyMGHqKjIw="
export CONSUL_SSL=true

# Terraform env vars
export TF_VAR_consul_address=${HOST_IP}:${CONSUL_PORT}
export TF_VAR_consul_scheme=${CONSUL_SCHEME}
export TF_VAR_consul_datacenter=${DATACENTER}
export TF_BACKEND_CONSUL_ADDRESS=${TF_BACKEND_CONSUL_ADDRESS}
export TF_BACKEND_CONSUL_PATH="terraform/${DATACENTER}.state"
export TF_WORKSPACE="default"