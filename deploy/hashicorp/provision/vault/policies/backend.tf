# Enable approle auth method
resource "vault_auth_backend" "approle" {
  type = "approle"
}

// resource "vault_consul_secret_backend" "test" {
//   path        = "consul"
//   description = "Manages the Consul backend"

//   address = var.consul_ip
//   token   = var.consul_token
//   scheme  = "http"
// }

// resource "vault_mount" "mongo-db" {
//   path = "mongo-db"
//   type = "database"
// }

// resource "vault_database_secret_backend_connection" "mongo-db" {
//   backend       = vault_mount.db.path
//   name          = "mongo-db"
//   allowed_roles = ["dev"]

//   postgresql {
//     connection_url = "mongodb://${var.mongo_username}:${var.mongo_password}@${var.mongo_ip}:27017/admin?ssl=true"
//   }
// }