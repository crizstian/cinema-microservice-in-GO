module "auth-methods" {
  source = "./auth-methods"
  
  enable_app_role                = var.enable_app_role
  enable_store_approle_in_consul = var.enable_store_approle_in_consul
  enable_userpass_engine         = var.enable_userpass_engine
  
  roles                          = var.roles
  consul_datacenter              = var.consul_datacenter
}

module "policies" {
  source = "./policies"

  enable_admin_policy          = var.enable_admin_policy
  enable_infrastructure_policy = var.enable_infrastructure_policy
  enable_app_policy            = var.enable_app_policy
  
  policy_apps                  = var.policy_apps
}

module "secrets" {
  source = "./secrets"

  enable_consul_engine   = var.enable_consul_engine
  enable_kv_engine       = var.enable_kv_engine
  enable_mongo_db_engine = var.enable_mongo_db_engine
}

module "generic-endpoints" {
  source = "./generic-endpoints"

  depends_on_kv_mount       = module.secrets.depends_on_kv_mount
  depends_on_consul_mount   = module.secrets.depends_on_consul_mount
  depends_on_userpass_mount = module.auth-methods.depends_on_userpass_mount

  deploy_cinema_microservice_secrets = var.deploy_cinema_microservice_secrets
  deploy_mongodb_secrets             = var.deploy_mongodb_secrets
  enable_admin_user                  = var.enable_admin_user
}