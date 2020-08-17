module "tf_consul" {
  source = "../../consul"

  datacenters = var.consul_datacenters
  store_kv    = [{
    path  = "cluster/info/status"
    value = "active"
  }]
  enabled_prepared_queries = true
  prepared_queries         = var.prepared_queries

  # ACL system
  create_consul_gossip_encryption_key = true
  create_consul_master_token          = true

  enable_anonymous_policy             = true
  enable_consul_server_agent_policy   = true
  enable_consul_snapshot_agent_policy = true
  enable_consul_vault_agent_policy    = true
  enable_mesh_gateway_policy          = true
  enable_replication_policy           = true
  enable_vault_agent_policy           = true

  # Consul Connect
  enable_intentions             = true
  enable_deny_all               = true
  service_to_service_intentions = var.service_to_service_intentions
 
  # Consul Central Config
  consul_central_config   = var.central_config_apps
  proxy_defaults          = var.proxy_defaults
  enable_proxy_defaults   = false
  enable_service_splitter = false
  enable_service_resolver = false
  enable_service_defaults = false

  custom_kv_acl = concat(var.apps, var.dbs)
}

module "tf_vault" {
  source = "../../vault"

  consul_datacenter = var.consul_datacenter
  enable_namespaces = false
  vault_namespaces  = [
    "prod",
    "preprod",
    "sandbox",
  ]

  # Vault Auth Methods
  enable_app_role                = true
  enable_userpass_engine         = true
  enable_store_approle_in_consul = true
    
  # Vault Policies
  enable_admin_policy            = true
  enable_infrastructure_policy   = true
  enable_app_policy              = true
  policy_apps                    = concat(var.apps, var.dbs)
  
  # Vault Engines
  enable_consul_engine           = false
  enable_kv_engine               = true
  enable_mongo_db_engine         = false
  enable_admin_user              = true

  # Vault Entities    
  enable_userpass_entity           = false
  enable_store_entity_id_in_consul = false
  vault_users                      = var.vault_users

  # Configurations
  app_roles                          = concat(var.apps, var.infrastructure, var.dbs)
  deploy_cinema_microservice_secrets = true
  deploy_mongodb_secrets             = true
}

output "consul_custom_kv_token" {
  value = module.tf_consul.consul_custom_kv_token
}