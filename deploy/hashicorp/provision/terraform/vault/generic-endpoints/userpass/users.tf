variable "depends_on_userpass_mount" {
  default = ""
}
variable "enable_admin_user" {
  default = false
}


resource "vault_generic_endpoint" "admin-user" {
  count = var.enable_admin_user ? 1 : 0
  
  depends_on           = [var.depends_on_userpass_mount]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin-policy", "default"],
  "password": "admin"
}
EOT
}