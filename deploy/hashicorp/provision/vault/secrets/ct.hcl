template {
  source          = "/vagrant/provision/vault/secrets/envconsul.hcl.tmpl"
  destination     = "/vagrant/provision/vault/secrets/envconsul.hcl"
  left_delimiter  = "[["
  right_delimiter = "]]"
}
