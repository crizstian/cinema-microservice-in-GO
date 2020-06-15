module "app-secrets" {
  source = "./app-secrets"

  depends_on_kv_mount                = var.depends_on_kv_mount  
  deploy_cinema_microservice_secrets = var.deploy_cinema_microservice_secrets
}

module "consul" {
  source = "./consul-secrets"

  depends_on_consul_mount          = var.depends_on_consul_mount
  generate_server_token            = var.generate_server_token
  upload_server_token_to_consul_kv = var.upload_server_token_to_consul_kv
  consul_datacenter                = var.consul_datacenter
}

module "userpass" {
  source = "./userpass"

  depends_on_userpass_mount = var.depends_on_userpass_mount
  users                     = var.users
}

module "mongo-secrets" {
  source = "./mongo-secrets"

  depends_on_kv_mount    = var.depends_on_kv_mount
  deploy_mongodb_secrets = var.deploy_mongodb_secrets
}


