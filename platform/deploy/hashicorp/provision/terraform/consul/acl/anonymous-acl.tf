variable "enable_anonymous_policy" {
  default = false
}
variable "datacenters" {
  default = []
}

resource "consul_acl_policy" "anonymous-policy" {
  count = var.enable_anonymous_policy ? 1 : 0

  name        = "anonymous-policy"
  datacenters = var.datacenters
  description = "Anonymous Policy"

  rules = <<-RULE
    node_prefix "" {
      policy = "read"
    }
    service_prefix "" {
      policy = "read"
    }
    session_prefix "" {
      policy = "read"
    }
    agent_prefix "" {
      policy = "read"
    }
    query_prefix "" {
      policy = "read"
    }
    operator = "read"
  RULE
}
