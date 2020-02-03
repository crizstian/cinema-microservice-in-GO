resource "consul_acl_role" "server-role" {
    name = "server-role"
    description = "server role includes agent and sensitive policies in order to handle sensitve operations."

    policies = [
        consul_acl_policy.agent-policy.id,
        consul_acl_policy.sensitive-policy.id
    ]
}