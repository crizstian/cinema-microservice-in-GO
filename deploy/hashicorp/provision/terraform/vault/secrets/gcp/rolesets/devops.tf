variable "gcp_backend" {}
variable "gcp_root_project" {}
variable "enable_gcp_devops_sa" {}

resource "vault_gcp_secret_roleset" "devops-sa" {
  count = var.enable_gcp_devops_sa ? 1 : 0
  
  backend      = var.gcp_backend
  roleset      = "devops-roleset"
  secret_type  = "access_token"
  project      = var.gcp_root_project
  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${var.gcp_root_project}"

    roles = [
      "roles/compute.admin",
    ]
  }
}