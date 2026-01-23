resource "vault_generic_secret" "notification-service" {
  count = var.deploy_cinema_microservice_secrets ? 1 : 0
  
  depends_on = [var.depends_on_kv_mount]

  path = "secret/notification-service"

  data_json = <<EOT
    {
      "EMAIL": "crr.developer.9@gmail.com",
      "EMAIL_PASS": "Cris123#"
    }
    EOT
}
