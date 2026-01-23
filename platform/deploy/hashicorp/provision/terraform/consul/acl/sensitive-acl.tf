variable "enable_sensitive_policy" {
  default = false
}

resource "consul_acl_policy" "sensitive-policy" {
  count = var.enable_sensitive_policy ? 1 : 0

  name        = "sensitive-policy"
  datacenters = var.datacenters
  description = "Policy to use to get access to sensitive capabilities"
  rules       = <<-RULE
    key_prefix "cluster/consul/" {
      policy = "write"
    }
    key_prefix "cluster/vault/" {
      policy = "write"
    }
    key_prefix "vault/" {
      policy = "write"
    }
    acl      = "write"
    keyring  = "write"
    operator = "write"
  RULE
}