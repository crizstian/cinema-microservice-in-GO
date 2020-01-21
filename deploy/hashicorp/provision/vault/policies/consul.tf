// resource "vault_consul_secret_backend" "consul" {
//   path        = "consul"
//   description = "Manages the Consul backend"

//   address = var.consul_ip
//   token   = var.consul_token
//   scheme  = "http"
// }

// resource "vault_generic_endpoint" "operator-consul-token" {
//   depends_on           = ["vault_consul_secret_backend.consul"]
//   path                 = "consul/roles/operator"
//   ignore_absent_fields = true

//   data_json = <<EOT
//     {
//       "lease": "300s",
//       "policies": "operator",
//     }
// EOT
// }

# Consul roles
// vault write consul/roles/operator policies=agent-policy lease=300s

# # Token lease is for 1hr
# vault write consul/roles/operator-prefix policies=sensitve-policy,server-policy,agent-prefix-policy lease=3600s

# # Token lease is for 5min
# vault write consul/roles/server policies=server-policy,agent-policy lease=300s

# vault write consul/roles/agent policies=agent-policy,blocking-policy

# vault write consul/roles/anonymous policies=blocking-policy,anonymous-policy
