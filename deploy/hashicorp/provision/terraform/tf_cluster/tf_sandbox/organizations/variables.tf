variable "consul_address" {}
variable "consul_datacenter" {}
variable "consul_scheme" {}

variable "technology-ops_us-admin" {
  default = {
    name     = "technology-ops_us Admin"
    type     = "internal"
    policies = ["technology-ops_us-admin-policy"]
  }
}

variable "technology-ops_us-user" {
  default = {
    name     = "technology-ops_us DevOps"
    type     = "internal"
    policies = ["technology-ops_us-policy"]
  }
}

variable "clgx-cicd-admin" {
  default = {
    name     = "clgx-cicd Admin"
    type     = "internal"
    policies = ["clgx-cicd-admin-policy"]
  }
}

variable "clgx-cicd-group" {
  default = {
    name     = "clgx-cicd DevOps"
    type     = "internal"
    policies = ["clgx-cicd-policy"]
  }
}