provider "vault" {
  namespace = "sbx/technology-ops_us"
  alias     = "sbxtechops"
}
provider "vault" {
  namespace = "sbx/clgx-cicd"
  alias     = "sbxclgx"
}
provider "consul" {
  address    = var.consul_address
  datacenter = var.consul_datacenter
  scheme     = var.consul_scheme
}

terraform {
  backend "consul" {}
}
