variable "enable_service_resolver" {
  default = false
}
variable "app_config_services" {
  default = []
}

resource "consul_config_entry" "service-resolver" {
  count = var.enable_service_resolver && length(var.app_config_services) > 0 ? length(var.app_config_services) : 0
  
  name = var.app_config_services[count.index].name
  kind = "service-resolver"

  config_json = jsonencode(var.app_config_services[count.index].config)
}

// locals {
//   resolver  = flatten([for i, s in var.app_config_services: s if can(s.service_resolver) ])
// }