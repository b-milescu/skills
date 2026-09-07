# GitLab Transport

Use only after `preflight` binds GitLab. Invoke `gitlab` and preserve its stable
snippet contracts: GitLab MCP first, documented help-first `glab` fallback only
for an eligible MCP gap, and provider-native post-mutation MCP readback.

Map the neutral records to GitLab project, issue, merge request, commit SHA,
pipeline/job, discussion/note, and branch values. GitLab validates numeric IIDs,
URLs, close-keyword syntax, and note locators; generic workflow code does not.

The GitLab branch owns draft/ready changes, exact-SHA advisory pipeline
observations, approvals, direct merge or queued auto-merge, native protection
refusals, closure previews, branch removal, and merged commit/squash containment.
User-level verdict and action eligibility remain owned by the common guard and
review flow; GitLab CI status never changes them. Use
[`gitlab/SKILL.md`](../../gitlab/SKILL.md) as the provider-specific mechanics
source rather than copying those mechanics here.

Handoff evidence on `snapshot` maps to `/gitlab` snippet `mr-handoff-evidence`.

## Provider transport

- [GitLab skill](../../gitlab/SKILL.md)
- [Snippet transports](../../gitlab/reference/snippet-transports.md)
- [Mutation guard](../../gitlab/reference/mutation-guard.md)
- [CI/finish guards](../../gitlab/reference/ci-finish-guards.md)
- [Authority verification](../../gitlab/reference/authority-verification.md)

Fall back to the full [`gitlab/SKILL.md`](../../gitlab/SKILL.md) only under
documented conditions.

## Issue publish

Follow the GitLab-owned [Issue publication contract](../../gitlab/SKILL.md#issue-publication)
for required native bindings, exact submitted-field preservation, creation
outcomes, and GET-only/bounded recovery. Fail closed when its trusted API-root
binding is absent; use only fallback conditions already named by `/gitlab`.
