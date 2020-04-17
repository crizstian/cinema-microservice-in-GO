variable "enable_anonymous_policy" {
  default = false
}

resource "consul_acl_policy" "anonymous-policy" {
  count = var.enable_anonymous_policy ? 1 : 0

  name        = "anonymous-policy"
  datacenters = var.datacenters
  description = "Policy to use for read only capabilities"
  rules       = <<-RULE
    node "" { 
      policy = "read"
    } 
    agent "" { 
      policy = "read"
    } 
    event "" { 
      policy = "read"
    } 
    key "" { 
      policy = "read"
    } 
    query "" { 
      policy = "read"
    } 
    service "" { 
      policy     = "read"
      intentions = "deny"
    } 
    session "" { 
      policy = "read"
    }
  RULE
}
