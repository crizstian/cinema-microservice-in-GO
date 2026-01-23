variable "enable_identity_group" {}
variable "groups" {}

resource "vault_identity_group" "group" {
  count = var.enable_identity_group ? length(var.groups) : 0
  name              = var.groups[count.index].name
  type              = var.groups[count.index].type
  policies          = var.groups[count.index].policies
  member_entity_ids = var.groups[count.index].member_entity_ids

  metadata = {
    version = "1"
  }
}

locals {
  
}