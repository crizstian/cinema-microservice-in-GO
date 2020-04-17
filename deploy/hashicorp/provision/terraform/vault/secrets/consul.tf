variable "enable_consul_engine" {
  default = false
}
variable "consul_token" {
  default = ""
}
variable "consul_address" {
  default = ""
}
variable "consul_scheme" {
  default = ""
}

resource "vault_consul_secret_backend" "consul" {
  count = var.enable_consul_engine ? 1 : 0

  path        = "consul"
  description = "Manages the Consul backend"
  address     = var.consul_address
  token       = var.consul_token
  scheme      = var.consul_scheme
}

resource "null_resource" "depends_on_consul_mount" {
  depends_on = [vault_consul_secret_backend.consul]
}

output "depends_on_consul_mount" {
  value = null_resource.depends_on_consul_mount.id
}

// resource "null_resource" "set-consul-token" {
//   depends_on = [consul_keys.server-consul-token]

//    triggers = {
//     consul_token = data.vault_generic_secret.server-consul-token.data.token
//   }


//   provisioner "local-exec" {
//     command = "CONSUL_HTTP_TOKEN=${var.consul_token} consul acl set-agent-token default ${data.vault_generic_secret.server-consul-token.data.token}"
//   }
// }