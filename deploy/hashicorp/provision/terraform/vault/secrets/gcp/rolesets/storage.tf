variable "enable_gcp_storage_sa" {}

resource "vault_gcp_secret_roleset" "cloud_storage-sa" {
  count = var.enable_gcp_storage_sa ? 1 : 0
  
  backend      = var.gcp_backend
  roleset      = "storage-roleset"
  secret_type  = "access_token"
  project      = var.gcp_root_project
  token_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

  binding {
    resource = "//cloudresourcemanager.googleapis.com/projects/${var.gcp_root_project}"

    roles = [
      "roles/storage.admin",
    ]
  }
}