variable "enable_app_role" {
  default = false
}
variable "roles" {
  default = []
}
variable "enable_store_approle_in_consul" {
  default = false
}

variable "enable_consul_engine" {
  default = false
}
variable "consul_token" {
  default = ""
}
variable "consul_address" {
  default = ""
}
variable "consul_scheme" {
  default = ""
}
variable "enable_kv_engine" {
  default = false
}
variable "enable_mongo_db_engine" {
  default = false
}
variable "allowed_roles" {
  default = []
}
variable "mongo_username" {
  default = ""
}
variable "mongo_password" {
  default = ""
}
variable "mongo_ip" {
  default = ""
}
variable "mongo_port" {
  default = ""
}
variable "connection_url" {
  default = ""
}

variable "enable_admin_policy" {
  default = false
}
variable "enable_infrastructure_policy" {
  default = false
}
variable "enable_app_policy" {
  default = false
}
variable "policy_apps" {
  default = []
}

variable "depends_on_kv_mount" {
  default = ""
}
variable "deploy_cinema_microservice_secrets" {
  default = false
}
variable "depends_on_consul_mount" {
  default = ""
}
variable "generate_server_token" {
  default = false
}
variable "upload_server_token_to_consul_kv" {
  default = false
}
variable "consul_datacenter" {
  default = ""
}

variable "depends_on_userpass_mount" {
  default = ""
}
variable "enable_admin_user" {
  default = false
}
variable "enable_userpass_engine" {
  default = false
}