variable "enable_agent_policy" {
  default = false
}

variable "datacenters" {
  default = []
}

resource "consul_acl_policy" "agent-policy" {
  count = var.enable_agent_policy ? 1 : 0

  name        = "agent-policy"
  datacenters = var.datacenters
  description = "Policy to use for Agent capabilities"
  
  rules       = <<-RULE
    node "" { 
      policy = "write"
    } 
    agent "" { 
      policy = "write"
    } 
    event "" { 
      policy = "write"
    } 
    key "" { 
      policy = "write"
    } 
    query "" { 
      policy = "write"
    } 
    service "" { 
      policy     = "write"
      intentions = "write"
    } 
    session "" { 
      policy = "write"
    }
  RULE
}