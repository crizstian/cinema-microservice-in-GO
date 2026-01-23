variable "depends_on_kv_mount" {}
variable "deploy_cinema_microservice_secrets" {}

resource "vault_generic_secret" "booking-service" {
  count = var.deploy_cinema_microservice_secrets ? 1 : 0
  
  depends_on = [var.depends_on_kv_mount]

  path = "secret/booking-service"

  data_json = <<EOT
    {
      "DB_USER":    "cristian",
      "DB_PASS":    "cristianPassword2017",
      "DB_NAME":    "booking",
      "DB_REPLICA": "rs1"
    }
    EOT
}