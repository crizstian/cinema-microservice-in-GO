variable "enable_gcp_engine" {}
variable "gcp_root_project" {}
variable "gcp_root_creds" {}

variable "enable_gcp_devops_sa" {}
variable "enable_gcp_storage_sa" {}

resource "vault_gcp_secret_backend" "gcp" {
  count = var.enable_gcp_engine ? 1 : 0
  
  path        = "gcp"
  credentials = file(var.gcp_root_creds)
}

module "rolesets" {
  source = "./gcp/rolesets"

  gcp_backend                 = var.enable_gcp_engine ? vault_gcp_secret_backend.gcp.0.path : ""
  gcp_root_project            = var.gcp_root_project
  enable_gcp_devops_sa        = var.enable_gcp_devops_sa
  enable_gcp_storage_sa = var.enable_gcp_storage_sa
}