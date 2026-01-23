variable "enable_replication_policy" {
  default = false
}

resource "consul_acl_policy" "acl_replication-policy" {
  count = var.enable_replication_policy ? 1 : 0

  name        = "replication-policy"
  datacenters = var.datacenters
  description = "Policy to use for acl_replication capabilities"
  
  rules = <<-RULE
    acl      = "write"
    operator = "write"

    service_prefix "" {
      policy     = "read"
      intentions = "read"
    }
  RULE
}