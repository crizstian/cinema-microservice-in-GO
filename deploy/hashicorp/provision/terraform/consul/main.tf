module "acl" {
  source = "./acl"

  datacenters             = var.datacenters
  enable_agent_policy     = var.enable_agent_policy    
  enable_anonymous_policy = var.enable_anonymous_policy
  enable_sensitive_policy = var.enable_sensitive_policy
  enable_blocking_policy  = var.enable_blocking_policy 

  enable_server_role = var.enable_server_role
}

module "intentions" {
  source = "./intentions"

  service_to_service_intentions = var.service_to_service_intentions
  service_to_db_intentions      = var.service_to_db_intentions
  enable_deny_all               = var.enable_deny_all
  enable_intentions             = var.enable_intentions
}

module "prepared-queries" {
  source = "./prepared-queries"

  enabled_prepared_queries = var.enabled_prepared_queries
  prepared_queries         = var.prepared_queries
}

module "kv" {
  source = "./kv"

  kv         = var.store_kv
  datacenter = var.datacenters[0]
}

module "external-services" {
  source = "./external-services"

  external_services  = var.external_services
  datacenter         = var.datacenters[0]
}

module "central-config" {
  source = "./central-config"

  consul_central_config   = var.consul_central_config
  proxy_defaults          = var.proxy_defaults
  enable_proxy_defaults   = var.enable_proxy_defaults
  enable_service_splitter = var.enable_service_splitter
  enable_service_resolver = var.enable_service_resolver
  enable_service_defaults = var.enable_service_defaults
}