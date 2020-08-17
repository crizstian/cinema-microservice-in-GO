variable "enable_consul_snapshot_agent_policy" {
  default = false
}

resource "consul_acl_policy" "consul-snapshot-agent-policy" {
  count = var.enable_consul_snapshot_agent_policy ? 1 : 0

  name        = "consul-snapshot-agent"
  datacenters = var.datacenters
  description = "Consul snapshot agent policy"
  
  rules       = <<-RULE
    acl = "write"
    key "consul-snapshot/lock" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    service "consul-snapshot" {
      policy = "write"
    }
  RULE
}