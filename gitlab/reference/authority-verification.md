# Authority Verification

**Authority Verification** is the canonical seam for deciding whether a GitLab workflow actor may approve or finish, must hand off, or must ask a human for a missing or contradictory authority fact.

Machine claim/result fields and enums: `skill://gitlab/reference/authority-verification.schema.json`.

In `Finish owner: parent` mode, reviewers hand off approval, merge, and auto-merge queue actions to the parent even when authority is otherwise verified.

Project binding, current SHA, exact-candidate local Gate Receipt, advisory CI observation, safe-text, fallback eligibility, mutation, and post-read remain in the [GitLab Mutation Guard](mutation-guard.md). Authority Verification is one guard phase.

## Claims and sources

Authority claims are maps, never grants. A consumer verifies the source before approval, merge, auto-merge queue, release, close, or cleanup.

The machine schema owns every required field and enum. The human input shape keeps only the source/grant relationship explicit:

```yaml
source_evidence:
  - grants_authority: true
```

Each entry also carries `source_type`, `source`, and `value`. `true` is valid only when that source grants the action.

### Source types and precedence

| Source type | Can grant authority? | Handling |
| --- | --- | --- |
| `human-explicit` | yes | Highest precedence for the named action; a human restriction wins until changed by a human. |
| `parent-explicit` | yes | Beats defaults within the authority granted to the parent. |
| `mr-or-issue-policy` | yes | Explicit only for the action named by the durable issue/MR policy note. |
| `project-rulebook` | yes | Stable repo policy section. |
| `repo-default` | approval only | Valid only when the default says so and no explicit restriction exists. |
| `builder-claim` | no | Routing hint that must resolve to a grant-capable source. |

The schema's `source_precedence[].granted_actions` is the machine source of truth. Repo defaults do not imply merge/auto-merge/release/cleanup authority. They also do not imply close authority.

Precedence fails closed:

1. Explicit restrictions beat grants for that action.
2. Human or parent instructions beat rulebook/project defaults.
3. Builder claims never grant authority.
4. Unresolved same-precedence conflict yields `result: conflict`, the most restrictive/no-action route, and parent/human resolution.
5. Missing or unverifiable source yields `result: missing`; it blocks the action without inventing a default finish authority.

## Result and routing

Routing decisions mean:

- `proceed` — authority is verified; reviewed-SHA, Gate Receipt, caller, and transport guards still apply. CI status is advisory.
- `must-handoff` — this caller takes no approval/finish mutation and hands evidence to the named actor.
- `ask-human` — source conflict or a human-only release path needs a parent/human decision.
- `blocked` — fix the named blocker before the requested action.

## No-self-approval / no-self-merge

The rule is unconditional and context-based:

- `builder` always gets `must-handoff` for handoff and `self_merge_risk` for approval, merge, or queue requests.
- A same-session builder, planner, or reviser cannot provide gate-eligible approval or finish for its own MR, even with another token. A parent may finish only after an independent final-reviewer pass, durable Review Report, fresh SHA/CI/authority/identity guards, and `Finish owner: parent` plus explicit authority-source routing.
- Equal GitLab caller/author ids do not by themselves block a fresh gate-eligible reviewer. Account identity is audit/token-stability evidence; session/context establishes independence.
- Missing or changed caller identity maps to `identity_unavailable` or `identity_changed` before the role × authority decision.

The enforced role × merge-authority × action sub-decision is in [`authority-matrix.md`](authority-matrix.md).

## Finish/result reporting

Record Authority Verification evidence separately from transport evidence:

- Authority: verified source refs, precedence/conflict result, caller role/context, identity status, and `authority_verification_source`.
- Transport: `via=mcp`, `via=glab-fallback`, or `via=n/a` from the Mutation Guard / finish result.

Authority success does not prove a mutation occurred; transport success does not prove authority without this seam's verified result.
