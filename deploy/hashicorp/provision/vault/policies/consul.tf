// variable "consul_token" {}

// resource "vault_consul_secret_backend" "consul" {
//   path        = "consul"
//   description = "Manages the Consul backend"

//   address = var.consul_ip
//   token   = var.consul_token
//   scheme  = "http"
// }

// resource "vault_generic_endpoint" "server-consul-token" {
//   depends_on           = [vault_consul_secret_backend.consul]
//   path                 = "consul/roles/server"
//   ignore_absent_fields = true

//   data_json = <<EOT
// {
//   "token_type": "client",
//   "lease": "10m",
//   "policies": ["agent-policy", "sensitive-policy"]
// }
// EOT
// }

// data "vault_generic_secret" "server-consul-token" {
//   depends_on = [vault_generic_endpoint.server-consul-token]
//   path       = "consul/creds/server"
// }

// # Upload consul token to consul kv for consul watch and health check
// resource "consul_keys" "server-consul-token" {
//   datacenter = "dc1"

//   key {
//     path  = "cluster/nodes/node-1/token-id"
//     value = data.vault_generic_secret.server-consul-token.data.accessor
//   }
//   key {
//     path  = "cluster/nodes/node-1/token"
//     value = data.vault_generic_secret.server-consul-token.data.token
//   }
//   key {
//     path  = "cluster/nodes/node-1/token-lease-id"
//     value = data.vault_generic_secret.server-consul-token.lease_id
//   }
//   key {
//     path  = "cluster/nodes/node-1/token-lease-duration"
//     value = data.vault_generic_secret.server-consul-token.lease_duration
//   }
//   key {
//     path  = "cluster/nodes/node-1/token-type"
//     value = "server"
//   }
//   key {
//     path  = "cluster/nodes/node-1/token-status"
//     value = "200"
//   }
// }

// resource "null_resource" "set-consul-token" {
//   depends_on = [consul_keys.server-consul-token]

//    triggers = {
//     consul_token = data.vault_generic_secret.server-consul-token.data.token
//   }


//   provisioner "local-exec" {
//     command = "CONSUL_HTTP_TOKEN=${var.consul_token} consul acl set-agent-token default ${data.vault_generic_secret.server-consul-token.data.token}"
//   }
// }