variable "consul_central_config" {
  default = []
}
variable "proxy_defaults" {
  default = ""
}
variable "enable_proxy_defaults" {
  default = false
}

module "service-defaults" {
  source = "./service-defaults"

  app_config_services = var.consul_central_config
}

module "service-resolver" {
  source = "./service-resolver"

  app_config_services = var.consul_central_config
}

module "service-splitter" {
  source = "./service-splitter"

  app_config_services = var.consul_central_config
}

module "proxy-defaults" {
  source = "./proxy-defaults"

  proxy_defaults        = var.proxy_defaults
  enable_proxy_defaults = var.enable_proxy_defaults
}