---
name: setup-dev-skills
description: Drafts and applies the smallest owner-confirmed project documentation delta, preserving custom setup and recording MCP-first integration bindings.
disable-model-invocation: true
---

# Setup Dev Skills

## Resource resolution

Use native runtime metadata to establish this file's absolute filesystem
path; if only the skill directory is given, append `SKILL.md`.
Resolve relative skill-bundle links against the directory of the file
containing the link, normalize `..`, strip Markdown fragments, and read the
resulting absolute filesystem path. Rebase again from each subsequently
loaded file. Never append parent-relative links to a resource URI or use the
target repository's working directory as the skill-resource base.

Target project/profile/provider references stay bound to the verified
target checkout, not the skill installation.

User-invoked and human-confirmed: discover, draft the smallest docs delta,
resolve genuine choices together, confirm once, apply. Other skills may recommend
this entry, but never auto-run it, login, install or mutate live labels.

## Explore the invoked target

Read owner intent, the existing rulebook's `project_profile`, `profile_path`,
`provider.reference`, policy/docs pointers and custom roots.
Shared [field guidance](reference/project-profile-facts.json) supplies no target
identity, vocabulary, host, default paths or detector.

Compare named fetch **and** push remotes with intended code/change-request scope
and fork intent. Prefer the relevant connected MCP; read its current tool/API
documentation and verify candidate platform, canonical repository and default
branch natively, including self-hosted instances. Neither host branding, the first
remote nor installed-tool presence establishes scope. Resolve multiple-target or
fork conflicts explicitly; keep independently configured tracker/CI bindings.

Use help-verified CLI fallback only when a needed MCP call is unavailable or has
a documented gap; establish the same scope and actor when both transports are
used. Missing tools/authentication do not erase known facts or prevent drafting:
mark verification gaps, never force login or invent capability. Setup needs no
all-service identity sweep or exhaustive fallback matrix.

Read existing domain/ADR, gate/runtime/bootstrap, guardrail and label docs only
as needed for the delta. Preserve task-selected specialist policy and live
vocabulary; no live label creation/rename/delete.
Setup never creates, edits, deletes or certifies runtime subagent definitions,
model/effort selection, preload, precedence or provenance; leave them untouched.

## Draft and resolve choices

Reconcile only missing, owner-requested or evidenced-stale sections in place.
A newer template alone is not drift. Preserve valid custom paths, vocabulary,
additions, policy and integration recipes; do not normalize complete documents.
If nothing needs changing, report no writes and stop.

Draft the smallest useful delta using [tracker](issue-tracker.md) and
[workflow](dev-workflows-generic.md) seeds as field guidance, not replacement docs.
At `provider.reference`, record a compact binding: intended provider, canonical
repository/default branch, applicable MCP route, tracker/CI pointers, and evidence
sources marked verified or unverified. Keep existing valid recipes authoritative.
Do not invent facts where native verification is unavailable.

Batch only genuine unresolved owner choices with their evidence and a suggested
resolution. Do not repeat known answers, offer a platform/tool menu or ask the
owner to discover undocumented provider internals. Missing local gate policy
needs an explicit rationale/owner choice, not fabricated PASS; CI stays advisory.

## Present and confirm

Preview changed sections and their target paths, why they change, resolving
profile/reference pointers and verification gaps. Do not require review of
unchanged full documents. After choices are resolved, obtain one confirmation
of the final delta before any writes.

## Write confirmed changes

Apply only that delta. Update the existing rulebook's Agent skills block/pointers
without touching unrelated content; if absent, resolve which native rulebook to
create. Conflicting blocks/sources need an owner choice. Use confirmed
`project_profile.agent_setup_docs` paths, never installation defaults.
Authored docs stay Markdown.

Reuse `project_profile`, `profile_path` and selected `provider.reference`; no
second config, detector, catalogue, dispatcher, generator or adapter registry.
Installed aliases retain underlying source ownership, not target policy.

Completion means confirmed docs applied, pointers resolving in the invoked target,
custom content preserved and verification gaps reported. No-drift means no writes.
It does not mean delivery-ready, action authority or future publication/gate/review
success. [Forge](../forge/SKILL.md#operation-time-recipes) establishes only the
active operation's mechanics/proofs before acting; setup does not certify all five
operations or require capacity/merge probes. Live installation/operator mutations
remain outside setup.
