variable "enable_clgx-cicd_admin_policy" {}

resource "vault_policy" "clgx-cicd-admin-policy" {
  count = var.enable_clgx-cicd_admin_policy ? 1 : 0

  name   = "clgx-cicd-admin-policy"
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
  EOT
}