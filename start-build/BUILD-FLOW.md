# Start Build Flow

Detailed workflow for `start-build`. Read before selecting issue(s), creating/updating MR(s), commenting, or marking ready. Assumes you've already read [SKILL.md](SKILL.md) for purpose, GitLab handoff, and the Issue pickup summary (Quick start step 1 covers `gitlab-local` preflight), plus the host project's issue-tracker guide or `gitlab-local` for canonical snippet names and flag pitfalls.

## Issue pickup

Issue pickup policy stays inline because it controls which work is safe to start.

1. Run `gitlab-local` **Snippet: local-repo-preflight** to confirm cwd is the intended git repo and `glab` resolves to it. If it fails, stop and ask.
2. Use `gitlab-local` **Snippet: issue-pickup** to list candidates (narrow via `--label`, `--assignee=@me`, `--author`, `--milestone` as project conventions dictate). Inspect 3-5 candidates — enough to validate coupling when multiple are in play.
3. Prefer open issues that are unassigned or `@me`, ready/triaged, clear, unblocked, and fit one MR.
4. For multiple, select only a set that satisfies the shared [Decoupling Contract](../docs/decoupling-contract.md).
5. Deprioritize blocked issues, issues with the project's information-needed or human-decision equivalent, in-progress/WIP items, and confidential/security-sensitive issues unless explicitly requested.
6. Inspect candidates with `gitlab-local` **Snippet: issue-pickup**; summarize ID, title, labels, assignee, suitability, coupling risk.
7. If one issue/set is clearly best, announce and proceed. If several are plausible or coupled, ask the user to choose.
8. Claim issues only when project convention is clear; do not create/mutate labels casually.

## Multiple issue worktree mode

Use when the user supplies multiple issues, asks for multiple tasks, or requests more than one issue at once. This heading remains in `BUILD-FLOW.md` as the stable anchor; detailed worktree setup, decoupling proof, and cleanup rules live in [reference/multiple-worktrees.md](reference/multiple-worktrees.md).

Core policy stays inline:

- Prove every item in the [Decoupling Contract](../docs/decoupling-contract.md) before parallel work; if any item is false, unknown, or contradicted by evidence, treat the work as coupled.
- Use the original checkout as coordinator-only during multi-issue runs.
- Run the normal implementation flow independently in each issue worktree: one issue, one branch, one Draft MR, one check gate, one Review Packet.
- In child `mr-builder` mode, do not launch builders or reviewers; the parent orchestrator owns delegation.
- Keep artifacts and evidence local to the owning worktree/MR.

## Discovery Budget

Keep discovery bounded before edits. Read the issue, project rulebook, linked docs, and only the concrete callers/tests/ADRs needed to establish current behavior, affected surfaces, test entrypoint, safety constraints, and non-goals. Stop expanding once those facts are evidence-backed; do not do open-ended repo spelunking.

If any required fact is still missing after that budget, stop, write the exact unanswered questions, and route the issue back to triage instead of guessing requirements or starting edits.

## Build Plan Packet

Before the first edit, write a concise Build Plan Packet from the discovery result. Capture the issue, intended behavior, affected surfaces, test plan, risk, and non-goals. Keep it short enough that reviewers can compare it against the issue and diff without reading a long workflow body. Use [`templates/build-plan-packet.md`](templates/build-plan-packet.md) as the shape.

This packet is pre-edit planning only; builder and reviewer authority boundaries stay in [Builder invocation modes](#builder-invocation-modes).

## Builder invocation modes

Use the mode supplied by the caller or agent prompt; when no parent orchestrator is delegating work, default to standalone `/start-build` mode.

### Standalone `/start-build` mode

- The builder owns the mandatory review gate after marking the MR ready.
- The builder spawns a fresh reviewer, waits for the Review Report, drives any revision rounds, and posts the Review Gate Summary.
- The builder never self-approves or self-merges.

### Child `mr-builder` mode

- The child builder implements the issue, opens/updates the Draft MR, marks it ready, and stops at final handoff.
- The parent orchestrator owns the mandatory review gate and any merge allowed by policy or human instruction.
- The child builder does not spawn a reviewer unless the parent explicitly instructs it to.

Minimum final handoff when the parent owns the gate:

- MR URL/IID
- `head_sha` and `reviewed_sha` (same MR head commit; `reviewed_sha` is the SHA the reviewer must read)
- CI status
- Local gate evidence
- RED/GREEN or TDD N/A rationale
- Changed paths
- Touched safety surfaces
- Decoupling proof
- Reviewer focus
- Open questions
- Merge authority
- Merge authority source
- Blockers

Mandatory independent review remains required in both modes unless a human explicitly documents a bypass. Builder self-approval and self-merge remain forbidden.

## Parent-orchestrator recipe

Use this recipe when a parent orchestrator coordinates child `mr-builder` and
`mr-reviewer` agents for a GitLab issue-to-MR loop. Project rulebooks may
specialize labels, local gates, merge authority defaults, merge authority source
requirements, run artifact paths, and post-merge checks, but they must not weaken
the safety invariants in this flow:
child builders do not spawn reviewers, approve, or merge; independent review
stays mandatory unless explicitly bypassed by a human; reviewed SHAs and CI
results stay bound to the MR head before approval or merge; and credentials or
product/runtime/operator external systems are not exposed through workflow artifacts.

### Durable child outputs

Parent-readable handoffs must survive isolated worktree cleanup. Do not rely on
`worktree:true` plus a relative `output` path plus `outputMode:"file-only"` for
any artifact the parent must read later: that combination can return a path
inside a temporary `pi-worktree-*` checkout, and parent reads can fail after the
worktree is removed.

Safe patterns:

- Prefer inline child output for the parent handoff when size permits.
- If a file output is required, have the caller create a durable run directory
  outside any `pi-worktree-*` path, then pass an absolute output path under that
  directory and ensure the parent directory exists before launch.
- If a child returns a stale temporary-worktree output path, recover from async
  run logs or other durable run artifacts when available; do not treat the
  missing local file as the canonical delivery record.
- For GitLab delivery, the MR description's Reviewer Lift / Review Packet and
  GitLab comments are the canonical durable handoff. Local handoff files and run
  artifacts are convenience copies only.

### Parent loop

1. **Resolve issue(s).** Read the issue, comments, labels, linked MRs or parent
   design docs, and project rulebook. Confirm each issue is `ready-for-agent` or
   otherwise approved for agent work. If multiple issues are in scope, prove the
   Decoupling Contract before parallel work; otherwise process issues serially in
   dependency order.
2. **Prepare isolated work.** Verify clean status, fetch the target branch, and
   create the source branch or one isolated worktree per decoupled issue. The
   parent checkout remains coordinator-only during multi-issue runs.
3. **Discover and run child `mr-builder`.** If the parent runtime exposes the
   `subagent` API, call `subagent({ action: "list" })` and look for agents whose
   name or description indicates issue-implementation specialization (for
   example `mr-builder`, `gitlab-builder`, or a project-scope `builder`/`worker`
   override). Prefer project-scope agents over user-scope agents over a builtin
   `worker`. Start one builder per issue/worktree with one issue URL/IID, one
   worktree, the target branch, the project rulebook, local Check Gate, quoted
   merge authority plus source, and any run directory. Never let two agents share a checkout,
   branch, temp DB, port, or uncommitted artifact directory. The builder owns
   implementation, Draft MR creation, Review Packet and Reviewer Lift updates,
   local gate evidence, ready-marking, and final handoff. In child mode the
   builder stops there; it does not spawn a reviewer, approve, merge, or clean
   up the parent-owned run.
4. **Parent spot-check.** Before review, validate the builder handoff and MR via
   `gitlab-local` snippets: MR URL/IID, `Closes #...`, source and target branch,
   pushed branch, current MR head SHA, builder `head_sha`, builder `reviewed_sha`,
   Reviewer Lift `Reviewed SHA`, pipeline SHA when exposed,
   changed paths, touched safety surfaces, decoupling proof, local gate result,
   open questions, merge authority, and merge authority source. Escalate if the handoff is missing,
   stale, out of scope, or contradicts the issue/rulebook.
5. **Discover and run `mr-reviewer`.** If the parent runtime exposes the
   `subagent` API, call `subagent({ action: "list" })` and look for agents whose
   name or description indicates MR / code-review specialization (for example
   `mr-reviewer`, `gitlab-reviewer`, or a project-scope `reviewer` override).
   Prefer project-scope agents over user-scope agents over a builtin reviewer.
   Start a fresh reviewer session with the MR URL, pointer to the MR Reviewer
   Lift block, project rulebook, and any run directory. The reviewer posts one
   Review Report for one reviewed SHA, then returns the parseable reviewer final
   handoff from `start-review/templates/reviewer-final-handoff.md` after any
   authorized action attempt. The GitLab Review Report remains the durable
   review record; the final handoff is a parent-orchestrator parsing aid.
   Approval or merge actions remain limited by the explicit merge authority and
   verifiable `Merge authority source` in the Review Packet, parent/human
   instruction, or project rulebook.
6. **Drive the decision loop.** On `approve`, run the SHA/CI guard before any
   finish action. On `request-changes`, send the finding IDs and reviewed SHA to
   the builder; require fix commits, targeted evidence, a full local gate when
   substantive, a file-backed revision note, and updated Reviewer Lift before a
   fresh reviewer session reads the new SHA. On `reject`, stop and escalate. On
   reviewer timeout, try one fresh reviewer session, then escalate. Keep the
   three-round review limit from the mandatory review gate.
7. **Enforce SHA and CI guards.** Before approval, merge, or auto-merge, re-read
   MR metadata and require the current MR SHA to equal the reviewed SHA. Treat CI
   as valid only when it is for that SHA. Red, canceled, skipped, missing, or
   stale CI blocks merge unless an authorized human records an explicit waiver.
   Pending CI may only be accepted under the CI-pending review policy in this
   flow and protected merge checks.
8. **Finish by authority.** For `approval-only` or `human release`, stop after
   reporting reviewed SHA, CI, and blockers. For `reviewer may merge` or
   `queue auto-merge`, only an authorized reviewer or parent may approve, merge,
   or queue with the reviewed SHA; a child builder still must not approve or
   merge. After merge or queueing, fetch the target branch, verify issue closure
   or pending closure, remove clean worktrees, and delete source branches only
   when project policy allows.
9. **Verify after merge.** Keep post-merge verification separate from review.
   The parent or verifier follows the [Post-merge verifier recipe](#post-merge-verifier-recipe)
   to confirm merged/default-branch state without taking reviewer authority.
10. **Archive local artifacts.** Keep local run artifacts redacted and untracked.
    Local handoff files are convenience artifacts only. Durable handoff stays in
    GitLab MR descriptions and comments, using file-backed comments for
    multiline updates.

### Post-merge verifier recipe

This compatibility heading preserves the `#post-merge-verifier-recipe` anchor.
Load the first-class [`/post-merge-verifier`](../post-merge-verifier/SKILL.md) skill for the read-only verifier contract and report shape.
Use `/gitlab-local` for command syntax; keep this section pointer-first for inbound links.

Core verifier policy stays inline: use this recipe only after independent review
and authority-aware finish steps report that merge or protected auto-merge
completed. The verifier confirms merged/default-branch state, linked issue state,
source-branch cleanup state, and documented non-mutating post-merge validation.
It must not approve, reject, merge, queue auto-merge, delete remote branches,
force-close issues, or run mutating release/deploy/operator validation unless a
human has explicitly authorized that operator action and the project workflow
documents how to record it.

## Check gate discovery

Before you claim the full local gate is green, discover it in this order:

1. Project rulebook / contributor docs (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README).
2. Build scripts (`Makefile`, `package.json`, task runner config, language-specific project files).
3. CI configuration (`.gitlab-ci.yml`, included pipeline files) to mirror the project gate locally where practical.
4. If still ambiguous, ask the user or state the limitation in the MR before requesting review.

## Handoff integrity checklist

Before marking ready or requesting review, validate the MR handoff:

- Reviewer Lift exists and its rows match `templates/reviewer-lift-schema.md`. Full and compact packets carry approved generated-copy blocks from that schema.
- `Reviewed SHA` equals the MR head SHA at the time you mark ready.
- CI pipeline evidence includes pipeline URL/ID, status, and commit SHA when available; pipeline SHA must match `Reviewed SHA` before treating green CI as evidence.
- No placeholder `OQ-1` remains; Open Questions is either `none` or lists real stable IDs.
- Local gate command/result is present, or N/A explains why only CI can provide it.
- Post-ready pushes have a delta comment and an updated Reviewer Lift.
- Merge authority is explicit and treated as a quoted claim, not a builder grant.
- Merge authority source is present and verifiable; missing or conflicting source information blocks approval/finish actions until a parent/human/rulebook source resolves it.

## Implementation flow

1. Resolve the issue(s) first: supplied or via pickup. If multiple, enter **Multiple issue worktree mode** and run the rest independently per worktree.
2. For a single issue, start clean from latest default branch:
   - `git status --porcelain` empty. If dirty, stop and ask — never auto-stash, reset, or clean.
   - `git fetch origin`.
   - `git checkout <default>` (use `default_branch` from `gitlab-local` **Snippet: local-repo-preflight** if not `main`).
   - `git pull --ff-only origin <default>`. If FF fails, stop and ask; do not force.
   - Confirm `git rev-parse HEAD` matches `origin/<default>` before branching.
   - Branch using the project's naming convention; reference the issue ID.
3. Load narrow context, not the whole repo or conversation: rulebook, issue, affected docs/source/tests, and ADRs only when they touch the issue. Expand outward only from concrete evidence such as imports/callers, failing tests, changed paths, or safety invariants.
4. Open a **Draft MR** early targeting the default branch, linked via `Closes #<id>`, after the source branch exists remotely. Use `gitlab-local` **Snippet: draft-mr-create-update** with `templates/review-packet.md` (or compact variant when eligible). Fill **Builder** metadata as `@builder — <model-id>` (e.g. `@builder — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing. Initialize the **Reviewer Lift** block from `templates/reviewer-lift-schema.md` — leave fields with `<pending>` until you have values, but keep the block present from day one so the reviewer's lookup path is stable. Fill `Merge authority` as a quoted claim and `Merge authority source` as verifiable provenance; the builder cannot grant approval, merge, or auto-merge authority.
5. For behavior-touching changes, implement vertical slices per the `tdd` skill. Commit coherent green slices, referencing issue/slice; revision commits cite review-thread items (e.g. `MF-1: <fix>`). For docs-only/config-only/mechanical work, state `TDD: N/A` and why in the MR — don't fake tests.
6. Use the smallest public layer that proves behavior without coupling to internals: pure unit tests for deterministic logic; adapter tests with fakes/recorded HTTP; state tests in temp dirs/throwaway DBs; orchestration tests with fake clocks verifying call ordering and calls *not* made; migration smoke tests; the project's full check gate before requesting review; coverage gate where required.
7. Run targeted tests during the red-green loop. Never use live product/runtime/operator external systems as regression evidence.
8. Update the MR description: diff summary, acceptance-criteria evidence, safety evidence, TDD trace (or `TDD: N/A` rationale), full test/check-gate output or CI link. **Keep the Reviewer Lift block current** — fill each field per `templates/reviewer-lift-schema.md` as values become available. Use stable `OQ-N` IDs in the body so the reviewer can answer each one.
9. Mark ready with `gitlab-local` **Snippet: draft-mr-create-update**. Then follow the active [Builder invocation mode](#builder-invocation-modes): standalone `/start-build` proceeds to the [Mandatory review gate](#mandatory-review-gate) below; child `mr-builder` stops at the documented final handoff for the parent orchestrator.
   - **Don't block ready-marking on CI when the full local check gate is green.** The local gate (lint, format, typecheck, full test suite, etc.) is the same check CI runs; once green and pushed, mark ready immediately. CI is the reviewer's clean-checkout safety net, not a builder-side wait.
   - Wait for CI before ready only when (a) the local gate could not be run (missing tooling, OS-specific job, unreachable integration suite) or (b) the change touches CI infrastructure itself. Say so explicitly in the MR.
   - **CI-pending review policy.** A reviewer may approve and queue auto-merge while CI is pending only when the local gate is PASS, the pending pipeline is for the reviewed SHA when GitLab exposes the SHA, and GitLab merge checks enforce green CI before merge. Red CI or stale green CI remains a blocker unless explicitly waived.
   - **Post-ready push protocol.** If you push any commits after marking ready (CI fix, review revision, rebase, anything), post an MR comment naming old SHA → new SHA, reason, changed files, gate rerun, and whether the delta is substantive. Update `Reviewer Lift > Reviewed SHA`, `CI pipeline`, and `Delta since last ready push`. Use `templates/revision-packet.md` for substantive post-ready changes, not only formal request-changes responses. The reviewer is told to refuse approval of a SHA they haven't read; silently pushing after ready risks merging unreviewed commits.
   - If CI later goes red, treat it like other review feedback: fetch logs, diagnose, fix, push a commit (with the post-ready delta comment). Don't unilaterally re-Draft.
10. If changes are requested, push fixes as new commits and reply to each thread. Builder replies with evidence; the reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution. Update the MR description with a brief revision summary and post `templates/revision-packet.md` as a comment. In standalone `/start-build` mode, run a **new** reviewer session (fresh session, fresh context) per the [Mandatory review gate](#mandatory-review-gate) protocol. In child `mr-builder` mode, return the revision handoff; the parent orchestrator starts the fresh reviewer.

## Compact packet eligibility

Use `templates/review-packet-compact.md` when the diff is simple enough that a short MR description suffices: docs-only, tests-only with no runtime impact, typo/lint, or dependency bump with no API impact. The compact packet carries the same approved generated-copy Reviewer Lift rows from `templates/reviewer-lift-schema.md` as the full packet, using explicit `N/A`/`none` values. Default to the full template when a broader map helps the reviewer.

## Stuck protocol

This compatibility heading preserves the `#stuck-protocol` anchor. Detailed stuck handling lives in [reference/stuck-protocol.md](reference/stuck-protocol.md).

Core policy stays inline: if blocked for more than 2 hours, keep the MR in Draft, post `templates/stuck-packet.md` as an MR comment via `gitlab-local` **Snippet: note-comment-creation**, apply the documented unblock label if one exists, list ranked hypotheses, and park the branch/worktree or switch only on a fresh branch/worktree.

## Mandatory review gate

In standalone `/start-build` mode, the builder owns reviewer handoff and must
start a fresh reviewer through whatever orchestration mechanism the runtime
provides; this gate is mandatory, not optional. If that runtime has no
reviewer-launch mechanism, stop and report the blocker instead of self-reviewing.
In child `mr-builder` mode, the parent orchestrator owns this gate after the
child returns its final handoff; the child builder must not start a reviewer
unless explicitly instructed. The builder never self-approves or self-merges (see
[SAFETY.md](SAFETY.md) non-negotiables). Builder and reviewer may share the same
GitLab username/PAT — review independence comes from session/context separation,
not GitLab identity. Concrete tool calls for parent-managed discovery live in the
[Parent-orchestrator recipe](#parent-orchestrator-recipe), not in child builder
instructions.

### Reviewer launch protocol

When you own this gate after the MR is ready:

1. **Discover available reviewers** using the runtime-specific agent discovery
   mechanism available to the owner of the gate. Look for agents whose name or
   description indicates MR / code-review specialization (for example
   `mr-reviewer`, `gitlab-reviewer`, or a project-scope `reviewer` override).
   Prefer project-scope agents over user-scope agents over builtin reviewers. If
   a specialized MR reviewer is found, use it; otherwise fall back to the
   builtin reviewer.
2. **Start** the selected reviewer running `start-review` in a fresh session. The
   task prompt must include:
   - **MR URL** — the full GitLab MR web URL.
   - **Reviewer Lift pointer** — direct the reviewer to the Reviewer Lift block in the MR description so it can copy structured values into the Review Report.
   - **Project rulebook path** — the path to the project's `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or equivalent rulebook so the reviewer can evaluate against project-specific rules.

Example task prompt template:

```text
Review MR: <MR web URL>
Reviewer Lift block is in the MR description — lift structured values into your Review Report.
Project rulebook: <path to rulebook>
```

### Review loop

1. **Start** a fresh reviewer session.
2. **Wait** for the Review Report. Timeout: 10 minutes per round.
3. **Evaluate** the reviewer's decision:
   - **Approve** — reviewer records approval for the reviewed SHA, then finish per `Merge authority`. If authority is `approval-only` or `human release`, stop after approval and report the reviewed SHA. If authority is `reviewer may merge` or `queue auto-merge`, only the reviewer, an authorized parent, or a human may merge or queue with the reviewed SHA. If GitLab blocks reviewer-side merge or queue, report the blocker and route finish to an authorized parent or human; the builder must not merge as a fallback. For safety-critical tasks, link the MR from any durable decision log the project keeps. Record the reviewed SHA and decision.
   - **Request changes** — push fix commits (each commit subject naming the item ID, e.g. `MF-1: <fix>`), post a revision-packet comment, update the MR description and Reviewer Lift, then start a **new** reviewer session (fresh session, fresh context — never reuse the same reviewer session).
   - **Reject** — hard stop. Do not spawn another reviewer on the same MR. Escalate to human immediately.
4. **3-round limit:** up to 3 rounds total (initial + 2 retries). If all 3 rounds result in request-changes, escalate to human with full context (round count, Review Reports, remaining Must Fix items).

### Timeout handling

This compatibility heading preserves the `#timeout-handling` anchor. Detailed timeout handling lives in [reference/timeout-handling.md](reference/timeout-handling.md).

Core policy stays inline: if no Review Report comes back within 10 minutes, do not retry the same reviewer session; start one fresh reviewer session with the same task prompt; if the second attempt also times out, escalate to human.

### Review Gate Summary

After all rounds complete (approve, reject, or 3-round exhaustion), post a brief summary as an MR comment:

```markdown
## Review Gate Summary

| Round | Reviewer | Decision | Headline |
|-------|----------|----------|----------|
| 1     | <agent>  | approve / request-changes / reject / timeout | <one-line summary> |
| 2     | <agent>  | ...      | ...      |
| 3     | <agent>  | ...      | ...      |

Final Review Report: <link to MR comment>
```

### Human bypass protocol

The human can bypass the mandatory review gate with explicit syntax. Bypass conditions:

- The human says **"skip gate"**, **"merge unreviewed"**, or equivalent explicit override.
- The override reason is documented in the MR description.
- The MR description `Review gate` field is set to `bypassed (human override)`.
- The override reason is recorded in an MR comment for audit trail.

A bypass does **not** waive the safety invariant against builder self-approval — even with a bypass, the builder still must not approve or merge its own MR. The human performs the merge directly or authorizes a named agent to do so.

## Template filling guides

Detailed section-by-section instructions live next to the templates:

- [Builder template filling guide](templates/filling-guide.md)
- [Shared ADR filling guide](../templates/filling-guide.md)

Safety-critical filling rules remain in this flow:

- Keep every field in the **Reviewer Lift** block current with every push according to `templates/reviewer-lift-schema.md`, including both quoted `Merge authority` and `Merge authority source` provenance.
- Treat CI evidence as valid only when the pipeline commit SHA (when GitLab exposes it) matches `Reviewed SHA`; red or stale CI is a blocker unless explicitly waived.
- Never paste secrets, credentials, auth headers, sensitive payloads, or unredacted logs into MR descriptions, comments, templates, or CI output.
- Use stable `OQ-N` IDs for open questions; remove placeholder IDs before ready.
- Preserve review item IDs (`MF-N`, `SF-N`, `C-N`) in revision-packet responses and commit subjects where applicable so reviewer traces stay stable.

## Success metric

Reviewable changes that preserve the project rulebook, remain testable, and don't create hidden operational surprises.
