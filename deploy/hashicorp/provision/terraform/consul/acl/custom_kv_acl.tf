variable "custom_kv_acl" {}

resource "consul_acl_policy" "custom_kv_acl" {
  count = length(var.custom_kv_acl) > 0 ? length(var.custom_kv_acl) : 0

  name        = "${var.custom_kv_acl[count.index]}-policy"
  datacenters = var.datacenters
  description = "${var.custom_kv_acl[count.index]} policy"
  
  rules       = <<-RULE
    key_prefix "cluster/apps/${var.custom_kv_acl[count.index]}/" { 
      policy = "write"
    } 
    key "cluster/info/status" { 
      policy = "read"
    } 
    agent_prefix "" {
      policy = "read"
    }
    session_prefix "" {
      policy = "write"
    }
    service_prefix "" {
      policy = "write"
    } 
    query_prefix "" {
      policy = "write"
    }
  RULE
}

resource "consul_acl_token" "custom_kv" {
  count = length(var.custom_kv_acl) > 0 ? length(var.custom_kv_acl) : 0
  
  description = "${var.custom_kv_acl[count.index]}-token"
  policies = ["${consul_acl_policy.custom_kv_acl[count.index].name}"]
  local = true
}

resource "consul_keys" "custom_kv_token" {
  count = length(var.custom_kv_acl) > 0 ? length(var.custom_kv_acl) : 0

  datacenter = var.datacenters[0]

  key {
    path  = "cluster/apps/${var.custom_kv_acl[count.index]}/auth/token"
    value = data.consul_acl_token_secret_id.read[count.index].secret_id 
  }
}

data "consul_acl_token_secret_id" "read" {
  count = length(var.custom_kv_acl) > 0 ? length(var.custom_kv_acl) : 0
  accessor_id = consul_acl_token.custom_kv[count.index].accessor_id
}


output "consul_custom_kv_token" {
  value = length(var.custom_kv_acl) > 0 ? [for i, o in data.consul_acl_token_secret_id.read : {"App": var.custom_kv_acl[i], "Token": o.secret_id  }] : [{"none": "none"}]
}