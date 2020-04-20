variable "app_config_services" {
  default = []
}

resource "consul_config_entry" "service-resolver" {
  count = length(local.resolver) > 0 ? length(local.resolver) : 0
  
  name = var.app_config_services[count.index].name
  kind = "service-resolver"

  config_json = jsonencode(local.resolver[count.index].service_resolver)
}

locals {
  resolver  = flatten([for i, s in var.app_config_services: can(s.service_resolver) ? [s] : []])
}