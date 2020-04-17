variable "enable_kv_engine" {
  default = false
}

resource "vault_mount" "secret-kv" {
  count = var.enable_kv_engine ? 1 : 0

  path        = "secret"
  type        = "kv"
  description = "Secret KV Engine"
}

resource "null_resource" "depends_on_kv_mount" {
  depends_on = [vault_mount.secret-kv]
}

output "depends_on_kv_mount" {
  value = null_resource.depends_on_kv_mount.id
}