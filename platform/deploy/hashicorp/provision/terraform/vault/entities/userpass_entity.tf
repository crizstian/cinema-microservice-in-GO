variable "enable_userpass_entity" {}
variable "users" {}
variable "userpass_accessor" {}
variable "enable_store_entity_id_in_consul" {}
variable "consul_datacenter" {}

resource "vault_identity_entity" "entity" {
  count    = var.enable_userpass_entity ? length(var.users) : 0
  
  name     = var.users[count.index].entity_name
  policies = var.users[count.index].policies
  metadata = var.users[count.index].metadata
}

resource "vault_identity_entity_alias" "userpass" {
  count          = var.enable_userpass_entity ? length(var.users) : 0
  
  name           = var.users[count.index].user
  mount_accessor = var.userpass_accessor
  canonical_id   = vault_identity_entity.entity[count.index].id
}


locals {
  technology-ops_us_admin_entities = flatten([for entity in vault_identity_entity.entity : entity.id if (entity.metadata.type == "admin" && (entity.metadata.group == "technology-ops_us" || entity.metadata.group == "root"))])
  technology-ops_us_user_entities  = flatten([for entity in vault_identity_entity.entity : entity.id if (entity.metadata.type != "admin" && entity.metadata.group == "technology-ops_us")])
  
  clgx-cicd_admin_entities = flatten([for entity in vault_identity_entity.entity : entity.id if (entity.metadata.type == "admin" && (entity.metadata.group == "clgx-cicd" || entity.metadata.group == "root"))])
  clgx-cicd_user_entities  = flatten([for entity in vault_identity_entity.entity : entity.id if (entity.metadata.type != "admin" && entity.metadata.group == "clgx-cicd")])
  
  entities = [{
      path     = "vault-operator/technology-ops_us/admin-entities"
      entities = local.technology-ops_us_admin_entities
    }, {
      path     = "vault-operator/technology-ops_us/user-entities"
      entities = local.technology-ops_us_user_entities
  },{
      path     = "vault-operator/clgx-cicd/admin-entities"
      entities = local.clgx-cicd_admin_entities
    }, {
      path     = "vault-operator/clgx-cicd/user-entities"
      entities = local.clgx-cicd_user_entities
  }]
}

resource "consul_keys" "secret-id" {
  count = var.enable_store_entity_id_in_consul ? length(local.entities) : 0

  datacenter = var.consul_datacenter

  key {
    path  = local.entities[count.index].path
    value = jsonencode(local.entities[count.index].entities)
  }
}