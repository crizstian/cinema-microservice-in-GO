module "tf_consul" {
  source = "../../consul"

  datacenters = var.consul_datacenters
  
  enable_agent_policy        = true
  enable_anonymous_policy    = true
  enable_sensitive_policy    = true
  enable_blocking_policy     = true
  enable_server_role         = true
  enable_replication_policy  = true
  enable_mesh_gateway_policy = true

  enable_intentions             = true
  enable_deny_all               = true
  service_to_service_intentions = var.service_to_service_intentions

  enabled_prepared_queries = true
  prepared_queries         = var.prepared_queries

  store_kv = [{
    path  = "cluster/info/status"
    value = "active"
  }]

  consul_central_config   = var.central_config_apps
  proxy_defaults          = var.proxy_defaults
  enable_proxy_defaults   = false
  enable_service_splitter = false
  enable_service_resolver = false
  enable_service_defaults = false
}

module "tf_vault" {
  source = "../../vault"

  enable_kv_engine                 = true
  enable_userpass_engine           = true
  enable_namespaces                = true
      
  enable_admin_policy              = true
  enable_infrastructure_policy     = true
  
  enable_userpass_entity           = true
  enable_store_entity_id_in_consul = true
  consul_datacenter                = var.consul_datacenter

  users      = var.users
  namespaces = [
    "prd",
    "nonprd",
    "sbx",
  ]
}