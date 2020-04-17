variable "prepared_queries" {
  default = []
}

variable "enabled_prepared_queries" {
  default = false
}

resource "consul_prepared_query" "prepared-query" {
  count = var.enabled_prepared_queries ? length(var.prepared_queries) : 0

  name         = can(var.prepared_queries[count.index].name) ? var.prepared_queries[count.index].name : var.prepared_queries[count.index].service
  near         = "_agent"
  service      = var.prepared_queries[count.index].service

  failover {
    nearest_n   = 3
    datacenters = var.prepared_queries[count.index].failover_dcs
  }
}