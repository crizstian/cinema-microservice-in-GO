locals {
  technology-ops_us-groups = [
    merge(var.technology-ops_us-admin, {member_entity_ids: jsondecode(data.consul_keys.technology-ops_us-admin-entities.var.entities)}),
    merge(var.technology-ops_us-user, {member_entity_ids: jsondecode(data.consul_keys.technology-ops_us-user-entities.var.entities)}),
  ]
  clgx-cicd-groups = [
    merge(var.clgx-cicd-admin, {member_entity_ids: jsondecode(data.consul_keys.clgx-cicd-admin-entities.var.entities)}),
    merge(var.clgx-cicd-group, {member_entity_ids: jsondecode(data.consul_keys.clgx-cicd-user-entities.var.entities)})
  ]
}

data "consul_keys" "technology-ops_us-admin-entities" {
  key {
    name    = "entities"
    path    = "vault-operator/technology-ops_us/admin-entities"
  }
}
data "consul_keys" "technology-ops_us-user-entities" {
  key {
    name    = "entities"
    path    = "vault-operator/technology-ops_us/user-entities"
  }
}

data "consul_keys" "clgx-cicd-admin-entities" {
  key {
    name    = "entities"
    path    = "vault-operator/clgx-cicd/admin-entities"
  }
}
data "consul_keys" "clgx-cicd-user-entities" {
  key {
    name    = "entities"
    path    = "vault-operator/clgx-cicd/user-entities"
  }
}

module "tf_vault_technology-ops_us" {
  source = "../../../vault"
  
  enable_technology-ops_us_admin_policy = true
  enable_technology-ops_us_policy       = true

  enable_identity_group          = true
  groups                         = local.technology-ops_us-groups

  enable_kv_engine               = true

  enable_gcp_engine              = true
  gcp_root_project               = "cl-70813983e33a"
  gcp_root_creds                 = "../../files/gcp.json"
  enable_gcp_devops_sa           = true

  providers = {
    vault = vault.sbxtechops
  }
}

module "tf_vault_clgx-cicd" {
  source = "../../../vault"
  
  enable_clgx-cicd_admin_policy = true
  enable_clgx-cicd_policy       = true
  
  enable_identity_group       = true
  groups                      = local.clgx-cicd-groups

  enable_kv_engine            = true

  enable_gcp_engine           = true
  gcp_root_project            = "cl-70813983e33a"
  gcp_root_creds              = "../../files/sbx-clgx-cicd.json"
  enable_gcp_storage_sa = true

  providers = {
    vault = vault.sbxclgx
  }
}