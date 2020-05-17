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
variable "deploy_mongodb_secrets" {
  default = false
}
