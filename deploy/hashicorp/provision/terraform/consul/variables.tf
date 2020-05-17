variable "datacenters" {
  default = []
}
variable "enable_agent_policy" {
  default = false
}
variable "enable_anonymous_policy" {
  default = false
}
variable "enable_sensitive_policy" {
  default = false
}
variable "enable_blocking_policy" {
  default = false
}
variable "enable_server_role" {
  default = false
}

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

variable "consul_central_config" {
  default = []
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