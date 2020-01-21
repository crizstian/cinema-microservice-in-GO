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

# Infrastructure Policies
resource "vault_policy" "infrastructure-policy" {
  count = length(var.infrastructure)

  name = "${var.infrastructure[count.index]}-policy"

  policy = <<EOT
    # Permits token creation
    path "auth/token/create" {
      capabilities = ["update"]
    }
    
    # Permits consul token creation
    path "consul/creds/*" {
      capabilities = ["read"]
    }
  EOT
}

