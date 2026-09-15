# Authoring rules

Apply these rules only to the configuration being changed; repository conventions win when stricter.

- Pin an explicit Terraform/OpenTofu core constraint and explicit provider source/version constraints using the repository's established constraint policy. Do not rewrite the dependency lock file without an authorized dependency-selection change.
- Give variables precise types, descriptions, and validation for domain constraints. Mark secret-bearing variables and outputs `sensitive = true`; never embed credentials or secret values.
- Document outputs and expose only stable caller-facing values.
- Prefer `for_each` with stable, meaningful keys when resource identity matters; do not derive identity from reorderable list positions.
- Keep dependencies implicit through references. Add `depends_on` or `lifecycle` only for an intentional behavior that the native test or repository contract demonstrates.
- Do not add provisioners. Do not change backend or state behavior unless the task explicitly requires and authorizes that surface.
- Keep modules narrow, names descriptive, formatting canonical, and comments limited to non-obvious intent.

Style guides:

- Terraform: <https://developer.hashicorp.com/terraform/language/style>
- OpenTofu: <https://opentofu.org/docs/language/syntax/style/>
