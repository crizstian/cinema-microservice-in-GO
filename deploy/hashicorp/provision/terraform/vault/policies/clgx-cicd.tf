variable "enable_clgx-cicd_policy" {}

resource "vault_policy" "clgx-cicd-policy" {
  count = var.enable_clgx-cicd_policy ? 1 : 0

  name   = "clgx-cicd-policy"
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