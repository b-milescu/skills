# Review Flow

Canonical mandatory independent review policy for one bound GitLab, GitHub, or
Azure DevOps change request. Provider mechanics live behind `/forge`; this file
owns review judgment, evidence, severity, CI/Open Question decisions, authority,
and action separation.
On missing mechanics or provider drift, fall back to the selected `/forge`
provider reference; never copy provider commands into this policy.

## Context Firewall

A gate-eligible reviewer is fresh: it did not build, plan, revise, or
parent-orchestrate the change. Same-session review is advisory only.
Parent/builder reasoning, packets, lifts, receipts, handoffs, comments, and
memory are claims or maps, not evidence. If inherited reasoning cannot be
separated from independent judgment, return `blocked`,
`human-decision-needed`, and `rerun-review` from a fresh context.

## Review Context Capsule

Record each claim, its independent reviewer verification, and its Tier 1 or
Tier 2 source before relying on it:

| Capsule field | Claim | Reviewer verification | Source |
|---|---|---|---|
| Repository | `<claimed repository/default branch>` | `<verified provider binding>` | `<Tier 1 or Tier 2 locator>` |
| Change request | `<claimed locator/source/target/commit>` | `<verified provider snapshot and diff>` | `<Tier 1 locator>` |
| Authority | `<claimed approval/finish authority and provenance>` | `<verified authority guard result>` | `<Tier 1 or Tier 2 locator>` |
| CI | `<claimed CI/local gate>` | `<verified commit-bound status>` | `<Tier 1 or Tier 2 locator>` |
| Scope | `<claimed issue scope and changed surfaces>` | `<verified issue-to-diff coverage>` | `<Tier 1 or Tier 2 locator>` |
| Artifacts | `<claimed packet/lift/receipt/report>` | `<verified source and readback>` | `<Tier 1 or Tier 2 locator>` |
| Context expansion | `<additional context requested>` | `<verified trigger and bounded read>` | `<finding, policy, or human instruction>` |

- **Tier 0 — prompt invariants:** target locator, rulebook, skill entry points,
  Context Firewall, stop condition, and authority/finish ownership.
- **Tier 1 — required reads:** bounded provider-native decision-grade evidence.
- **Tier 2 — risk-triggered reads:** bounded repository policy, source, tests,
  docs, and verified run evidence tied to a concrete risk or finding.
- **Tier 3 — forbidden-by-default broad context:** whole-repository reading,
  parent conversation, hidden history, memory, and unrelated summaries.

Reviewer Lift is a map, not proof. Independently verify every safety-critical
field and record its verification and source. A suspected secret exposure
blocks partial approval, uses redacted diagnostics, and routes to a
human/security path.


## Fail-closed review coverage

Complete provider-native files, diffs, discussions, reviews, and CI contexts are required; truncation, pagination uncertainty, or stale bindings block.
If the reviewer cannot inspect all behavior-affecting changed surfaces, return
`blocked` with `partial-review`; never partially approve. Fail-closed triggers
are: diff unavailable; too large for bounded review; binary/generated artifact without provenance; hidden dependencies; missing linked issue/context affecting behavior; or tool limits before decision. Request a split when bounded complete review cannot otherwise be restored.

Suspected credential exposure returns `blocked` with
`secret-exposure-suspected`: do not quote the secret, redact the Review Report,
block approval, and route removal, rotation, and history purge plus human
security escalation per project policy.

## Binding and completeness

Invoke `forge preflight` before snapshot, publication, or action and record
provider, canonical repository, default branch, opaque change-request
identifier/locator, source/target, current commit, and caller identity.
Ambiguity, profile mismatch, or a bare cross-repository identifier fails closed.

Use `forge snapshot` to obtain:

- linked issue description and all current notes/revisions;
- current change-request state and exact commit;
- complete paginated files/diff with provider truncation limits proven absent;
- every review, thread/discussion, resolution, and required policy input;
- required CI contexts bound to the reviewed commit or provider-proven
  integration candidate;
- local Gate Receipt and authority provenance locators.

Local checkout, remote source, Reviewer Lift reviewed commit, and current
provider commit must agree. A push invalidates prior review, CI, gate, and action
evidence until rebound. Incomplete files/contexts, unresolved required review,
stale head, wrong-commit CI, missing readback, or a provider `unknown/null`
native state fails closed.

## Single-change request checkout mode

Single-change-request review is the default and preferred mode: one change
request per fresh reviewer session. Before local commands or targeted checks,
use an isolated checkout where `git status --porcelain` is empty and the observed
`git rev-parse HEAD` equals the exact reviewed commit from a fresh
`forge snapshot`. If either check differs, the selected provider branch
materializes that exact commit and the reviewer recreates a detached isolated
worktree, then repeats both checks. Never run an arbitrary `git pull`.

For multiple independent changes, the parent/harness proves the Decoupling
Contract and gives each change request its own isolated checkout and fresh
reviewer. Serialized review never batches decisions, comments, or actions.

## Review method

1. Read the issue and acceptance criteria, then the complete diff.
2. Sweep declared Reviewer Focus and every changed safety/acceptance surface.
3. Trace only evidence-linked callers, schemas, generated copies, docs, and
   failure paths; confirm no compatibility alias or stale caller remains.
4. Verify behavior claims through public observable tests.
5. Perform a structural maintainability sweep across the full diff.
6. Only after checkout binding, run targeted checks needed to verify findings.
   Never mutate live product/operator systems as review evidence.

## Findings and tone

- `MF-N` — must fix before pass: correctness, safety, incomplete evidence,
  contract violation, unresolved required review, stale binding, or maintainable
  decomposition defect with concrete risk.
`Reject` publishes the Review Report, takes no approval or finish action, then stops and escalates to the human/parent.
- `SF-N` — non-blocking suggestion.
- `C-N` — clarification required for a decision.

Each finding records stable Review Report locator, originating 40-hex reviewed
commit, short ID, location, observable impact, evidence, and required outcome.
Style alone is non-blocking. Be direct and demanding on substance without
performative language.

## Structural maintainability sweep

Keep the sweep diff-first and blast-radius-bounded; expand outside the diff only
when concrete evidence identifies a caller, invariant, or failure path. Check
Code-judo simplification, hidden coupling, duplicated policy, shallow modules,
special-case branching, and wrong-layer helpers. A file growing from `<1000` to
`>1000` lines is a presumptive Must Fix without a compelling decomposition rationale.

Decision rule: material in-scope complexity may block as `MF-N`. Use `C-N` for
taste, speculative redesign, or out-of-scope cleanup.

## Review tone

Raise evidence-backed structural findings plainly: name the smell, location, and
bounded remedy. Tone never moves the bar. Do not request changes for taste;
taste, naming, and formatting remain non-blocking `C-N`.

## CI and Open Question decision tables

### CI decision table

| Bound CI state | Observable review/action policy |
|---|---|
| success on the exact reviewed commit or provider-proven integration candidate | pass/approval eligible when every other guard passes |
| pending/running | review may proceed; automatic or queued finish requires selected-provider proof of protected policy and exact binding |
| conditionally required job absent | allowed only when target-repo Check Gate or `project_profile` declares it not applicable and every applicable required job succeeds; rules-omitted is absent, not skipped |
| failed/canceled/skipped applicable CI | blocks pass, approval, and finish |
| missing/incomplete/unknown/wrong binding | blocks pass, approval, and finish |
| authorized written waiver | applies only to its recorded scope/provenance; reviewer cannot self-waive |

Absent conditionally required CI for any other reason blocks. Local Gate PASS,
readiness, or Gate coverage never substitutes for CI and never grants approval
or finish.

### Open Question decision table

| Observable class | Policy |
|---|---|
| answered from evidence | no blocker; record the evidence |
| builder evidence gap | `request-changes` with a bounded remedy |
| human/product/security decision | `blocked`; no approval |
| non-blocking | `C-N`, follow-up, or recorded rationale |

Use stable `OQ-N` IDs; no placeholder questions at publication.

## Finish authority source precedence

Explicit human/provider restrictions precede defaults; silence never grants finish.


## Approval-authority policy

Reviewer approval is `default-after-pass` only when stable repository policy
permits it and no stronger source restricts it. Approval authority is separate
from Finish authority. Missing/contradictory/unverifiable approval provenance
blocks approval, not the review judgment. Missing Finish authority blocks only
finish, never judgment or independently permitted approval. A builder never
grants or exercises approval.

Finish authority is one affirmative action-specific claim: `approval-only`,
`reviewer may merge`, `queue auto-merge`, `human release`, or an expressly
permitted project default. Silence never becomes `approval-only` and never
grants finish. `Finish owner: parent` always returns verdict/evidence to the
parent with approval `not-approved`, finish `none`, and next action
`finish-by-authorized-actor`.

## Default finish: queued auto-merge

When verdict is pass, finish authority affirmatively allows it, caller context is
eligible, and the selected provider offers an exact-reviewed-commit protected
queue, the default finish is queue auto-merge through one guarded `forge act`.
The commit-bound CI floor is intact: pending/running/success may queue only under
provider policy; failed/canceled/missing/stale CI blocks. Queue is not a CI waiver
and is never reported as merged.

GitHub auto-merge and merge queue are distinct. Azure DevOps auto-complete lacks
a documented expected-head binding, so an exact-commit queue request returns
`sha-bound-action-unsupported`. GitLab queue behavior remains in `/gitlab`.

## Publication and actions

1. Draft the Review Report with intended verdict, approval, and finish actions
   before final guards.
2. Take the final provider-native change-request, reviewed-commit, CI, authority,
   and caller snapshot.
3. If any guard fails, convert the verdict to `blocked` and update the draft
   before publication.
4. Use `forge publish` to create one durable non-blocking report with safe-body
   validation and byte-for-byte provider-native readback.
5. Immediately before an allowed action, take a fresh `forge snapshot` and run
   the common reviewed-commit guard. If the head changed after publication, skip
   approval and finish and record `stale-commit` in the action result and final
   handoff.
6. Perform exactly one authorized `forge act`.
7. Verify provider-native post-read and emit the action result plus final
   reviewer handoff. `Finish owner: parent` keeps approval `not-approved` and
   finish `none`.

## Review Report contract

The durable report contains provider/repository/change-request binding, stable
report locator, reviewed commit, complete-diff/discussion evidence, local gate,
CI commit/status, context capsule, Reviewer Lift verification, acceptance and
safety surfaces, findings, targeted checks, open questions, verdict, intended
and completed approval/finish actions, blocker/next action, and readback proof.
Never claim an action until provider-native post-read verifies it.
