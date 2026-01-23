variable "enable_userpass_engine" {}

resource "vault_auth_backend" "userpass" {
  count = var.enable_userpass_engine ? 1 : 0
  type  = "userpass"
}

resource "null_resource" "depends_on_userpass_mount" {
  count = var.enable_userpass_engine ? 1 : 0
  depends_on = [vault_auth_backend.userpass]
}

output "depends_on_userpass_mount" {
    value = var.enable_userpass_engine ? null_resource.depends_on_userpass_mount.0.id : ""
}

output "userpass_accessor" {
  value = var.enable_userpass_engine ? vault_auth_backend.userpass[0].accessor : ""
}
