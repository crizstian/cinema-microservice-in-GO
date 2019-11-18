export VAULT_CACERT=/var/vault/config/ca.crt.pem
export VAULT_ADDR=https://172.20.20.31:8200

export NOMAD_ADDR=https://172.20.20.31:4646
export NOMAD_CACERT=/var/vault/config/ca.crt.pem
export NOMAD_CLIENT_CERT=/var/vault/config/server.crt.pem
export NOMAD_CLIENT_KEY=/var/vault/config/server.key.pem

export CONSUL_HTTP_ADDR=https://172.20.20.31:8501
export CONSUL_CACERT=/var/vault/config/ca.crt.pem
export CONSUL_CLIENT_CERT=/var/vault/config/server.crt.pem
export CONSUL_CLIENT_KEY=/var/vault/config/server.key.pem

export HOST_IP=`echo $CONSUL_HTTP_ADDR | cut -c9-20`
export DATACENTER=DC2
