# Dev Workflows

Confirmed profile: `<target profile id>` at `<profile_path>`.
Selected `provider.reference`: `<target-owned integration doc or section>`.
Intended code/change, work-item and advisory CI scopes: `<independently verified scopes>`.
Named fetch/push remotes and fork intent: `<confirmed target choices>`.

Shared field guidance: `skill://setup-dev-skills/reference/project-profile-facts.json`
(no default target profile). Shared delivery uses `/forge`, `/start-build`,
`/start-review`, `/plan-to-issues`, `/issue-delivery-loop` and `/retro` through
confirmed target pointers. Local work items bind filesystem scope. Refresh only
systems required by the requested operation; missing or unsupported actions block
only that operation. Configuration grants no action authority.

Canonical resources:

- `skill://forge/SKILL.md`
- `skill://forge/reference/common-guard.md`
- `skill://start-build/templates/delivery-schema.md`
- `skill://start-build/templates/reviewer-lift-schema.md`
- `skill://start-build/reference/parent-owned-gate.md`
- `skill://start-review/REVIEW-FLOW.md`

This profile declares confirmed custom Agent Setup Doc paths, exact Check Gate
command/runtime/bootstrap, label/readiness vocabulary, branch policy, advisory CI,
domain/ADR paths, release/deploy policy, manual acceptance evidence and auxiliary
index ownership. Hooks preserve the
[safety floors](skill://setup-dev-skills/docs/effort-scaling.md#hard-floors-never-scaled-away).

Complete runtime-specific same-name project declarations point at canonical skill
entries and preserve role/model/effort pins and task-selected specialists. Native
tool selectors come only from confirmed available target tools; metadata is not
hard confinement. Establish each runtime's precedence and selected-file/skill
provenance separately from actual spawning and allocated/revision sessions.
Resolve canonical builder/final-reviewer roles through the effective spawning
inventory, preserving native qualified IDs and verified target-project precedence
under [native route selection](skill://start-build/reference/parent-orchestrator.md#native-route-selection).
Keep logical skill IDs stable; use Claude's `skills:<name>` for plugin invocation
and preloads, and OMP's canonical names. Entry bodies supply Claude's filesystem
mapping; resource access does not supply target policy or prove preload execution.
Resolve installed helper URIs to real filesystem paths before execution from a
foreign target CWD. Installed `docs/` aliases keep underlying source ownership and
never replace this target's profile, identity, paths, vocabulary or policy.
