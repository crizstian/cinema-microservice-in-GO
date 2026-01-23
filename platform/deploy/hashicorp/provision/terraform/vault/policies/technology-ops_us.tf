variable "enable_technology-ops_us_policy" {}

resource "vault_policy" "technology-ops_us-policy" {
  count = var.enable_technology-ops_us_policy ? 1 : 0

  name   = "technology-ops_us-policy"
  policy = <<EOT
    # Manage namespaces
    path "sys/namespaces/*" {
      capabilities = ["read", "list"]
    }

    # Enable and manage secrets engines
    path "sys/mounts/*" {
      capabilities = ["read", "list"]
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