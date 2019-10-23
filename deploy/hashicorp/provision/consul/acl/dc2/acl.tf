provider "consul" {
  address    = "172.20.20.31:8500"
  datacenter = "dc1", "dc2"
}

resource "consul_acl_policy" "server-policy" {
  name        = "server-policy"
  datacenters = ["dc1", "dc2"]
  description = "Policy to use for Server capabilities"
  rules       = <<-RULE
    node "" {
      policy = "write"
    }
    key_prefix "vault/" { 
      policy = "write"
    } 
    RULE
}

resource "consul_acl_policy" "agent-policy" {
  name        = "agent-policy"
  datacenters = ["dc1", "dc2"]
  description = "Policy to use for Agent capabilities"
  rules       = <<-RULE
    node "" { 
      policy = "write"
    } 
    agent "" { 
      policy = "write"
    } 
    event "" { 
      policy = "write"
    } 
    key "" { 
      policy = "write"
    } 
    query "" { 
      policy = "write"
    } 
    service "" { 
      policy     = "write"
      intentions = "write"
    } 
    session "" { 
      policy = "write"
    }
    RULE
}

resource "consul_acl_policy" "anonymous-policy" {
  name        = "anonymous-policy"
  datacenters = ["dc1", "dc2"]
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

resource "consul_acl_policy" "sensitve-policy" {
  name        = "sensitve-policy"
  datacenters = ["dc1", "dc2"]
  description = "Policy to use to get access to sensitve capabilities"
  rules       = <<-RULE
    key_prefix "cluster/consul/" {
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

resource "consul_acl_policy" "blocking-policy" {
  name        = "blocking-policy"
  datacenters = ["dc1", "dc2"]
  description = "Policy to use for blocking access to restricted operations"
  rules       = <<-RULE
    key_prefix "cluster/consul/" {
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



resource "consul_acl_policy" "agent-prefix-policy" {
  name        = "agent-prefix-policy"
  datacenters = ["dc1", "dc2"]
  description = "Policy to use for Agent capabilities"
  rules       = <<-RULE
    node_prefix "" { 
      policy = "write"
    } 
    agent_prefix "" { 
      policy = "write"
    } 
    event_prefix "" { 
      policy = "write"
    } 
    key_prefix "" { 
      policy = "write"
    } 
    query_prefix "" { 
      policy = "write"
    } 
    service_prefix "" { 
      policy     = "write"
      intentions = "write"
    } 
    session_prefix "" { 
      policy = "write"
    }
    RULE
}