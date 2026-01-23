variable "external_services" {
  default = []
}

variable "datacenter" {
  default = []
}

resource "consul_node" "external_node" {
  count = length(var.external_services) > 0 ? length(var.external_services) : 0

  name    = var.external_services[count.index].name
  address = var.external_services[count.index].address
}

resource "consul_service" "external_service" {
  count = length(var.external_services) > 0 ? length(var.external_services) : 0

  name = var.external_services[count.index].name
  node = consul_node.external_node[count.index].name
  port = var.external_services[count.index].port
  tags = var.external_services[count.index].tags
  datacenter = var.datacenter
}