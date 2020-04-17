variable "service_to_service_intentions" {
  default = []
}

variable "service_to_db_intentions" {
  default = []
}

variable "enable_deny_all" {
  default = false
}

variable "enable_intentions" {
  default = false
}

locals {
  service_to_service = flatten([for s in var.service_to_service_intentions: [for d in s.destination: { "source": s.source, "destination": d }]])
  service_to_db      = flatten([for s in var.service_to_db_intentions: [for d in s.destination: { "source": s.source, "destination": d }]])
  intentions         = concat(local.service_to_service, local.service_to_db)
}

resource "consul_intention" "allow-service-to-service" {
  count = var.enable_intentions ? length(local.intentions) : 0

  source_name      = local.intentions[count.index].source
  destination_name = local.intentions[count.index].destination
  action           = "allow"
}

resource "consul_intention" "deny-all" {
  count = var.enable_deny_all ? 1 : 0
  
  source_name      = "*"
  destination_name = "*"
  action           = "deny"
}