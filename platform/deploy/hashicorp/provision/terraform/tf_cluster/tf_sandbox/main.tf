provider "vault" {
  namespace = "sandbox"
  alias     = "sbx"
}

terraform {
  backend "consul" {}
}

module "tf_vault_sandbox" {
  source = "../../vault"
  
  enable_namespaces = true
  namespaces        = [
    "devops",
    "innovation",
  ]

  providers = {
    vault = vault.sbx
  }
}