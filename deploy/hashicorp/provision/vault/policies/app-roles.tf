# Application Roles
resource "vault_approle_auth_backend_role" "apps-role" {
  count = length(concat(var.apps, var.infrastructure))

  backend        = vault_auth_backend.approle.path
  role_name      = "${element(concat(var.apps, var.infrastructure), count.index)}-role"
  token_policies = ["${element(concat(vault_policy.apps-policy.*.name, vault_policy.infrastructure-policy.*.name), count.index)}"]
  token_ttl      = 1440
  secret_id_ttl  = 0
}

# Application Secret_id to auth againts vault
resource "vault_approle_auth_backend_role_secret_id" "apps-secret" {
  count = length(concat(var.apps, var.infrastructure))

  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.apps-role[count.index].role_name
}

# Upload applications role_id to consul kv
resource "consul_keys" "apps-role-id" {
  count = length(concat(var.apps, var.infrastructure))

  datacenter = "dc1"

  key {
    path  = "cluster/apps/${element(concat(var.apps, var.infrastructure), count.index)}/auth/role_id"
    value = vault_approle_auth_backend_role.apps-role[count.index].role_id
  }
}

# Upload applications secret_id to consul kv
resource "consul_keys" "apps-secret-id" {
  count = length(concat(var.apps, var.infrastructure))

  datacenter = "dc1"

  key {
    path  = "cluster/apps/${element(concat(var.apps, var.infrastructure), count.index)}/auth/secret_id"
    value = vault_approle_auth_backend_role_secret_id.apps-secret[count.index].secret_id
  }
}