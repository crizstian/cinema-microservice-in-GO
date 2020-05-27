variable "enable_service_resolver" {
  default = false
}
variable "app_config_services" {
  default = []
}

resource "consul_config_entry" "service-resolver" {
  count = var.enable_service_resolver && length(local.resolver) > 0 ? length(local.resolver) : 0
  
  name = var.app_config_services[count.index].name
  kind = "service-resolver"

  config_json = jsonencode(local.resolver[count.index].service_resolver)
}

locals {
  resolver  = flatten([for i, s in var.app_config_services: s if can(s.service_resolver) ])
}