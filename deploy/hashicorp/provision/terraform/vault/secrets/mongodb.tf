variable "enable_mongo_db_engine" {
  default = false
}
variable "allowed_roles" {
  default = []
}
variable "mongo_username" {
  default = ""
}
variable "mongo_password" {
  default = ""
}
variable "mongo_ip" {
  default = ""
}
variable "mongo_port" {
  default = ""
}
variable "connection_url" {
  default = ""
}

locals {
  connection_url = "mongodb://${var.mongo_username}:${var.mongo_password}@${var.mongo_ip}:${var.mongo_port}/admin?ssl=true"
}

resource "vault_mount" "mongo-db" {
  count = var.enable_mongo_db_engine ? 1 : 0

  path = "mongo-db"
  type = "database"
}

resource "vault_database_secret_backend_connection" "mongo-db" {
  count = var.enable_mongo_db_engine ? 1 : 0
  
  backend       = vault_mount.mongo-db.0.path
  name          = "mongo-db"
  allowed_roles = var.allowed_roles

  mongodb {
    connection_url = var.connection_url == "" ? local.connection_url : var.connection_url
  }
}