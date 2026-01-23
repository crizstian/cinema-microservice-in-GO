resource "vault_generic_secret" "movie-service" {
  count = var.deploy_cinema_microservice_secrets ? 1 : 0
  
  depends_on = [var.depends_on_kv_mount]

  path = "secret/movie-service"

  data_json = <<EOT
    {
      "DB_USER":    "cristian",
      "DB_PASS":    "cristianPassword2017",
      "DB_NAME":    "movies",
      "DB_REPLICA": "rs1"
    }
    EOT
}