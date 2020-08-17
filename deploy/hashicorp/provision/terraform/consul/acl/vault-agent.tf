variable "enable_vault_agent_policy" {
  default = false
}

resource "consul_acl_policy" "vault-agent-policy" {
  count = var.enable_vault_agent_policy ? 1 : 0

  name        = "vault-agent"
  datacenters = var.datacenters
  description = "Vault agent policy"
  rules       = <<-RULE
    key_prefix "vault/" {
      policy = "write"
    }
    service_prefix "vault" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    node_prefix "" {
      policy = "write"
    }
    agent_prefix "" {
      policy = "write"
    }
  RULE
}