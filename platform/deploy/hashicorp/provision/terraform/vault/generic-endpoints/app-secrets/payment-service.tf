resource "vault_generic_secret" "payment-service" {
  count = var.deploy_cinema_microservice_secrets ? 1 : 0
  
  depends_on = [var.depends_on_kv_mount]

  path = "secret/payment-service"

  data_json = <<EOT
    {
      "DB_USER":    "cristian",
      "DB_PASS":    "cristianPassword2017",
      "DB_NAME":    "payment",
      "DB_REPLICA": "rs1",
      "STRIPE_SECRET": "sk_test_lPPoJjmmbSjymtgo4r0O3z89",
      "STRIPE_PUBLIC": "pk_test_l10342hIODZmOJsBpY6GVPHj"
    }
    EOT
}