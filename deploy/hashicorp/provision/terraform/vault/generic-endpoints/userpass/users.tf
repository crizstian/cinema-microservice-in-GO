variable "depends_on_userpass_mount" {}
variable "users" {}

resource "vault_generic_endpoint" "admin-user" {
  count = length(var.users)
  
  depends_on           = [var.depends_on_userpass_mount]
  path                 = "auth/userpass/users/${var.users[count.index].user}"
  ignore_absent_fields = true
  data_json            = <<EOT
  {
    "password": "${var.users[count.index].password}"
  }
  EOT
}