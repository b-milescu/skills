# GitLab Transport

Invoke `gitlab` and preserve its stable snippet contracts: GitLab MCP first,
documented help-first `glab` fallback only for an eligible MCP gap, and
provider-native post-mutation MCP readback.

Neutral records map to GitLab project, issue, merge request, commit SHA,
pipeline/job, discussion/note, and branch values. GitLab validates numeric IIDs,
URLs, close-keyword syntax, and note locators; generic workflow code does not.

This branch owns draft/ready changes, exact-SHA advisory pipeline observations,
approvals, direct merge or queued auto-merge, native protection refusals,
closure previews, branch removal, and merged commit/squash containment.
User-level verdict and action eligibility stay with the common guard and review
flow; GitLab CI status never changes them. `snapshot` handoff evidence maps to
`/gitlab` snippet `mr-handoff-evidence`.

## Provider transport

Provider-specific mechanics, never copied here:

- [GitLab skill](../../gitlab/SKILL.md) — fall back to the full skill only under
  its documented conditions
- [Snippet transports](../../gitlab/reference/snippet-transports.md)
- [Mutation guard](../../gitlab/reference/mutation-guard.md)
- [CI/finish guards](../../gitlab/reference/ci-finish-guards.md)
- [Authority verification](../../gitlab/reference/authority-verification.md)

## Issue publish

Follow the GitLab-owned [Issue publication contract](../../gitlab/SKILL.md#issue-publication)
for URL-free native arguments, independent intended-repository verification,
fresh project/user bindings, exact submitted-field preservation, creation
outcomes, and GET-only/bounded recovery. The bound MCP owns routing; missing or
conflicting repository evidence or an old mounted schema blocks publication, not
a missing caller API URL. Use only fallback conditions `/gitlab` already names.
