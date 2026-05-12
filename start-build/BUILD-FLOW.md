# Start Build Flow

Detailed workflow for `start-build`. Read before selecting issue(s), creating/updating MR(s), commenting, or marking ready. Assumes you've already read [SKILL.md](SKILL.md) for purpose and GitLab handoff, plus the host project's issue-tracker guide for `glab`/`gl-*` command syntax and flag pitfalls.

## GitLab tooling reference

The command reference intentionally lives in the host project's issue-tracker guide (in this repo, `docs/agents/issue-tracker.md`). Use it for preflight/auth, wrapper commands, issue/MR/CI syntax, worktree snippets, and known `glab` flag pitfalls. This flow names commands only where sequencing matters.

## Issue pickup

When the user supplies issue IDs/URLs, use them if suitable. Otherwise pick one issue or a decoupled set from the **current GitLab project**:

1. Run `gl-preflight` to confirm cwd is the intended git repo and `glab` resolves to it. If it fails, stop and ask.
2. List open issues (`glab issue list --per-page 50`; add `--output json` only if you need `jq`). Narrow with `--label`, `--assignee=@me`, `--author`, `--milestone` as project conventions dictate. Prefer issues that are unassigned or `@me`, ready/triaged, with clear acceptance criteria, fit one MR, not blocked/confidential/security-sensitive unless requested.
3. Deprioritize blocked, needs-info, needs-human, in-progress/WIP labels, or issues with an existing open MR. Infer from repo docs if labels differ.
4. Inspect 3-5 candidates with `glab issue view <id>` (or enough to validate coupling for multiple). Don't dump raw JSON; summarize ID, title, labels, assignee, suitability, coupling risk.
5. If one issue or one decoupled set is clearly suitable, announce and proceed. If multiple are plausible or ambiguous, ask the user to choose.
6. Claim issues only when project convention is clear (e.g. self-assign or `in-progress` label). Do not create/mutate labels casually.

## Multiple issue worktree mode

Use when the user supplies multiple issues, asks for multiple tasks, or requests more than one issue at once.

1. Resolve candidates first. Build a set only if every item is one-MR-sized, unblocked, and has no dependency/order relation with another candidate.
2. Prove decoupling before parallelizing:
   - no `depends on`, `after #...`, shared blocker, stacked branch, or release-order relation;
   - no expected overlapping edits to the same files/modules or behavior-critical surfaces;
   - no shared migrations, schemas, locks, sequencing, deploy topology, generated artifacts, version bumps, or dependency lockfiles;
   - tests run independently without shared ports, databases, product/runtime/operator external systems, or mutable global state.
3. If decoupling is unclear, stop and ask for a serial order or smaller set. Never parallelize coupled issues to save time.
4. Use the original checkout as a coordinator only — do not code in it during a multi-issue run:
   - `git status --porcelain` empty;
   - `git fetch origin`;
   - detect default branch (`gl-repo-default-branch`, or project docs if jq isn't available);
   - one sibling worktree per issue: `git worktree add -b <branch> <path> origin/<default_branch>`.
5. In each worktree, run the normal implementation flow from context loading onward. One issue, one branch, one Draft MR, one check gate, one Review Packet per worktree.
6. **Write the decoupling proof once per MR, in `Reviewer Lift > Decoupling proof`.** List the co-running MR IIDs and why decoupled (no file/module overlap, no shared migrations/locks/lockfiles, tests independent). Also keep `Changed paths` and `Touched safety surfaces` current so the reviewer can spot contradictions quickly. The reviewer reads this rather than re-deriving it from each MR's metadata.
7. If the harness provides parallel subagents/worktree orchestration, run one build agent per worktree. Never let two agents share a checkout, branch, temp DB, port, or uncommitted artifact directory.
8. Keep artifacts/evidence local to that worktree/MR. Do not combine Review Packets, close multiple issues from one MR, or stack branches unless the user explicitly switches to a serial plan.
9. Before revision/merge follow-up, re-check target branch and merge status. If another worktree's MR creates a conflict or stale branch, pause and report the coupling.
10. Remove a worktree only after its branch is pushed and `git -C <path> status --porcelain` is empty: `git worktree remove <path>`. Use `git worktree prune` only after verifying stale paths.

## Before coding questions

Every non-trivial task needs a GitLab issue describing the user/operator-visible goal. If one doesn't exist, open it before starting. Capture in the issue or Draft MR description:

1. What user/operator-visible behavior changes (CLI, daemon, state, metrics, docs)?
2. Which safety invariant is closest: external mutation, sequencing, locking, immutable baselines, gates, secrets, schemas, deploy?
3. If TDD is not applicable, why?
4. What evidence defines correctness (specs, ADRs, prior reviews, vendor quirks)?
5. What is out of scope?
6. If refactoring, is any surface behavior-touching? See [SAFETY.md](SAFETY.md).
7. What is the merge authority for this MR: approval-only, reviewer may merge, queue auto-merge, human release, or project default?

## Check gate discovery

Before you claim the full local gate is green, discover it in this order:

1. Project rulebook / contributor docs (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, README).
2. Build scripts (`Makefile`, `package.json`, task runner config, language-specific project files).
3. CI configuration (`.gitlab-ci.yml`, included pipeline files) to mirror the project gate locally where practical.
4. If still ambiguous, ask the user or state the limitation in the MR before requesting review.

## Handoff integrity checklist

Before marking ready or requesting review, validate the MR handoff:

- Reviewer Lift exists with the same required rows in full and compact packets: Reviewed SHA, CI pipeline, Local gate, RED, GREEN, Changed paths, Touched safety surfaces, Decoupling proof, Reviewer Focus, Open Questions, Merge authority, Delta since last ready push.
- `Reviewed SHA` equals the MR head SHA at the time you mark ready.
- CI pipeline evidence includes pipeline URL/ID, status, and commit SHA when available; pipeline SHA must match `Reviewed SHA` before treating green CI as evidence.
- No placeholder `OQ-1` remains; Open Questions is either `none` or lists real stable IDs.
- Local gate command/result is present, or N/A explains why only CI can provide it.
- Post-ready pushes have a delta comment and an updated Reviewer Lift.
- Merge authority is explicit.

## Implementation flow

1. Resolve the issue(s) first: supplied or via pickup. If multiple, enter **Multiple issue worktree mode** and run the rest independently per worktree.
2. For a single issue, start clean from latest default branch:
   - `git status --porcelain` empty. If dirty, stop and ask — never auto-stash, reset, or clean.
   - `git fetch origin`.
   - `git checkout <default>` (check via `gl-repo-default-branch` if not `main`).
   - `git pull --ff-only origin <default>`. If FF fails, stop and ask; do not force.
   - Confirm `git rev-parse HEAD` matches `origin/<default>` before branching.
   - Branch using the project's naming convention; reference the issue ID.
3. Load relevant context: rulebook, architecture docs, source/tests, ADRs.
4. Open a **Draft MR** early targeting the default branch, linked via `Closes #<id>`, after the source branch exists remotely (push the first commit or use `glab mr create --push` after committing). Use `templates/review-packet.md` (or compact variant when eligible). Fill **Builder** metadata as `@builder — <model-id>` (e.g. `@builder — claude-opus-4-7`); do not add a separate model-only row; if the harness doesn't expose the model id, omit it instead of guessing. Initialize the **Reviewer Lift** block (Reviewed SHA, CI pipeline, Local gate, RED, GREEN, Changed paths, Touched safety surfaces, Decoupling proof, Reviewer Focus, Open Questions, Merge authority, Delta since last ready push) — leave fields with `<pending>` until you have values, but keep the block present from day one so the reviewer's lookup path is stable.
5. For behavior-touching changes, implement vertical slices per the `tdd` skill. Commit coherent green slices, referencing issue/slice; revision commits cite review-thread items (e.g. `MF-1: <fix>`). For docs-only/config-only/mechanical work, state `TDD: N/A` and why in the MR — don't fake tests.
6. Use the smallest public layer that proves behavior without coupling to internals: pure unit tests for deterministic logic; adapter tests with fakes/recorded HTTP; state tests in temp dirs/throwaway DBs; orchestration tests with fake clocks verifying call ordering and calls *not* made; migration smoke tests; the project's full check gate before requesting review; coverage gate where required.
7. Run targeted tests during the red-green loop. Never use live product/runtime/operator external systems as regression evidence.
8. Update the MR description: diff summary, acceptance-criteria evidence, safety evidence, TDD trace (or `TDD: N/A` rationale), full test/check-gate output or CI link. **Keep the Reviewer Lift block current** — fill `Reviewed SHA` (MR head), `CI pipeline` (URL/ID + status + commit SHA when available), `Local gate` (PASS/FAIL/N/A + exact command), `RED`/`GREEN` one-liners, `Changed paths`, `Touched safety surfaces`, `Decoupling proof` (or N/A), `Reviewer Focus` (1-2 areas to read hardest, or "none"), `Open Questions` (count + IDs, or "none"), `Merge authority`, and `Delta since last ready push`. Use stable `OQ-N` IDs in the body so the reviewer can answer each one.
9. `glab mr update <id> --ready` and request review (human or `start-review` in a fresh session).
   - **Review request protocol.** Request a named reviewer with `--reviewer`/project-approved mechanism when known; apply existing ready-for-review labels only when the project convention is clear; otherwise hand off the MR URL plus `Reviewed SHA` to the reviewer session. Do not invent labels casually.
   - **Don't block ready-marking on CI when the full local check gate is green.** The local gate (lint, format, typecheck, full test suite, etc.) is the same check CI runs; once green and pushed, mark ready immediately. CI is the reviewer's clean-checkout safety net, not a builder-side wait.
   - Wait for CI before ready only when (a) the local gate could not be run (missing tooling, OS-specific job, unreachable integration suite) or (b) the change touches CI infrastructure itself. Say so explicitly in the MR.
   - **CI-pending review policy.** A reviewer may approve and queue auto-merge while CI is pending only when the local gate is PASS, the pending pipeline is for the reviewed SHA when GitLab exposes the SHA, and GitLab merge checks enforce green CI before merge. Red CI or stale green CI remains a blocker unless explicitly waived.
   - **Post-ready push protocol.** If you push any commits after marking ready (CI fix, review revision, rebase, anything), post an MR comment naming old SHA → new SHA, reason, changed files, gate rerun, and whether the delta is substantive. Update `Reviewer Lift > Reviewed SHA`, `CI pipeline`, and `Delta since last ready push`. Use `templates/revision-packet.md` for substantive post-ready changes, not only formal request-changes responses. The reviewer is told to refuse approval of a SHA they haven't read; silently pushing after ready risks merging unreviewed commits.
   - If CI later goes red, treat it like other review feedback: fetch logs, diagnose, fix, push a commit (with the post-ready delta comment). Don't unilaterally re-Draft.
10. If changes are requested, push fixes as new commits and reply to each thread. Builder replies with evidence; the reviewer resolves threads after verifying unless the project explicitly allows builder-side resolution. Update the MR description with a brief revision summary and post `templates/revision-packet.md` as a comment.
11. After approval, the reviewer merges or queues auto-merge only when `Merge authority` allows it. If authority is approval-only/human release, stop after approval and report the reviewed SHA. If GitLab blocks reviewer-side merge, merge per repo workflow using the reviewed SHA. For safety-critical tasks, link the MR from any durable decision log the project keeps.

## Compact packet eligibility

Use `templates/review-packet-compact.md` when the diff is simple enough that a short MR description suffices: docs-only, tests-only with no runtime impact, typo/lint, or dependency bump with no API impact. The compact packet still carries the same Reviewer Lift rows as the full packet, using explicit `N/A`/`none` values. Default to the full template when a broader map helps the reviewer.

## Stuck protocol

If blocked for more than 2 hours:

1. Keep the MR in Draft.
2. Post `templates/stuck-packet.md` as an MR comment via `gl-mr-comment <id> templates/stuck-packet.md` (after filling it).
3. Apply a `needs-unblock` label.
4. Request review explicitly for unblocking.
5. List ranked hypotheses.
6. Park the branch/worktree or switch to a non-blocked issue on a fresh branch/worktree.

## Review handoff

Use `start-review` in a fresh LLM session when an agentic reviewer is desired. Builder and reviewer may share the same GitLab username/PAT — review independence comes from session/context separation, not GitLab identity. If the reviewer approves, they should run `glab mr approve <id> --sha <reviewed-sha>`; they merge or queue auto-merge for the reviewed SHA only when `Merge authority` allows it.

## Success metric

Reviewable changes that preserve the project rulebook, remain testable, and don't create hidden operational surprises.
