module "auth-methods" {
  source = "./auth-methods"
  
  enable_app_role                = var.enable_app_role
  enable_store_approle_in_consul = var.enable_store_approle_in_consul
  enable_userpass_engine         = var.enable_userpass_engine
  
  app_roles                      = var.app_roles
  consul_datacenter              = var.consul_datacenter
}

module "entities" {
  source = "./entities"
  
  consul_datacenter                = var.consul_datacenter
  userpass_accessor                = module.auth-methods.userpass_accessor

  enable_userpass_entity           = var.enable_userpass_entity
  enable_store_entity_id_in_consul = var.enable_store_entity_id_in_consul
  users                            = var.users

  enable_identity_group = var.enable_identity_group
  groups                = var.groups
}

module "policies" {
  source = "./policies"

  enable_admin_policy                   = var.enable_admin_policy
  enable_edu_admin_policy               = var.enable_edu_admin_policy
  enable_technology-ops_us_admin_policy = var.enable_technology-ops_us_admin_policy
  enable_clgx-cicd_admin_policy         = var.enable_clgx-cicd_admin_policy
  
  enable_infrastructure_policy    = var.enable_infrastructure_policy
  enable_clgx-cicd_policy         = var.enable_clgx-cicd_policy
  enable_technology-ops_us_policy = var.enable_technology-ops_us_policy

  enable_app_policy = var.enable_app_policy
  policy_apps       = var.policy_apps
}

module "secrets" {
  source = "./secrets"

  enable_kv_engine = var.enable_kv_engine
  
  enable_consul_engine  = var.enable_consul_engine
  consul_token          = var.consul_token
  consul_address        = var.consul_address
  consul_scheme         = var.consul_scheme

  enable_mongo_db_engine  = var.enable_mongo_db_engine
  allowed_roles           = var.allowed_roles
  mongo_username          = var.mongo_username
  mongo_password          = var.mongo_password
  mongo_ip                = var.mongo_ip
  mongo_port              = var.mongo_port
  connection_url          = var.connection_url

  enable_gcp_engine = var.enable_gcp_engine
  gcp_root_project  = var.gcp_root_project
  gcp_root_creds    = var.gcp_root_creds

  enable_gcp_devops_sa  = var.enable_gcp_devops_sa
  enable_gcp_storage_sa = var.enable_gcp_storage_sa
}

module "generic-endpoints" {
  source = "./generic-endpoints"

  depends_on_kv_mount                = module.secrets.depends_on_kv_mount
  depends_on_consul_mount            = module.secrets.depends_on_consul_mount
  depends_on_userpass_mount          = module.auth-methods.depends_on_userpass_mount

  deploy_cinema_microservice_secrets = var.deploy_cinema_microservice_secrets
  deploy_mongodb_secrets             = var.deploy_mongodb_secrets
  users                              = var.users
}

module "namespaces" {
  source = "./namespaces"

  enable_namespaces = var.enable_namespaces
  namespaces        = var.namespaces
}