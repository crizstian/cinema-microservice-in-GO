variable "enable_kv_engine" {}

resource "vault_mount" "secret-kv" {
  count = var.enable_kv_engine ? 1 : 0

  path        = "secret"
  type        = "kv"
  description = "Secret KV Engine"
}

resource "null_resource" "depends_on_kv_mount" {
  count = var.enable_kv_engine ? 1 : 0
  
  depends_on = [vault_mount.secret-kv]
}

output "depends_on_kv_mount" {
  value = var.enable_kv_engine ? null_resource.depends_on_kv_mount.0.id : ""
}