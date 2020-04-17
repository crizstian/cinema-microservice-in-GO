variable "datacenters" {
  default = ["dc1", "dc2"]
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