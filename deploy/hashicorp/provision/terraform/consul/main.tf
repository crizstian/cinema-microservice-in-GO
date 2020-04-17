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