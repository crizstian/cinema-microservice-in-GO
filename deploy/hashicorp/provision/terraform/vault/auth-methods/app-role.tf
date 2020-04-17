variable "enable_app_role" {
  default = false
}
variable "roles" {
  default = []
}
variable "enable_store_approle_in_consul" {
  default = false
}
variable "consul_datacenter" {
  default = ""
}

resource "vault_auth_backend" "approle" {
  count = var.enable_app_role ? 1 : 0
  type  = "approle"
}

resource "vault_approle_auth_backend_role" "role" {
  count = var.enable_app_role ? length(var.roles) : 0

  backend        = vault_auth_backend.approle.0.path
  role_name      = "${var.roles[count.index]}-role"
  token_policies = ["${var.roles[count.index]}-policy"]
  token_ttl      = 1440
  secret_id_ttl  = 0
}

# Application Secret_id to auth againts vault
resource "vault_approle_auth_backend_role_secret_id" "secret" {
  count = var.enable_app_role ? length(var.roles) : 0

  backend   = vault_auth_backend.approle.0.path
  role_name = vault_approle_auth_backend_role.role[count.index].role_name
}

# Upload applications role_id to consul kv
resource "consul_keys" "role-id" {
  count = var.enable_app_role && var.enable_store_approle_in_consul ? length(var.roles) : 0

  datacenter = var.consul_datacenter

  key {
    path  = "cluster/apps/${var.roles[count.index]}/auth/role_id"
    value = vault_approle_auth_backend_role.role[count.index].role_id
  }
}

# Upload applications secret_id to consul kv
resource "consul_keys" "secret-id" {
  count = var.enable_app_role && var.enable_store_approle_in_consul ? length(var.roles) : 0

  datacenter = var.consul_datacenter

  key {
    path  = "cluster/apps/${var.roles[count.index]}/auth/secret_id"
    value = vault_approle_auth_backend_role_secret_id.secret[count.index].secret_id
  }
}