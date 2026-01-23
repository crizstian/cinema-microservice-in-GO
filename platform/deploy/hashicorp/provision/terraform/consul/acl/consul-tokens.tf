variable "create_consul_gossip_encryption_key" {
  default = false
}
variable "create_consul_master_token" {
  default = false
}

resource "random_uuid" "consul_master_token" {
  count = var.create_consul_master_token ? 1 : 0
}
resource "random_uuid" "vault_agent_token" {
  count = var.enable_vault_agent_policy ? 1 : 0
}
resource "random_uuid" "consul_agent_server_token" {
  count = var.enable_consul_server_agent_policy ? 1 : 0
}
resource "random_uuid" "consul_vault_agent_token" {
  count = var.enable_consul_vault_agent_policy ? 1 : 0
}
resource "random_uuid" "consul_snapshot_token" {
  count = var.enable_consul_snapshot_agent_policy ? 1 : 0
}
resource "random_uuid" "consul_replication_token" {
  count = var.enable_replication_policy ? 1 : 0
}
resource "random_uuid" "consul_mesh_gw_token" {
  count = var.enable_mesh_gateway_policy ? 1 : 0
}

resource "random_id" "consul_gossip_encryption_key" {
  count = var.create_consul_gossip_encryption_key ? 1 : 0
  byte_length = 32
}