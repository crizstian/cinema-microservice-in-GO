variable "enable_service_splitter" {
  default = false
}
variable "app_config_services" {
  default = []
}

resource "consul_config_entry" "service-splitter" {
  count = var.enable_service_splitter && length(local.splitter) > 0 ? length(local.splitter) : 0
  
  name = local.splitter[count.index].name
  kind = "service-splitter"

  config_json = jsonencode(local.splitter[count.index].service_splitter)
}

locals {
  splitter  = flatten([for i, s in var.app_config_services: can(s.service_splitter) ? [s] : []])
}