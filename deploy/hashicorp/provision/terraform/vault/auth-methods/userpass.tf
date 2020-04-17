variable "enable_userpass_engine" {
  default = false
}

resource "vault_auth_backend" "userpass" {
  count = var.enable_userpass_engine ? 1 : 0
  type  = "userpass"
}

resource "null_resource" "depends_on_userpass_mount" {
  count = var.enable_userpass_engine ? 1 : 0
  depends_on = [vault_auth_backend.userpass]
}

output "depends_on_userpass_mount" {
    value = null_resource.depends_on_userpass_mount.0.id
}