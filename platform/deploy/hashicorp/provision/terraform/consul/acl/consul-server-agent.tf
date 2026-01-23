variable "enable_consul_server_agent_policy" {
  default = false
}

resource "consul_acl_role" "server-role" {
  count = var.enable_consul_server_agent_policy ? 1 : 0

  name = "consul-server-agent"
  description = "consul server agent"
}