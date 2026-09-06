# Review Flow

Canonical mandatory independent review policy for one bound GitLab, GitHub, or
Azure DevOps change request. Provider mechanics live behind `/forge`; this file
owns review judgment, evidence, severity, advisory CI/Open Question classifications,
authority, and action separation.
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
| CI | `<claimed advisory CI/local gate>` | `<verified local Gate Receipt and commit-bound CI observation>` | `<Tier 1 or Tier 2 locator>` |
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

Complete provider-native files, diffs, discussions, reviews, and required policy inputs are required; truncation, pagination uncertainty, or stale bindings block. CI absence or incomplete CI pagination is recorded as an advisory observation and does not make review coverage incomplete.
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
- configured CI contexts observed for the reviewed commit or provider-proven
  integration candidate, when available;
- exact-candidate local Gate Receipt and authority provenance locators.

Local checkout, remote source, Reviewer Lift reviewed commit, current provider
commit, and Gate Receipt candidate must agree before publishing a current pass.
A push invalidates prior review, gate, action, and reported CI pointers for the
new head; it never rewrites the historical report's reviewed commit or finding
identities. Incomplete files/contexts, unresolved required review, stale head,
or missing required evidence readback prevents pass. A provider `unknown/null`
native action state denies that action, not an otherwise valid judgment.
Missing, stale, wrong-commit, or red CI is advisory evidence, not a review or
action blocker.

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
- `C-N` — non-blocking consideration. Decision prerequisites use the existing
  [Open Question classification](#open-question-decision-table), not `C-N`.

Each finding records stable Review Report locator, originating 40-hex reviewed
commit, short ID, location, observable impact, evidence, and bounded remedy
(required for `MF-N`, optional for `SF-N`/`C-N`).
Style alone is non-blocking. Be direct and demanding on substance without
performative language.

Publish new optional `SF-N`/`C-N` findings in the plain, non-resolvable Review
Report or an explicitly non-blocking comment lifecycle. Reserve unresolved
change-request threads for actual requirements, including required Open
Questions; optional findings alone never require changes before pass.

Before resolving any existing thread, including an accidentally resolvable
report, inspect its full content and replies for outstanding requirements or
decisions. An `SF-N`/`C-N` identifier alone never authorizes resolution or bulk
resolution. Keep mixed-content threads unresolved until their requirements are
satisfied; classify decision prerequisites through the Open Question table.
Respect native resolution permissions and merge protections; report refusals
without bypassing them.

Lifecycle changes preserve the original `(Report locator, Reviewed SHA,
Finding ID)` tuple and applicable follow-up obligations for surviving `SF-N`
findings. Non-blocking severity does not waive finish bookkeeping.

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

| Observed CI classification | Evidence treatment |
|---|---|
| bound success | record provider locator, status, and exact reviewed/integration commit |
| bound pending/running | record as an as-of observation |
| bound failed/canceled/skipped | record as an as-of observation; investigate only when it reveals an actual in-scope defect |
| unavailable or missing | record that no provider status was available |
| stale, wrong-commit, incomplete, or unknown binding | do not attribute the status to the reviewed candidate; record the binding limitation |

Every classification is advisory. No provider CI status changes the review
verdict or approval, merge, queued-finish, or post-merge eligibility. The
required quality predicate is a passing exact-candidate local Check Gate and,
in parent-owned mode, its durable Gate Receipt. Independent review, reviewed-SHA
binding, authority/caller guards, exactly one mutation, and native readback are
separate mandatory predicates. Native provider protection may refuse a mutation;
report the refusal without bypassing it.

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
grants finish. `Finish owner: parent` is an intentional no-action route, not
missing authority: return verdict/evidence to the parent with approval
`not-approved`, finish `none`, action blocker `none`, and next action
`finish-by-authorized-actor` when review is valid. Review blockers still apply.

Classify the failed predicate, not the blocker token alone:

| Failed predicate | Review judgment | Action and routing |
|---|---|---|
| Incomplete coverage or missing required policy/context | `blocked`; no pass | No approval/finish; `partial-review`, `rerun-review` with the builder/parent restoring missing inputs |
| Wrong/ambiguous repository or unverified target binding | `blocked`; no pass | No approval/finish; `preflight-failure`, `fix-blocker` with the parent restoring binding |
| Head changed before publication | `blocked`; no current pass | No approval/finish; `changed-head-sha`, `rerun-review` by a fresh reviewer on the new head |
| Missing, invalid, or wrong-commit required local gate/Gate Receipt | No pass; `request-changes` for a builder evidence gap, otherwise `blocked` | No approval/finish; for revision use `none`, `revise`; otherwise `other` with the gate failure reason, `fix-blocker` with the gate owner |
| Compromised reviewer independence | `blocked`; no pass | No approval/finish; `human-decision-needed`, `rerun-review` from a fresh context |
| Authority/provenance absent, contradictory, or restricted only for the requested action | Retain the complete current review's judgment | Deny that action; `missing-authority`, `finish-by-authorized-actor` to the parent/authorized actor; a non-inferable authority decision uses `human-decision-needed`, `human-escalation` |
| Permission unknown or denied only for the requested action | Retain the complete current review's judgment | Deny that action; `permission-failure`, `finish-by-authorized-actor` to an actor with verified permission |
| Provider cannot bind the requested action to the reviewed commit | Retain the complete current review's judgment | Deny that action; `sha-bound-action-unsupported`, `fix-blocker` to the parent; no unbound substitute |

An action-only classification requires all review-validity predicates to hold.
For example, permission loss that prevents full diff access is incomplete review,
not merely action denial; caller/context uncertainty that compromises
independence cannot preserve pass. Security and human-decision review blockers
remain governed by the coverage, Context Firewall, and Open Question policies.
Every action guard remains mandatory, including for independently permitted
approval when finish is denied. Use existing
[`handoff-tokens.schema.json`](reference/handoff-tokens.schema.json) tokens and
align next action with the handoff's expected next actor/action.

## Default finish: queued auto-merge

When verdict is pass, the exact-candidate Gate Receipt is valid, finish authority
affirmatively allows it, caller context is eligible, and the selected provider
offers an exact-reviewed-commit protected queue, the default finish is queue
auto-merge through one guarded `forge act`. Provider CI remains advisory.
Native protection may hold or refuse the request; report that provider outcome.
Queued is non-terminal and is never reported as merged.

GitHub auto-merge and merge queue are distinct. Azure DevOps auto-complete lacks
a documented expected-head binding, so an exact-commit queue request returns
`sha-bound-action-unsupported`. GitLab queue behavior remains in `/gitlab`.

## Publication and actions

A `request-changes` verdict is not an action blocker: record approval
`not-approved`, finish `none`, action blocker `none`, and next action `revise`.
Use `other` only for a blocker no listed token names, and add a one-line reason
in the Review Report's Action / Blocker section.

1. Draft the Review Report with its verdict and intended or no-action approval
   and finish state before final guards; completed effects belong to later evidence.
2. Take the final provider-native change-request, reviewed-commit, local Gate
   Receipt, advisory CI, authority, and caller snapshot.
3. Classify failed predicates using [Approval-authority policy](#approval-authority-policy).
   Review-invalidating failures prevent pass; update the draft verdict and
   evidence gaps before publication. Action-only failures retain the valid
   judgment but deny the affected action with its blocker and next actor/action.
   An advisory CI classification is not a guard.
4. Use `forge publish` to create one durable non-blocking report with safe-body
   validation and byte-for-byte provider-native readback.
   `Finish owner: parent` reviewers return the two-line final handoff now,
   with approval `not-approved` and finish `none`; they neither act nor wait
   for the parent's action records.
5. Immediately before an allowed action, take a fresh `forge snapshot` and run
   the common reviewed-commit guard. If the head changed after publication, skip
   approval and finish and record `changed-head-sha` with `rerun-review` for a
   fresh reviewer in a [post-report action note](#post-report-action-evidence).
   Preserve the published judgment, original reviewed commit, and finding
   identities as historical evidence, not a pass for the new head.
6. Perform exactly one authorized `forge act` only when its guards pass and the
   finish owner permits it; otherwise emit the no-action result. An action-only
   failure after publication does not change the valid historical judgment;
   newly discovered invalid review evidence must be reported, not masked as
   action-only.
7. The authorized actor owns provider-native post-read and any required
   [action explanation](#post-report-action-evidence). Emit the two-line final
   handoff (change-request locator and Review Report note id); later action
   evidence stays in native notes, not extra final-response fields.

## Review Report contract

The durable report contains provider/repository/change-request binding, stable
report locator, reviewed commit, complete-diff/discussion evidence, local gate,
CI commit/status, context capsule, Reviewer Lift verification, acceptance and
safety surfaces, findings, targeted checks, open questions, verdict, intended
or no-action approval/finish state, and publication-time blocker/next action.
Publication readback establishes durability. Keep that report immutable:
later effects, blockers, or evidence corrections use a backlinking note,
not a regenerated verdict, changed reviewed commit, or renumbered findings.
The original report needs no unknown future action-note URL.

## Post-report action evidence

The authorized actor owns the action's native post-read. An action attempt,
provider refusal, or post-publication guard failure requires a compact plain
non-blocking action explanation note on the same change request. Intentional
parent-owned reviewer no-action needs no extra note.

Publish through `forge publish`, with safe-body validation and byte-for-byte
native readback. Include the original report's stable identity and published
locator, exact reviewed commit, actor and authority source, action attempted
or denied, whether a mutation ran, verified outcome or explicit unverified
state, blocker/reason, next actor/action, and native evidence locators with
as-of observations. A changed head records both reviewed and observed commits.
Use existing blocker tokens; `other` requires a one-line explanation.
Never claim success from a mutation response alone; queued is not merged.
This note explains the action, not a second review verdict or authority grant.

The next actor discovers the note through existing provider-native
change-request notes/discussions, following pagination through the relevant
post-report records. Match the backlink to the retrieved report's stable
identity, published locator, repository/change request, and exact reviewed
commit; verify the note author/authority and cited native outcome evidence.
Read the complete note and relevant replies, not a search snippet or latest-note
guess. Historical outcomes do not authorize a new action: re-read current head,
Gate Receipt, and authority through the common guard.

A missing required note, incomplete discovery, failed publication readback,
or mismatched backlink/evidence leaves the action record unverified. Preserve
any independently verified native effect, report the evidence gap, and route
the authorized actor to restore durable evidence; do not infer success from
report intent or repeat a possibly completed mutation to repair a note.
If publication is unavailable, return the explicit transport blocker rather
than a fabricated note ID. Parent-owned reviewer completion never depends on
the later actor producing this note.
