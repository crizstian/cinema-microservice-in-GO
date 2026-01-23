variable "kv" {
  default = []
}

variable "datacenter" {
  default = ""
}

resource "consul_keys" "cluster_status" {
  count = length(var.kv) > 0 ? length(var.kv) : 0

  datacenter = var.datacenter

  key {
    path  = var.kv[count.index].path
    value = var.kv[count.index].value
  }
}