Terraform Steps

- $ terraform init
- $ terraform plan
- $ terraform apply -auto-approve

==========================================================================
```bash
$ vault login -method=userpass username="bob" password="user"

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.APAmfDURvNOhR1sTNzm66OaH
token_accessor         fgS6zShr04IxqulqvNC52dxo
token_duration         768h
token_renewable        true
token_policies         ["default"]
identity_policies      ["default"]
policies               ["default"]
token_meta_username    technology-ops_us
```
==========================================================================
```bash

$ VAULT_TOKEN=s.APAmfDURvNOhR1sTNzm66OaH vault token lookup
Key                            Value
---                            -----
accessor                       0EprWT8dkErvEWfNzGrdvrp8
creation_time                  1591282999
creation_ttl                   768h
display_name                   userpass-bob
entity_id                      c2a53233-43ce-73bd-923f-953b5a272342
expire_time                    2020-07-06T15:03:19.227310518Z
explicit_max_ttl               0s
external_namespace_policies    map[IYFU8:[technology-ops_us-admin-policy]]
id                             s.APAmfDURvNOhR1sTNzm66OaH
identity_policies              [default]
issue_time                     2020-06-04T15:03:19.227310273Z
meta                           map[username:bob]
num_uses                       0
orphan                         true
path                           auth/userpass/login/bob
policies                       [default]
renewable                      true
ttl                            767h59m34s
type                           service
```
==========================================================================
```bash

$ VAULT_TOKEN=s.APAmfDURvNOhR1sTNzm66OaH vault read -namespace="sbx/technology-ops_us" gcp/token/devops-roleset
Key                   Value
---                   -----
expires_at_seconds    1591286913
token                 ya29.c.Ko8BzQc79QhJFyQ2KDX0849YrCz-qtFNUVmBOKSBbq1KiPUDKJD-RaDpXbOO_5zNTlyjrKfB5-1amuHEYaU92nTH94rUz5xPgOZ_FskG1Q7QENGf4J12NKW8Wjh3oWdzW-wWWdvemUnsyRyQ418Gx5iXqm_6p19satUCaoW3x5RGDCeuaXeKKlMkM15uNewF5Rg
token_ttl             59m58s


VAULT_TOKEN=s.APAmfDURvNOhR1sTNzm66OaH vault read sbx/technology-ops_us/gcp/token/devops-roleset
Key                   Value
---                   -----
expires_at_seconds    1591286943
token                 ya29.c.Ko8BzQcvFEbEQ5i-GcYOIIZjgc8oqjQ7dDXeobKGKsc49XHRDyxiUxD64YLDaKv2dcIfqGUV4Z3-Z9QTlUCWjgpQCSMnkWuIrp1CZRzyp_3iSniGa4IkFYxD7OL1hU2s4MJ8oNHNz26MmmszJu_GOGm-sfTOaJQC4E4MbetNxWueTiC1Egksfl8s1nN_glY4Y10
token_ttl             59m58s
```
==========================================================================
```bash
VAULT_TOKEN=s.APAmfDURvNOhR1sTNzm66OaH vault read -namespace="sbx/clgx-cicd" gcp/token/storage-roleset
Error reading gcp/token/devops-roleset: Error making API request.

URL: GET https://172.20.20.11:8200/v1/gcp/token/devops-roleset
Code: 403. Errors:

* 1 error occurred:
	* permission denied
```




==========================================================================
```bash

$ vault login -method=userpass username="marydoe" password="user"

Success! You are now authenticated.
...

Key                    Value
---                    -----
token                  s.vKOOPr9kelfrqJYwwYot58X4
...
...
```
==========================================================================
```bash

$ VAULT_TOKEN=s.vKOOPr9kelfrqJYwwYot58X4 vault token lookup

Key                            Value
---                            -----
accessor                       4FAvHUqVOeOJy3zlHSkkSK49
creation_time                  1591287982
creation_ttl                   768h
display_name                   userpass-marydoe
entity_id                      1a0c93d2-2d89-76be-3626-01b156d3706a
expire_time                    2020-07-06T16:26:22.28881912Z
explicit_max_ttl               0s
external_namespace_policies    map[Y1ct9:[clgx-cicd-policy]]
id                             s.vKOOPr9kelfrqJYwwYot58X4
identity_policies              [default]
issue_time                     2020-06-04T16:26:22.288818917Z
meta                           map[username:marydoe]
num_uses                       0
orphan                         true
path                           auth/userpass/login/marydoe
policies                       [default]
renewable                      true
ttl                            767h59m7s
type                           service
```
==========================================================================
```bash

$ VAULT_TOKEN=s.vKOOPr9kelfrqJYwwYot58X4 vault read -namespace="sbx/clgx-cicd" gcp/token/storage-roleset

Key                   Value
---                   -----
expires_at_seconds    1591291704
token                 ya29.c.Ko8BzQdcD9DFxaBzvuPv_uSVvrrqoItCEVntCmbalWHXj6muWQiWRq0q3SIRwd8TIaTJE4aOOA8QrSAhG-4j6JQuo-kmwPLnXgmZcvuXjElnKzdGn5n-SzdEmYVLdVr22asq2y41j8GtFuLrFpYPN52LcwdwAWtHCsG7z-cv8rmglgEyk-ZVRL4k1J9ZzNkJ3JY
token_ttl             59m58s
```
==========================================================================
```bash

$ VAULT_TOKEN=s.vKOOPr9kelfrqJYwwYot58X4 vault read -namespace="sbx/technology-ops_us" gcp/token/devops-roleset

Error reading gcp/token/devops-roleset: Error making API request.

URL: GET https://172.20.20.11:8200/v1/gcp/token/devops-roleset
Code: 403. Errors:

* 1 error occurred:
	* permission denied

```

```bash
.
|-- tf_cluster
|   |-- files
|   |   `-- gcp.json
|   |-- root
|   |   |-- main.tf
|   |   |-- provider.tf
|   |   `-- variables.tf
|   |-- tf_nonprd
|       |-- main.tf
|       `-- organizations
|           |-- main.tf
|           |-- provider.tf
|           `-- variables.tf
|   |-- tf_prd
|       |-- main.tf
|       `-- organizations
|           |-- main.tf
|           |-- provider.tf
|           `-- variables.tf
|   `-- tf_sbx
|       |-- main.tf
|       `-- organizations
|           |-- main.tf
|           |-- provider.tf
|           `-- variables.tf
`-- vault
    |-- auth-methods
    |   |-- app-role.tf
    |   `-- userpass.tf
    |-- entities
    |   |-- groups.tf
    |   |-- output.tf
    |   `-- userpass_entity.tf
    |-- generic-endpoints
    |   |-- app-secrets
    |   |   `-- example-service.tf
    |   |-- main.tf
    |   |-- userpass
    |   |   `-- users.tf
    |   `-- variables.tf
    |-- main.tf
    |-- namespaces
    |   `-- main.tf
    |-- policies
    |   |-- admin.tf
    |   |-- app.tf
    |   |-- certification-admin.tf
    |   |-- certification.tf
    |   |-- edu-admin.tf
    |   |-- infrastructure.tf
    |   |-- training-admin.tf
    |   |-- training.tf
    |   `-- example.tf
    |-- secrets
    |   |-- gcp
    |   |   `-- rolesets
    |   |       |-- devops.tf
    |   |       `-- storage.tf
    |   |-- gcp.tf
    |   |-- kv.tf
    `-- variables.tf
```

```bash
  # module.tf_vault.module.auth-methods.null_resource.depends_on_userpass_mount[0] will be created
  + resource "null_resource" "depends_on_userpass_mount" {
      + id = (known after apply)
    }

  # module.tf_vault.module.auth-methods.vault_auth_backend.userpass[0] will be created
  + resource "vault_auth_backend" "userpass" {
      + accessor                  = (known after apply)
      + default_lease_ttl_seconds = (known after apply)
      + id                        = (known after apply)
      + listing_visibility        = (known after apply)
      + max_lease_ttl_seconds     = (known after apply)
      + path                      = (known after apply)
      + tune                      = (known after apply)
      + type                      = "userpass"
    }

  # module.tf_vault.module.entities.consul_keys.secret-id[0] will be created
  + resource "consul_keys" "secret-id" {
      + datacenter = "sfo"
      + id         = (known after apply)
      + var        = (known after apply)

      + key {
          + delete = false
          + flags  = 0
          + path   = "vault-operator/technology-ops_us/admin-entities"
          + value  = (known after apply)
        }
    }

  # module.tf_vault.module.entities.vault_identity_entity.entity[0] will be created
  + resource "vault_identity_entity" "entity" {
      + external_policies = false
      + id                = (known after apply)
      + metadata          = {
          + "group" = "root"
          + "type"  = "admin"
        }
      + name              = "admin"
      + policies          = [
          + "admin-policy",
        ]
    }

  # module.tf_vault.module.entities.vault_identity_entity.entity[1] will be created
  + resource "vault_identity_entity" "entity" {
      + external_policies = false
      + id                = (known after apply)
      + metadata          = {
          + "organization" = "technology-ops_us"
          + "type"         = "admin"
        }
      + name              = "Bob Smith"
      + policies          = [
          + "default",
        ]
    }

  # module.tf_vault.module.entities.vault_identity_entity.entity[3] will be created
  + resource "vault_identity_entity" "entity" {
      + external_policies = false
      + id                = (known after apply)
      + metadata          = {
          + "organization" = "clgx-cicd"
          + "type"         = "admin"
        }
      + name              = "John Snow"
      + policies          = [
          + "default",
        ]
    }

      # module.tf_vault.module.entities.vault_identity_entity.entity[1] will be created
  + resource "vault_identity_entity" "entity" {
      + external_policies = false
      + id                = (known after apply)
      + metadata          = {
          + "organization" = "technology-ops_us"
          + "type"         = "member"
        }
      + name              = "James Smith"
      + policies          = [
          + "default",
        ]
    }

  # module.tf_vault.module.entities.vault_identity_entity.entity[3] will be created
  + resource "vault_identity_entity" "entity" {
      + external_policies = false
      + id                = (known after apply)
      + metadata          = {
          + "organization" = "clgx-cicd"
          + "type"         = "member"
        }
      + name              = "Tyler Snow"
      + policies          = [
          + "default",
        ]
    }

  # module.tf_vault.module.entities.vault_identity_entity_alias.userpass[0] will be created
  + resource "vault_identity_entity_alias" "userpass" {
      + canonical_id   = (known after apply)
      + id             = (known after apply)
      + mount_accessor = (known after apply)
      + name           = "root"
    }

  # module.tf_vault.module.entities.vault_identity_entity_alias.userpass[1] will be created
  + resource "vault_identity_entity_alias" "userpass" {
      + canonical_id   = (known after apply)
      + id             = (known after apply)
      + mount_accessor = (known after apply)
      + name           = "bob"
    }

  # module.tf_vault.module.entities.vault_identity_entity_alias.userpass[2] will be created
  + resource "vault_identity_entity_alias" "userpass" {
      + canonical_id   = (known after apply)
      + id             = (known after apply)
      + mount_accessor = (known after apply)
      + name           = "johndoe"
    }

  # module.tf_vault.module.namespaces.vault_namespace.ns[0] will be created
  + resource "vault_namespace" "ns" {
      + id           = (known after apply)
      + namespace_id = (known after apply)
      + path         = "prd"
    }

  # module.tf_vault.module.namespaces.vault_namespace.ns[1] will be created
  + resource "vault_namespace" "ns" {
      + id           = (known after apply)
      + namespace_id = (known after apply)
      + path         = "nonprd"
    }

  # module.tf_vault.module.namespaces.vault_namespace.ns[2] will be created
  + resource "vault_namespace" "ns" {
      + id           = (known after apply)
      + namespace_id = (known after apply)
      + path         = "sbx"
    }

  # module.tf_vault.module.secrets.null_resource.depends_on_kv_mount[0] will be created
  + resource "null_resource" "depends_on_kv_mount" {
      + id = (known after apply)
    }

  # module.tf_vault.module.secrets.vault_mount.secret-kv[0] will be created
  + resource "vault_mount" "secret-kv" {
      + accessor                  = (known after apply)
      + default_lease_ttl_seconds = (known after apply)
      + description               = "Secret KV Engine"
      + id                        = (known after apply)
      + max_lease_ttl_seconds     = (known after apply)
      + path                      = "secret"
      + seal_wrap                 = (known after apply)
      + type                      = "kv"
    }

  # module.tf_vault.module.generic-endpoints.module.userpass.vault_generic_endpoint.admin-user[0] will be created
  + resource "vault_generic_endpoint" "admin-user" {
      + data_json            = (sensitive value)
      + disable_delete       = false
      + disable_read         = false
      + id                   = (known after apply)
      + ignore_absent_fields = true
      + path                 = "auth/userpass/users/root"
      + write_data           = (known after apply)
      + write_data_json      = (known after apply)
    }

  # module.tf_vault.module.generic-endpoints.module.userpass.vault_generic_endpoint.admin-user[1] will be created
  + resource "vault_generic_endpoint" "admin-user" {
      + data_json            = (sensitive value)
      + disable_delete       = false
      + disable_read         = false
      + id                   = (known after apply)
      + ignore_absent_fields = true
      + path                 = "auth/userpass/users/bob"
      + write_data           = (known after apply)
      + write_data_json      = (known after apply)
    }

...

Plan: 46 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```


Next we need to create the child namespaces 

```bash
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.tf_vault_technology-ops_us.module.namespaces.vault_namespace.ns[0] will be created
  + resource "vault_namespace" "ns" {
      + id           = (known after apply)
      + namespace_id = (known after apply)
      + path         = "technology-ops_us"
    }

  # module.tf_vault_technology-ops_us.module.namespaces.vault_namespace.ns[1] will be created
  + resource "vault_namespace" "ns" {
      + id           = (known after apply)
      + namespace_id = (known after apply)
      + path         = "clgx-cicd"
    }

Plan: 2 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

Next we need to implement the policies for the specific namespaces and create a entity group to allow the users authenticated in root to work on the specific namespaces

```bash

Terraform will perform the following actions:

  # module.tf_vault_technology-ops_us.module.entities.vault_identity_group.group[0] will be created
  + resource "vault_identity_group" "group" {
      + external_policies = false
      + id                = (known after apply)
      + member_entity_ids = [
          + "c2a53233-43ce-73bd-923f-953b5a272342",
          + "c714f14b-7b07-db4d-6a36-844fa6e10dd1",
        ]
      + metadata          = {
          + "version" = "1"
        }
      + name              = "technology-ops_us Admin"
      + policies          = [
          + "technology-ops_us-admin-policy",
        ]
      + type              = "internal"
    }

  # module.tf_vault_technology-ops_us.module.entities.vault_identity_group.group[1] will be created
  + resource "vault_identity_group" "group" {
      + external_policies = false
      + id                = (known after apply)
      + member_entity_ids = [
          + "46db1c29-cfb9-bb31-e499-34952600dad1",
        ]
      + metadata          = {
          + "version" = "1"
        }
      + name              = "technology-ops_us DevOps"
      + policies          = [
          + "technology-ops_us-policy",
        ]
      + type              = "internal"
    }

  # module.tf_vault_technology-ops_us.module.policies.vault_policy.technology-ops_us-admin-policy[0] will be created
  + resource "vault_policy" "technology-ops_us-admin-policy" {
      + id     = (known after apply)
      + name   = "technology-ops_us-admin-policy"
      + policy = <<~EOT
                # Manage namespaces
                path "sys/namespaces/*" {
                  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
                }

                # Manage policies
                path "sys/policies/acl/*" {
                  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
                }

                # List policies
                path "sys/policies/acl" {
                  capabilities = ["list"]
                }

                # Enable and manage secrets engines
                path "sys/mounts/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }

                # List available secrets engines
                path "sys/mounts" {
                  capabilities = [ "read" ]
                }

                # Manage secrets at 'secret'
                path "secret/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }
        EOT
    }

  # module.tf_vault_technology-ops_us.module.policies.vault_policy.technology-ops_us-policy[0] will be created
  + resource "vault_policy" "technology-ops_us-policy" {
      + id     = (known after apply)
      + name   = "technology-ops_us-policy"
      + policy = <<~EOT
                # Manage namespaces
                path "sys/namespaces/*" {
                  capabilities = ["read", "list"]
                }

                # Enable and manage secrets engines
                path "sys/mounts/*" {
                  capabilities = ["read", "list"]
                }

                # List available secrets engines
                path "sys/mounts" {
                  capabilities = [ "read" ]
                }

                # Manage secrets at 'secret'
                path "secret/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }

                # Create tokens for GCP
                path "gcp/token/*" {
                  capabilities = [ "read" ]
                }
        EOT
    }

  # module.tf_vault_technology-ops_us.module.secrets.null_resource.depends_on_kv_mount[0] will be created
  + resource "null_resource" "depends_on_kv_mount" {
      + id = (known after apply)
    }

  # module.tf_vault_technology-ops_us.module.secrets.vault_gcp_secret_backend.gcp[0] will be created
  + resource "vault_gcp_secret_backend" "gcp" {
      + credentials               = (sensitive value)
      + default_lease_ttl_seconds = 0
      + id                        = (known after apply)
      + max_lease_ttl_seconds     = 0
      + path                      = "gcp"
    }

  # module.tf_vault_technology-ops_us.module.secrets.vault_mount.secret-kv[0] will be created
  + resource "vault_mount" "secret-kv" {
      + accessor                  = (known after apply)
      + default_lease_ttl_seconds = (known after apply)
      + description               = "Secret KV Engine"
      + id                        = (known after apply)
      + max_lease_ttl_seconds     = (known after apply)
      + path                      = "secret"
      + seal_wrap                 = (known after apply)
      + type                      = "kv"
    }

  # module.tf_vault_clgx-cicd.module.entities.vault_identity_group.group[0] will be created
  + resource "vault_identity_group" "group" {
      + external_policies = false
      + id                = (known after apply)
      + member_entity_ids = [
          + "4a4931b5-508f-1508-91e4-b73584a8746c",
          + "c714f14b-7b07-db4d-6a36-844fa6e10dd1",
        ]
      + metadata          = {
          + "version" = "1"
        }
      + name              = "clgx-cicd Admin"
      + policies          = [
          + "clgx-cicd-admin-policy",
        ]
      + type              = "internal"
    }

  # module.tf_vault_clgx-cicd.module.entities.vault_identity_group.group[1] will be created
  + resource "vault_identity_group" "group" {
      + external_policies = false
      + id                = (known after apply)
      + member_entity_ids = [
          + "1a0c93d2-2d89-76be-3626-01b156d3706a",
        ]
      + metadata          = {
          + "version" = "1"
        }
      + name              = "clgx-cicd DevOps"
      + policies          = [
          + "clgx-cicd-policy",
        ]
      + type              = "internal"
    }

  # module.tf_vault_clgx-cicd.module.policies.vault_policy.clgx-cicd-admin-policy[0] will be created
  + resource "vault_policy" "clgx-cicd-admin-policy" {
      + id     = (known after apply)
      + name   = "clgx-cicd-admin-policy"
      + policy = <<~EOT
                # Manage namespaces
                path "sys/namespaces/*" {
                  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
                }

                # Manage policies
                path "sys/policies/acl/*" {
                  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
                }

                # List policies
                path "sys/policies/acl" {
                  capabilities = ["list"]
                }

                # Enable and manage secrets engines
                path "sys/mounts/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }

                # List available secrets engines
                path "sys/mounts" {
                  capabilities = [ "read" ]
                }

                # Manage secrets at 'secret'
                path "secret/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }
        EOT
    }

  # module.tf_vault_clgx-cicd.module.policies.vault_policy.clgx-cicd-policy[0] will be created
  + resource "vault_policy" "clgx-cicd-policy" {
      + id     = (known after apply)
      + name   = "clgx-cicd-policy"
      + policy = <<~EOT
                # Manage namespaces
                path "sys/namespaces/*" {
                  capabilities = ["read", "list"]
                }

                # Enable and manage secrets engines
                path "sys/mounts/*" {
                  capabilities = ["read", "list"]
                }

                # List available secrets engines
                path "sys/mounts" {
                  capabilities = [ "read" ]
                }

                # Manage secrets at 'secret'
                path "secret/*" {
                  capabilities = ["create", "read", "update", "delete", "list"]
                }

                # Create tokens for GCP
                path "gcp/token/*" {
                  capabilities = [ "read" ]
                }
        EOT
    }

  # module.tf_vault_clgx-cicd.module.secrets.null_resource.depends_on_kv_mount[0] will be created
  + resource "null_resource" "depends_on_kv_mount" {
      + id = (known after apply)
    }

  # module.tf_vault_clgx-cicd.module.secrets.vault_gcp_secret_backend.gcp[0] will be created
  + resource "vault_gcp_secret_backend" "gcp" {
      + credentials               = (sensitive value)
      + default_lease_ttl_seconds = 0
      + id                        = (known after apply)
      + max_lease_ttl_seconds     = 0
      + path                      = "gcp"
    }

  # module.tf_vault_clgx-cicd.module.secrets.vault_mount.secret-kv[0] will be created
  + resource "vault_mount" "secret-kv" {
      + accessor                  = (known after apply)
      + default_lease_ttl_seconds = (known after apply)
      + description               = "Secret KV Engine"
      + id                        = (known after apply)
      + max_lease_ttl_seconds     = (known after apply)
      + path                      = "secret"
      + seal_wrap                 = (known after apply)
      + type                      = "kv"
    }

  # module.tf_vault_technology-ops_us.module.secrets.module.rolesets.vault_gcp_secret_roleset.devops-sa[0] will be created
  + resource "vault_gcp_secret_roleset" "devops-sa" {
      + backend               = "gcp"
      + id                    = (known after apply)
      + project               = "cl-70813983e33a"
      + roleset               = "devops-roleset"
      + secret_type           = "access_token"
      + service_account_email = (known after apply)
      + token_scopes          = [
          + "https://www.googleapis.com/auth/cloud-platform",
        ]

      + binding {
          + resource = "//cloudresourcemanager.googleapis.com/projects/cl-70813983e33a"
          + roles    = [
              + "roles/compute.admin",
            ]
        }
    }

  # module.tf_vault_clgx-cicd.module.secrets.module.rolesets.vault_gcp_secret_roleset.cloud_storage-sa[0] will be created
  + resource "vault_gcp_secret_roleset" "cloud_storage-sa" {
      + backend               = "gcp"
      + id                    = (known after apply)
      + project               = "cl-70813983e33a"
      + roleset               = "storage-roleset"
      + secret_type           = "access_token"
      + service_account_email = (known after apply)
      + token_scopes          = [
          + "https://www.googleapis.com/auth/cloud-platform",
        ]

      + binding {
          + resource = "//cloudresourcemanager.googleapis.com/projects/cl-70813983e33a"
          + roles    = [
              + "roles/storage.admin",
            ]
        }
    }

Plan: 16 to add, 0 to change, 0 to destroy.
```