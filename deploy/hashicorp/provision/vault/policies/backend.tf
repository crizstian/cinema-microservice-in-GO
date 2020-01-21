# Enable approle auth method
resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_mount" "secret-kv" {
  path        = "secret"
  type        = "kv"
  description = "Secret KV Engine"
}
