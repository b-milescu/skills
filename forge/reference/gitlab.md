# GitLab Transport

Use only after `preflight` binds GitLab. Invoke `gitlab` and preserve its stable
snippet contracts: GitLab MCP first, documented help-first `glab` fallback only
for an eligible MCP gap, and provider-native post-mutation MCP readback.

Map the neutral records to GitLab project, issue, merge request, commit SHA,
pipeline/job, discussion/note, and branch values. GitLab validates numeric IIDs,
URLs, close-keyword syntax, and note locators; generic workflow code does not.

The GitLab branch owns draft/ready changes, exact-SHA pipelines, approvals,
direct merge or queued auto-merge, closure previews, branch removal, and merged
commit/squash containment. Use [`gitlab/SKILL.md`](../../gitlab/SKILL.md) as the
provider-specific source of truth rather than copying those mechanics here.

## Provider transport

- [GitLab skill](../../gitlab/SKILL.md)
- [Snippet transports](../../gitlab/reference/snippet-transports.md)
- [Mutation guard](../../gitlab/reference/mutation-guard.md)
- [CI/finish guards](../../gitlab/reference/ci-finish-guards.md)
- [Authority verification](../../gitlab/reference/authority-verification.md)

Fall back to the full [`gitlab/SKILL.md`](../../gitlab/SKILL.md) only under
documented conditions.

## Issue publish

Create one issue through disclosed `/gitlab` MCP-first `create_issue` (labels on
create, or `update_issue` label-reconcile), then native `get_issue` /
`get_issue_description` readback of title, labels, and body. Fallback only when
`/gitlab` already names that condition. Fail closed if this branch cannot name
a native create.
