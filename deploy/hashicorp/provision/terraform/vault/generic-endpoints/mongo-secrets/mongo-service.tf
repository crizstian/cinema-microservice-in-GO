variable "depends_on_kv_mount" {
  default = ""
}
variable "deploy_mongodb_secrets" {
  default = false
}

resource "vault_generic_secret" "mongodb-service" {
  count = var.deploy_mongodb_secrets ? 1 : 0
  
  depends_on = [var.depends_on_kv_mount]

  path = "secret/mongo-db"

  data_json = <<EOT
    {
      "DB_ADMIN_USER"         : "cristian",
      "DB_ADMIN_PASS"         : "cristianPassword2017",
      "DB_REPLICA_ADMIN"      : "replicaAdmin",
      "DB_REPLICA_ADMIN_PASS" : "replicaAdminPassword2017",
      "DB_REPLSET_NAME"       : "rs1",
      "MONG_KEYFILE"          : "${filebase64("${path.module}/mongo-keyfile")}"
    }
    EOT
}