# Authority Verification

**Authority Verification** is the canonical seam for deciding whether a GitLab workflow actor may proceed with an approval or finish action, must hand off, or must ask a human for a missing/contradictory authority fact.

Machine-readable schema: [`authority-verification.schema.json`](authority-verification.schema.json) / `skill://gitlab/reference/authority-verification.schema.json`.

## Resource addressing

When a skill runs from a target repository, reference authority resources with `skill://gitlab/...`:

- `skill://gitlab/reference/authority-verification.md`
- `skill://gitlab/reference/authority-verification.schema.json`
- `skill://gitlab/reference/authority-matrix.md`
- `skill://gitlab/reference/identity-and-authentication.md`
- `skill://gitlab/reference/authority-matrix.md`

Target-repo policy remains repo-relative. Use `docs/agents/dev-workflows.md`, `docs/agents/check-gate.md`, and project rulebook paths for the repository being changed; do not rewrite those target policy refs as gitlab skill resources.

## Scope

This seam owns authority facts only:

- finish-owner routing (`Finish owner: parent`) distinct from merge authority;
- approval and merge authority claim shape;
- accepted source types and source precedence;
- missing, restricted, and conflicting source results;
- verified authority output and action routing;
- no-self-approval / no-self-merge relationship to caller identity and review context.

It does **not** replace project binding, MR head SHA checks, exact-SHA CI, local gate / Gate Receipt checks, safe-text validation, fallback eligibility, or post-mutation re-read. Those stay in the [GitLab Mutation Guard](mutation-guard.md). Authority Verification is the guard's authority phase.

## Input claim shape

Authority claims are maps, not grants. Builders may quote claims and sources in Reviewer Lift / delivery handoffs, but a consumer must verify the source before any approval, merge, auto-merge queue, release, close, or cleanup action.

```yaml
authority_verification_input:
  requested_action: "approve | merge | queue-auto-merge | handoff"
  finish_owner: "parent | caller"
  caller:
    role: "builder | reviewer | authorized-parent | human"
    caller_user_id: "<GitLab user id from get_current_user()>"
    mr_author_id: "<GitLab user id from get_merge_request.author.id>"
    identity_status: "verified-stable | unavailable | changed"
    context_relation: "fresh-reviewer | builder-session | parent-session | reviser-session | human | unknown"
  approval:
    value: "default-after-pass | restricted"
    source: "<stable repo policy ref, human/parent/MR comment URL, or restriction source>"
    source_type: "human-explicit | parent-explicit | mr-or-issue-policy | project-rulebook | repo-default | builder-claim"
    verified: false
    restricted: false
  merge:
    value: "approval-only | reviewer may merge | queue auto-merge | human release | project default"
    source: "<parent task prompt, human MR comment URL, rulebook path+section, or project default source>"
    source_type: "human-explicit | parent-explicit | mr-or-issue-policy | project-rulebook | repo-default | builder-claim"
    verified: false
  source_evidence:
    - source_type: "repo-default"
      source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
      value: "default-after-pass"
      grants_authority: true
```

### Source types and precedence

| Source type | Can grant authority? | Precedence / handling |
| --- | --- | --- |
| `human-explicit` | yes | Highest precedence for the named action. A human restriction also wins until a human changes it. |
| `parent-explicit` | yes | Beats rulebook/project defaults within the authority the parent was granted by the human/project. |
| `mr-or-issue-policy` | yes | Durable issue/MR policy note or comment URL. Treat as explicit only for the action it names. |
| `project-rulebook` | yes | Stable repo policy section, for example `docs/agents/dev-workflows.md#review-approval--merge-policy`. |
| `repo-default` | yes, for approval only when the default policy says so | Default approval-after-pass is valid only when no explicit restriction source exists. Repo defaults do not imply merge/auto-merge/release/cleanup authority. |
| `builder-claim` | no | Routing hint only. It must point to one of the source types above before it becomes verified authority. |

Machine metadata scopes grants by action: `source_precedence[].granted_actions` limits `repo-default` to `approve`, so repo defaults can never be consumed as merge, auto-merge, release, close, or cleanup authority.

Precedence is fail-closed:

1. Explicit restrictions beat grants for the affected action.
2. Human or parent instructions beat rulebook/project defaults.
3. Builder claims never beat any other source and never grant authority by themselves.
4. If sources conflict and no higher-precedence source resolves the conflict, choose the most restrictive/no-action result, set `result: conflict`, and route to a parent/human rather than inferring authority.
5. Missing source or unverifiable source is `result: missing`; it blocks the affected action but does not invent `approval-only` or any other default finish authority.

## Output shape

Authority Verification emits one result for one requested action:

```yaml
authority_verification:
  result: "verified | restricted | conflict | missing | handoff | blocked"
  decision: "proceed | must-handoff | ask-human | blocked"
  blocker: "none | missing_authority | authority_source_mismatch | restricted_authority | permission_uncertain | self_merge_risk | identity_unavailable | identity_changed"
  next_actor: "reviewer | authorized-parent | parent | human | none"
  next_action: "proceed | handoff | ask-human | fix-authority-source | rerun-with-fresh-identity"
  approval:
    value: "default-after-pass | restricted"
    source: "<verified source>"
    verified: true
    restricted: false
  merge:
    value: "approval-only | reviewer may merge | queue auto-merge | human release | project default"
    source: "<verified source>"
    verified: true
  conflicts: []
  evidence:
    authority_verification_source: "description-verified | description-mismatch | parameter-verified | parameter-assumed"
    source_refs:
      - "start-review/REVIEW-FLOW.md#approval-authority-policy"
```

`decision` is deliberately routing-oriented:

- `proceed` — authority is verified for the requested action; the caller still must satisfy SHA/CI/local-gate/transport guards.
- `must-handoff` — no approval/finish mutation may be taken by this caller; hand off to the named actor with the authority evidence.
- `ask-human` — a human/parent decision is required because sources conflict or a human-only release path was reached.
- `blocked` — the requested action is unsafe until the named blocker is fixed.

## No-self-approval / no-self-merge

The no-self rule is unconditional and context-based:

- `builder` role always produces `decision: must-handoff` for handoff and `blocker: self_merge_risk` for any requested approval, merge, or queue action.
- A same-session builder, planner, or reviser context cannot provide gate-eligible approval or finish for its own MR, even with a different GitLab token. A parent coordinator may finish only after an independent final-reviewer pass plus durable Review Report, fresh MR SHA/CI/authority/identity guards, and `Finish owner: parent` / explicit authority source routing.
- GitLab account equality (`caller_user_id == mr_author_id`) is **not** a blocker by itself for a fresh, gate-eligible reviewer. Identity is audit/token-stability evidence; review independence is the session/context boundary.
- Missing or changed caller identity maps to `identity_unavailable` or `identity_changed` before the role × authority decision runs.

The deterministic role × merge-authority × action table remains in [`authority-matrix.md`](authority-matrix.md) and is enforced by [`../scripts/gitlab-finish-authority.sh`](../scripts/gitlab-finish-authority.sh). That matrix is the finish-action sub-decision inside this broader authority seam.

## Finish/result reporting

Reports and machine handoffs record Authority Verification evidence separately from GitLab transport evidence:

- Authority evidence: verified source refs, precedence/conflict result, caller role/context, caller identity status, and `authority_verification_source` in `finish_result`.
- Transport evidence: `via=mcp`, `via=glab-fallback`, or `via=n/a` from the mutation guard / finish result.

A passing authority result never implies a transport mutation happened. A successful transport mutation never proves authority unless it cites this seam's verification result.
