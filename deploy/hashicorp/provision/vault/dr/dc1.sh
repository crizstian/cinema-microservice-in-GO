. /etc/environment

echo "vault write -f sys/replication/dr/primary/enable"
vault write -f sys/replication/dr/primary/enable

echo "vault write -format=json sys/replication/dr/primary/secondary-token id=secondary"
token=`vault write -format=json sys/replication/dr/primary/secondary-token id="secondary-c" | jq .wrap_info.token | sed s/\"//g`

echo "consul kv put cluster/vault/secondary/token $token"
consul kv put cluster/vault/secondary/token $token

