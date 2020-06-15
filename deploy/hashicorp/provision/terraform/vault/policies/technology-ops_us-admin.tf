variable "enable_technology-ops_us_admin_policy" {}

resource "vault_policy" "technology-ops_us-admin-policy" {
  count = var.enable_technology-ops_us_admin_policy ? 1 : 0

  name   = "technology-ops_us-admin-policy"
  policy = <<EOT
    # Manage namespaces
    path "sys/namespaces/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Manage policies
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # List policies
    path "sys/policies/acl" {
      capabilities = ["list"]
    }

    # Enable and manage secrets engines
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # List available secrets engines
    path "sys/mounts" {
      capabilities = [ "read" ]
    }

    # Manage secrets at 'secret'
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Create tokens for GCP
    path "gcp/token/*" {
      capabilities = [ "read" ]
    }
  EOT
}