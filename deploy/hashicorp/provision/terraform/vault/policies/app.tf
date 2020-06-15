variable "enable_app_policy" {}
variable "policy_apps" {}

# Application Policies
resource "vault_policy" "apps-policy" {
  count = var.enable_app_policy ? length(var.policy_apps) : 0

  name = "${var.policy_apps[count.index]}-policy"

  policy = <<EOT
    path "secret/${var.policy_apps[count.index]}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    path "secret/${var.policy_apps[count.index]}" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}
