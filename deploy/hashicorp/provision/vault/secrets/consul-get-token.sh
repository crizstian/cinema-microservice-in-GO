export VAULT_TOKEN=$1
export VAULT_ADDR=http://172.20.20.11:8200

echo "Get Consul Role Token from Vault"

vault read consul/creds/$2