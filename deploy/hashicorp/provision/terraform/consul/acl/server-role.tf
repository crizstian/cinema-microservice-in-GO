variable "enable_server_role" {
  default = false
}

resource "consul_acl_role" "server-role" {
  count = var.enable_server_role ? 1 : 0

  name = "server-role"
  description = "server role includes agent and sensitive policies in order to handle sensitve operations."

  policies = [
    consul_acl_policy.agent-policy.0.id,
    consul_acl_policy.sensitive-policy.0.id
  ]
}