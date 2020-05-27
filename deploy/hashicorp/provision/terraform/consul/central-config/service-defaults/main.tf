variable "enable_service_defaults" {
  default = false
}
variable "app_config_services" {
  default = []
}

resource "consul_config_entry" "service-defaults" {
  count = var.enable_service_defaults && length(var.app_config_services) > 0 ? length(var.app_config_services) : 0
  
  name = var.app_config_services[count.index].name
  kind = "service-defaults"

  config_json = jsonencode({
    Protocol    = "http"
    MeshGateway = {
      Mode = var.app_config_services[count.index].mesh_resolver
    }
  })
}