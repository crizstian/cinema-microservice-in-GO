variable "enable_mesh_gateway_policy" {
  default = false
}

resource "consul_acl_policy" "acl_mesh-gateway-policy" {
  count = var.enable_mesh_gateway_policy ? 1 : 0

  name        = "mesh-gateway-policy"
  datacenters = var.datacenters
  description = "Policy to use for mesh-gateway capabilities"
  
  rules = <<-RULE
    service_prefix "gateway" {
      policy = "write"
    }
    service_prefix "" {
      policy = "read"
    }
    node_prefix "" {
      policy = "read"
    }
    agent_prefix "" {
      policy = "read"
    }
  RULE
}
