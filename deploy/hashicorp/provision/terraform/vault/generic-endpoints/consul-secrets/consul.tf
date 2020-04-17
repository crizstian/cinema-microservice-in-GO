variable "depends_on_consul_mount" {
  default = ""
}
variable "generate_server_token" {
  default = false
}
variable "upload_server_token_to_consul_kv" {
  default = false
}
variable "consul_datacenter" {
  default = ""
}

resource "vault_generic_endpoint" "server-consul-token" {
  count = var.generate_server_token ? 1 : 0

  depends_on           = [var.depends_on_consul_mount]
  path                 = "consul/roles/server"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "token_type": "client",
  "lease": "10m",
  "policies": ["agent-policy", "sensitive-policy"]
}
EOT
}

data "vault_generic_secret" "server-consul-token" {
  count = var.generate_server_token && var.upload_server_token_to_consul_kv ? 1 : 0
  
  depends_on = [vault_generic_endpoint.server-consul-token]
  path       = "consul/creds/server"
}

# Upload consul token to consul kv for consul watch and health check
resource "consul_keys" "server-consul-token" {
  count = var.generate_server_token && var.upload_server_token_to_consul_kv ? 1 : 0
  
  datacenter = var.consul_datacenter

  key {
    path  = "cluster/nodes/node-1/token-id"
    value = data.vault_generic_secret.server-consul-token.0.data.accessor
  }
  key {
    path  = "cluster/nodes/node-1/token"
    value = data.vault_generic_secret.server-consul-token.0.data.token
  }
  key {
    path  = "cluster/nodes/node-1/token-lease-id"
    value = data.vault_generic_secret.server-consul-token.0.lease_id
  }
  key {
    path  = "cluster/nodes/node-1/token-lease-duration"
    value = data.vault_generic_secret.server-consul-token.0.lease_duration
  }
  key {
    path  = "cluster/nodes/node-1/token-type"
    value = "server"
  }
  key {
    path  = "cluster/nodes/node-1/token-status"
    value = "200"
  }
}