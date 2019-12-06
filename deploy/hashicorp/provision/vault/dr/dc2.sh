. /etc/environment

echo "consul kv get -http-addr=172.20.20.11:8500 cluster/vault/secondary/token"
token=`consul kv get -http-addr=172.20.20.11:8500 cluster/vault/secondary/token`

echo "vault write sys/replication/dr/secondary/enable token=$token"
vault write sys/replication/dr/secondary/enable token=$token ca_file=/var/vault/config/ca.crt.pem
