provider "vault" {
  namespace = "sbx"
  alias     = "sbx"
}

terraform {
  backend "consul" {}
}

module "tf_vault_ENV1" {
  source = "../../vault"
  
  enable_namespaces = true
  namespaces        = [
    "technology-ops_us",
    "clgx-cicd",
  ]

  providers = {
    vault = vault.sbx
  }
}