variable "enable_consul_vault_agent_policy" {
  default = false
}

resource "consul_acl_policy" "consul-vault-agent-policy" {
  count = var.enable_consul_vault_agent_policy ? 1 : 0

  name        = "consul-vault-agent"
  datacenters = var.datacenters
  description = "Consul Vault agent policy"
  
  rules       = <<-RULE
    node_prefix "" { 
      policy = "write"
    } 
    agent_prefix "" { 
      policy = "write"
    } 
    service_prefix "" { 
      policy     = "read"
    } 

  RULE
}