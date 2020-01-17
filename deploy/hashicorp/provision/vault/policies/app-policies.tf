# Application Policies
resource "vault_policy" "apps-policy" {
  count = length(var.apps)

  name = "${var.apps[count.index]}-policy"

  policy = <<EOT
    path "secret/${var.apps[count.index]}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/${var.apps[count.index]}" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

# Application Roles
resource "vault_approle_auth_backend_role" "apps-role" {
  count = length(var.apps)

  backend        = vault_auth_backend.approle.path
  role_name      = "${var.apps[count.index]}-role"
  token_policies = ["${vault_policy.apps-policy[count.index].name}"]
  token_ttl      = 1440
  secret_id_ttl  = 0
}

# Application Secret_id to auth againts vault
resource "vault_approle_auth_backend_role_secret_id" "apps-secret" {
  count = length(var.apps)

  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.apps-role[count.index].role_name
}

# Upload applications role_id to consul kv
resource "consul_keys" "apps-role-id" {
  count = length(var.apps)

  datacenter = "dc1"

  key {
    path  = "cluster/vault/${var.apps[count.index]}/role_id"
    value = vault_approle_auth_backend_role.apps-role[count.index].role_id
  }
}

# Upload applications secret_id to consul kv
resource "consul_keys" "app-secret-id" {
  count = length(var.apps)

  datacenter = "dc1"

  key {
    path  = "cluster/vault/${var.apps[count.index]}/secret_id"
    value = vault_approle_auth_backend_role_secret_id.apps-secret[count.index].secret_id
  }
}