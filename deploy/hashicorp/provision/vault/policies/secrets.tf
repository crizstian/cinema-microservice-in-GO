resource "vault_generic_endpoint" "admin-user" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin-policy", "default"],
  "password": "admin"
}
EOT
}

# NOT GOOD PRACTICE TO STORE SECRETS; THIS IS FOR DEMO PURPOSES
resource "vault_generic_secret" "movie-service" {
  depends_on = [vault_mount.secret-kv]

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

resource "vault_generic_secret" "booking-service" {
  depends_on = [vault_mount.secret-kv]

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

resource "vault_generic_secret" "payment-service" {
  depends_on = [vault_mount.secret-kv]

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

resource "vault_generic_secret" "notification-service" {
  depends_on = [vault_mount.secret-kv]

  path = "secret/notification-service"

  data_json = <<EOT
    {
      "EMAIL": "crr.developer.9@gmail.com",
      "EMAIL_PASS": "Cris123#"
    }
    EOT
}


