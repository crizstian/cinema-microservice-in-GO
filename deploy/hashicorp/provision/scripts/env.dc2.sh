export VAULT_CACERT=/var/vault/config/ca.crt.pem
export VAULT_ADDR=https://172.20.20.31:8200
export VAULT_CLIENT_CERT=/var/vault/config/server.crt.pem
export VAULT_CLIENT_KEY=/var/vault/config/server.key.pem

export NOMAD_ADDR=https://172.20.20.31:4646
export NOMAD_CACERT=/var/vault/config/ca.crt.pem
export NOMAD_CLIENT_CERT=/var/vault/config/server.crt.pem
export NOMAD_CLIENT_KEY=/var/vault/config/server.key.pem

export CONSUL_HTTP_ADDR=http://172.20.20.31:8500
# export CONSUL_CACERT=/var/vault/config/ca.crt.pem
# export CONSUL_CLIENT_CERT=/var/vault/config/server.crt.pem
# export CONSUL_CLIENT_KEY=/var/vault/config/server.key.pem

export HOST_IP=`echo $CONSUL_HTTP_ADDR | cut -c8-19`
export DATACENTER=dc2
