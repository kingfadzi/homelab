# dynamic-project-policy.hcl
path "secret/data/projects/{{identity.entity.aliases.auth_jwt.role_name}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}