# Dev Workflows

Provider: `<gitlab | github | azure-devops>`
Repository: `<canonical repository identifier>`
Default branch: `<default branch>`

Profile facts: `skill://setup-dev-skills/reference/project-profile-facts.json`.

Shared delivery uses `/forge`, `/start-build`, `/start-review`, and
`/issue-delivery-loop`. `/forge preflight` verifies the provider/profile/remote
binding once and exposes only the selected provider reference. Common policy
uses issue, change request, commit SHA, and CI run terminology; provider-native
mechanics stay in that reference.

Canonical resources:

- `skill://forge/SKILL.md`
- `skill://forge/reference/common-guard.md`
- `skill://start-build/templates/delivery-schema.md`
- `skill://start-build/templates/reviewer-lift-schema.md`
- `skill://start-build/reference/parent-owned-gate.md`
- `skill://start-review/REVIEW-FLOW.md`

This profile declares the target Check Gate, label/readiness policy, branch
naming, required CI jobs, domain/ADR paths, release/deploy authority, manual
validation, language families, acceptance surfaces, and auxiliary-index policy.
These hooks never weaken reviewed-commit binding, CI binding, authority,
independent review, complete diff coverage, or provider-native readback.

`/plan-to-issues` is the shared publisher for GitLab, GitHub, and Azure DevOps
after `/forge preflight`. `/gitlab` remains GitLab-only transport. GitHub uses
native REST/GraphQL or `gh` inside the selected forge reference; Azure DevOps uses
mounted native Boards/Repos/Pipelines tools first. Add no provider SDK.
