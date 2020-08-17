variable "datacenters" {
  default = []
}

# ACL system
variable "create_consul_gossip_encryption_key" {
  default = false
}
variable "create_consul_master_token" {
  default = false
}
variable "enable_anonymous_policy" {
  default = false
}
variable "enable_consul_server_agent_policy" {
  default = false
}
variable "enable_consul_snapshot_agent_policy" {
  default = false
}
variable "enable_consul_vault_agent_policy" {
  default = false
}
variable "enable_mesh_gateway_policy" {
  default = false
}
variable "enable_replication_policy" {
  default = false
}
variable "enable_vault_agent_policy" {
  default = false
}

# Consul Connect
variable "service_to_service_intentions" {
  default = []
}
variable "service_to_db_intentions" {
  default = []
}
variable "enable_deny_all" {
  default = false
}
variable "enable_intentions" {
  default = false
}


variable "prepared_queries" {
  default = []
}

variable "enabled_prepared_queries" {
  default = false
}

variable "store_kv" {
  default = []
}

variable "external_services" {
  default = []
}
variable "datacenter" {
  default = ""
}


# Consul Central Config
variable "consul_central_config" {
  default = {
    service_defaults = []
    service_resolver = []
  }
}

variable "proxy_defaults" {
  default = ""
}
variable "enable_proxy_defaults" {
  default = false
}
variable "enable_service_splitter" {
  default = false
}
variable "enable_service_resolver" {
  default = false
}
variable "enable_service_defaults" {
  default = false
}

variable "custom_kv_acl" {
  default = []
}