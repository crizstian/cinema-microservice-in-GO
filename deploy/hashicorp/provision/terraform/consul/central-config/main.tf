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

module "service-defaults" {
  source = "./service-defaults"

  enable_service_defaults = var.enable_service_defaults
  app_config_services     = var.consul_central_config
}

module "service-resolver" {
  source = "./service-resolver"

  enable_service_resolver = var.enable_service_resolver
  app_config_services     = var.consul_central_config
}

module "service-splitter" {
  source = "./service-splitter"

  enable_service_splitter = var.enable_service_splitter
  app_config_services     = var.consul_central_config
}

module "proxy-defaults" {
  source = "./proxy-defaults"

  proxy_defaults        = var.proxy_defaults
  enable_proxy_defaults = var.enable_proxy_defaults
}