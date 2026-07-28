# Parent-owned Check Gate and Gate Receipt

This is the canonical seam for parent-owned Check Gate mode. Other build,
review, delivery-loop, and template docs point here instead of redefining the
ownership fields, Gate Receipt schema, parent verification checklist, or
ready-transition evidence.

Use this mode when a child builder has completed the implementation but the
parent coordinator owns the final local Check Gate and Draft-to-ready transition.
The child leaves the MR Draft and hands the parent a candidate SHA; the parent
runs the repo Check Gate on that exact SHA, posts one Gate Receipt MR comment,
and only then performs the ready transition.
As gate evidence, the child records only the parent-owned/not-run contract and
candidate SHA; that candidate SHA is the only child-provided gate evidence. It may point at the project Gate coverage mapping as a routing
claim, but it must not claim local gate `PASS`/`FAIL`, Gate Receipt success, or
uncovered CI satisfaction.

## Resource addressing

When this workflow runs from another target repo, reference skill-owned resources
with `skill://start-build/...`:

- `skill://start-build/reference/parent-owned-gate.md`
- `skill://start-build/templates/gitlab-delivery-schema.md`
- `skill://start-build/templates/reviewer-lift-schema.md`
- `skill://start-build/templates/builder-final-handoff.md`
- `skill://start-build/templates/review-packet.md`
- `skill://start-build/scripts/validate-gate-receipt.mjs`

Target-repo policy remains repo-relative. The full project Check Gate command and
policy are read from `docs/agents/check-gate.md` in the target repo, not from a
`skill://start-build/...` resource.

## Ownership contract

Child builders must not claim gate pass/fail in this mode; they record this contract when the parent owns the Check Gate:

```yaml
local_gate_owner: "parent"
builder_gate_status:
  status: "not-run"
  not_run_reason: "parent-owned"
ready_transition_owner: "parent"
```

Semantics:

- `local_gate_owner: "parent"` means the parent, not the child, must run the full
  local Check Gate before ready/review.
- `builder_gate_status.status: "not-run"` means the child intentionally did not
  run or claim the parent-owned gate.
- `builder_gate_status.not_run_reason: "parent-owned"` distinguishes this valid
  handoff from missing evidence.
- `ready_transition_owner: "parent"` means the child must leave the MR Draft; the
  parent posts the Gate Receipt and marks ready after the receipt passes.
- Child handoff gate evidence is limited to `local_gate_owner: "parent"`,
- `builder_gate_status.status: "not-run"`, `not_run_reason: "parent-owned"`,
- `ready_transition_owner: "parent"`, and the exact candidate SHA. Any Gate
- coverage row remains a policy/routing claim until the parent verifies it.
- If issue acceptance criteria include literal target strings with byte-for-byte wording requirements, the child must also hand off targeted exact-string comparison evidence bound to the candidate SHA. Keep this requirement scoped to literal-string acceptance criteria; do not expand it into broad ceremony for ordinary prose/docs edits.

This contract must appear in the Reviewer Lift / MR description and in the child
builder final handoff when a compact `delivery.kind=gitlab-delivery` block is
present. It does not make the Gate Receipt a substitute for the full project
Check Gate.

## Gate Receipt schema

Anchor: `gate_receipt.kind=gate-receipt`. The parent posts this as an MR comment
for the exact candidate SHA before the MR is handed to review.

```yaml
gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "parent"
  mr_iid: "123"
  issue_iid: "57"
  checkout_path: "/absolute/path/to/verified/checkout"
  checkout_sha: "1111111111111111111111111111111111111111"
  status_before: "draft"
  status_after: "ready"
  command: "<target repo Check Gate command per docs/agents/check-gate.md>"
  result: "PASS"
  summary: "full project Check Gate completed successfully"
  preflight_checks:
    - name: "clean-status-before"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty"
    - name: "tracked-files-unchanged-after"
      command: "git status --porcelain"
      result: "PASS"
      summary: "empty; no tracked files changed during preflight/gate"
  evidence:
    - tier: "tier-1"
      kind: "local-gate"
      source: "MR comment or run artifact URL/path"
      summary: "command, checkout SHA, and result"
  observed_at: "2026-06-01T00:00:00Z"
```

`observed_at` is optional. Every other field is required so the parent, reviewer,
and finisher can bind the receipt to the exact MR, issue, checkout, SHA, command,
status transition, preflight state, and evidence.

## Pre-post validation and exact note binding

Render the Gate Receipt once to `<receipt.yml>`. Before creating the durable MR
note, validate every field whose value exists before GitLab assigns a note ID:

```text
node skill://start-build/scripts/validate-gate-receipt.mjs --mode pre-post --receipt "<receipt.yml>" --mr-iid "<MR IID>" --issue-iid "<issue IID>" --reviewed-sha "<current MR head SHA>" --gate-command "<project Check Gate command>"
```

A nonzero result stops before any note mutation. On success, read the same
artifact and pass those exact bytes as the `body` to
`safe_create_merge_request_note`; do not render a second copy. Re-read the
created note with `get_merge_request_note` and require its body to equal
`<receipt.yml>` byte-for-byte before updating the Reviewer Lift or handing off.
The post-note validation below remains mandatory because it binds the assigned
note ID and current Reviewer Lift before ready.

## Pre-ready validation

Before the GitLab Mutation Guard's ready mutation, run the cross-platform,
pure-local validator against the canonical receipt and current Review Packet.
Pass the current Gate Receipt comment's numeric note ID so the Review Packet
cannot point at an older receipt on the same MR:

```text
node skill://start-build/scripts/validate-gate-receipt.mjs --receipt "<receipt.yml>" --review-packet "<review-packet.md>" --mr-iid "<MR IID>" --issue-iid "<issue IID>" --reviewed-sha "<current MR head SHA>" --gate-receipt-note-id "<current Gate Receipt note ID>" --gate-command "<project Check Gate command>" --gate-policy-ref "<project gate policy ref>"
```

Any nonzero result stops the ready transition before a GitLab mutation. The
validator binds the receipt and Reviewer Lift to the supplied MR, issue, SHA,
current Gate Receipt note, gate command, and policy; it does not replace the
checklist below.

This receipt check does not validate review-finding identity. When Reviewer Lift `Finding bindings` is non-`none`, separately run `node start-review/scripts/validate-finding-bindings.mjs --report <originating-report.md> ... --lift <review-packet.md>` per `../../start-review/reference/finding-identities.md`; any missing, stale, ambiguous, or contradictory tuple also stops the ready mutation. A `none` Lift can be checked without report inputs.

## Parent verification checklist

A single parent ready-transition check is enough when every item below is true:

1. Project binding is verified through `/gitlab` for the target repo, MR,
   source branch, target branch, issue IID, and default branch.
2. The MR is Draft, links the intended issue with `Closes #<iid>`, and targets the
   expected default branch.
3. The child handoff, Reviewer Lift `Reviewed SHA`, MR head SHA, and remote source
   branch all name the same candidate SHA.
4. If issue acceptance criteria name literal target strings with byte-for-byte wording requirements, the Reviewer Lift / `Acceptance Criteria Evidence` section includes targeted exact-string comparison evidence bound to the same candidate SHA, and the parent spot-checks that evidence before ready-marking or launching re-review in parent-owned gate mode.
5. Candidate checkout is clean before gate and `checkout_sha` equals the candidate SHA.
6. The command from target `docs/agents/check-gate.md` runs on the exact checkout SHA and returns `PASS`.
7. Gate coverage is classified `full-local`, `hybrid`, or `ci-only` (never `parent-owned`). For `hybrid`/`ci-only`, review launch does not wait for terminal-success exact-SHA CI: record the current exact-SHA status for every uncovered required job, and allow pending/running CI through the ready transition. Failed, canceled, skipped, missing, stale, or wrong-SHA required CI blocks pass eligibility and every finish action unless an authorized CI waiver is recorded.
8. Post-gate status check shows tracked files unchanged. If tracked files
changed during preflight gate, block ready/merge unless the changes are
committed to MR head and gate reruns on the new SHA, or an explicit
parent/human waiver is recorded in Gate Receipt MR discussion.
9. Gate Receipt MR comment uses `gate_receipt.kind=gate-receipt` and includes
every required field above, including `result: "PASS"` and `checkout_sha`
equal to the exact candidate SHA.
10. Immediately before marking ready, MR head still equals receipt
`checkout_sha`; if changed, block and rerun checklist on the new SHA.
11. Ready mutation follows GitLab Mutation Guard post-mutation re-read and
confirms the expected MR state.
12. Each acceptance surface declared in builder's Reviewer Lift
`Acceptance surfaces` row drawn from the project's
`project_profile.acceptance_surfaces_ref` vocabulary has `test`, `smoke`,
`docs-read`, `ci`, or documented `N/A — <reason>` evidence verified from Tier
1 / Tier 2 sources before ready transition. When project declares no
`acceptance_surfaces_ref`, row fail-closed to `[]` / `none`; any non-empty
surface value or unresolvable surface ref blocks ready transition as a schema
defect.
13. Reviewer Lift `Finding bindings` is `none` or the pure-local finding-binding validator passed against every originating Review Report; parent ready-marking never relies on a bare reused short ID.

## Evidence-ready handoff tokens

These pointers make the next actor safe to proceed without another
parent/builder/reviewer clarification loop:

- `mr-description-reviewer-lift-current` — Reviewer Lift is present, current, and
  names the candidate SHA plus the ownership contract.
- `candidate-sha-pushed` — `git rev-parse HEAD`, MR head metadata, and
  `git ls-remote origin <source_branch>` agree on the candidate SHA.
- `gate-receipt-exact-sha-pass` — the Gate Receipt is present, required fields are
  filled, `result: "PASS"`, and `checkout_sha` equals the reviewed SHA.
- `ready-transition-post-reread` — after ready-marking, a post-mutation re-read
  confirms the MR state and unchanged head SHA.

Before the Gate Receipt exists, a child builder handoff should route to
`phase: "parent-gate"`, `expected_next_actor: "parent"`,
`expected_next_action: "parent-run-gate"`, `blocked: false`,
`required_parent_decision: "none"`, and evidence pointers such as
`mr-description-reviewer-lift-current` and `candidate-sha-pushed`.

After the Gate Receipt, the candidate SHA and a passing Gate Receipt are sufficient to mark ready and launch review while exact-SHA CI is pending. Reviewers still treat the receipt as a claim/source pointer and independently verify SHA, CI/local-gate, authority, scope, diff evidence, and any builder/parent exact-string comparison claims before pass, approval, or finish. Failed, canceled, skipped, missing, stale, or wrong-SHA required CI remains fail-closed for pass eligibility and every finish action unless an authorized CI waiver is recorded. Builder/parent exact-string evidence does not substitute for independent reviewer verification.

## Gate Receipt as canonical gate evidence; delta-sized MR description updates

The Gate Receipt MR comment is the canonical record of the parent-owned gate result. Once a Gate Receipt is posted:

- Do not duplicate the Gate Receipt content into a full MR description rewrite. The Reviewer Lift in the description must stay current, but the Gate Receipt comment is the authoritative gate evidence source.
- MR description updates after a Gate Receipt is posted must be delta-only: update only fields whose content actually changed — for example, `Reviewed SHA` when a post-receipt fix was committed, or a provenance pointer when the authority source changed. Do not repeat the full Gate Receipt body, parent reasoning, or prior Reviewer Lift narrative as description prose.
- Token-heavy full MR description rewrites duplicate canonical evidence, create reviewer confusion about which record to trust, and inflate context with stale parent reasoning. Keep post-receipt updates minimal.

This rule does not reduce required Reviewer Lift fields: all required fields must remain present and current. It governs only the verbosity of post-receipt description updates.

## Stale exact-SHA evidence fails closed after a revision push

A Gate Receipt binds its `result: "PASS"` to one exact `checkout_sha`. After any post-ready revision push moves the MR head, that receipt is tied to an **older SHA** and is **stale evidence** for the new reviewed SHA. It does not count as gate evidence for the new SHA **until a new exact-SHA Gate Receipt** with `checkout_sha` equal to the new reviewed SHA exists. The reviewer must not re-derive a current receipt from GitLab history; re-review fails closed on stale exact-SHA evidence rather than proceeding from it.

So on every post-ready revision push in parent-owned gate mode, the parent or builder must refresh the exact-SHA pointers in the Reviewer Lift before re-review is requested:

- `Reviewed SHA` → the new head SHA.
- CI pointer (`CI pipeline` / `Gate coverage rationale` CI mapping) → rebound to the new SHA; older-SHA CI is stale until rebound.
- Gate Receipt pointer → point at the new exact-SHA Gate Receipt comment; the older-SHA receipt pointer is stale and must not be presented as current gate evidence.
- `Delta since last ready push` → old SHA → new SHA, reason, changed files, gate rerun, and whether the change is substantive.

This stays delta-sized: refresh only the pointer fields and post the new Gate Receipt as its own MR comment. Do not duplicate the Gate Receipt body into the MR description.
