variable "enable_blocking_policy" {
  default = false
}

resource "consul_acl_policy" "blocking-policy" {
  count = var.enable_blocking_policy ? 1 : 0

  name        = "blocking-policy"
  datacenters = var.datacenters
  description = "Policy to use for blocking access to restricted operations"
  rules       = <<-RULE
    key_prefix "cluster/consul/" {
      policy = "deny"
    }
    key_prefix "cluster/vault/" {
      policy = "deny"
    }
    key_prefix "vault/" {
      policy = "deny"
    }
    acl      = "deny"
    keyring  = "deny"
    operator = "deny"
    RULE
}