# MR Build/Review Orchestration Design Brief

Status: design brief for issue #55. This file recommends project-agnostic changes
for GitLab-backed Dev Workflows; it does not change approval, merge, or release
policy until follow-up implementation issues are approved.

## Goal

Reduce parent-orchestrator manual work in GitLab issue-to-MR loops while keeping
safety boundaries explicit:

- parent owns final orchestration decisions;
- `mr-builder` owns one issue branch and one Review Packet;
- `mr-reviewer` owns one Review Report and one SHA-bound decision;
- `gitlab-local` owns CLI syntax, safe file-backed GitLab writes, and reusable
  snippets;
- skills own reusable workflow contracts that project docs can specialize.

## Current responsibility map

| Surface | Current responsibility | Gap / friction |
| --- | --- | --- |
| `/start-build` | Defines issue pickup, clean-branch setup, Draft MR creation, Reviewer Lift, TDD expectations, local Check Gate, ready-marking, and standalone mandatory review gate. | Strong single-MR workflow, but parent-orchestrator loop is spread across prose and agent prompts. |
| `/start-review` | Defines MR pickup, Reviewer Lift validation, diff review, Review Report, SHA-bound approval/merge, and multi-MR review mode. | Review report is complete, but summary-first machine output is not yet a first-screen contract. |
| `/gitlab-local` | Centralizes `glab` pitfalls and snippet names for issues, MRs, CI, notes, approvals, and SHA guards. | Needs safer multiline comment examples and optional CI/finish snippets. |
| `mr-builder` | Child builder. Implements issue, opens/updates MR, marks ready, then returns final handoff. Does not spawn reviewer, approve, or merge. | Authority boundary exists, but parent still repeats prompt text and must parse mostly human prose. |
| `mr-reviewer` | Fresh MR reviewer. Reads issue/MR/diff, posts Review Report, approves/request-changes/rejects. Merge only when authority allows. | Authority boundary exists, but report should expose summary and machine-readable finding data first. |
| Parent orchestrator | Chooses issue(s), spawns builder(s), spot-checks, spawns reviewer(s), drives revisions, watches CI, merges or stops per authority, cleans up. | No canonical recipe, no standard run directory, and no single handoff schema to automate decisions. |

## Proposed parent-orchestrator loop

Use this loop as a future recipe, not as a policy override:

1. **Resolve issue** — read issue, labels, comments, and project rulebook. Confirm
   scope fits one MR or satisfies the Decoupling Contract.
2. **Prepare checkout** — clean status, fetch default branch, create one branch or
   worktree per issue.
3. **Spawn `mr-builder`** — pass issue URL/IID, worktree path, project rulebook,
   local Check Gate, and run directory.
4. **Parent spot-check** — validate builder handoff schema, MR URL/IID, reviewed
   SHA, branch push, changed paths, safety surfaces, and local Check Gate result.
5. **Spawn `mr-reviewer`** — pass MR URL, pointer to Reviewer Lift, project
   rulebook, and run directory.
6. **Handle decision**:
   - `approve`: run CI guard; merge or stop according to merge authority.
   - `request-changes`: send findings to builder; require fix commits, targeted
     tests, revision note, updated handoff, then spawn a fresh reviewer.
   - `reject`: stop and escalate to human.
   - `timeout`: spawn one fresh reviewer; escalate if second attempt times out.
7. **CI guard** — watch the pipeline for the reviewed SHA. Red or stale CI blocks
   merge unless explicitly waived.
8. **Finish MR** — SHA guard, approval/merge authority check, merge or queue
   auto-merge, fetch default, verify issue closure, delete branch/worktree when
   safe.
9. **Post-merge verification** — optional verifier checks default branch state,
   issue/MR closure, and any documented post-merge contract.
10. **Archive run artifacts** — keep local evidence under the run directory; do
    not commit run artifacts.

## Placement recommendations

| Change | Belongs in | Reason | Suggested evidence |
| --- | --- | --- | --- |
| Parent loop recipe | `start-build/BUILD-FLOW.md` plus `docs/agents/dev-workflows.md` pointer | Build flow already owns mandatory gate and handoff sequencing; repo docs point to active Dev Workflows. | Markdown link check; reviewer validates no project-specific policy leaked in. |
| Builder handoff schema | `start-build/templates/` and `mr-builder` agent definitions | Builder produces the data, templates keep Review Packet and final output aligned. | Schema drift test like `tests/reviewer-lift-schema.sh`. |
| Reviewer report schema | `start-review/templates/` and `mr-reviewer` agent definitions | Reviewer owns decision/findings data and Review Report shape. | Template/schema test plus sample report fixture. |
| Safe file-backed comments | `gitlab-local/SKILL.md` | `gitlab-local` is the single source of `glab` command shape and pitfalls. | Markdown check plus shellcheck-style review of snippets. |
| CI watcher snippet | `gitlab-local/SKILL.md` first; optional `scripts/` helper later | CLI semantics belong in `gitlab-local`; script adds value only after snippet stabilizes. | Shell regression test with fake `glab` output if scripted. |
| Finish-MR snippet | `gitlab-local/SKILL.md` first; optional `scripts/` helper later | SHA guard, approve, merge, fetch, closure check, and cleanup are GitLab workflow primitives. | Fake-`glab` shell test if scripted; manual review for authority text. |
| Authority boundaries | `agents/claude/*.md`, `agents/pi/*.md`, and skill invocation-mode sections | Agents should carry boundaries so parent prompts stay short. | `npm run check:agents-schema`; prompt drift check. |
| Fallback-model guidance | Agent definitions and parent loop recipe | Runtime selection is orchestration behavior, not GitLab CLI behavior. | Schema/frontmatter validation where supported; prose review otherwise. |
| Summary-first review reports | `start-review/templates/review-report.md` and `mr-reviewer` prompts | Reviewer output owns first-screen decision ergonomics. | Template tests and sample report review. |
| Post-merge verifier | New recipe under `start-review/` or `docs/agents/` after approval | Separate verifier keeps `mr-reviewer` review-only. | Follow-up issue with clear no-mutation/default-branch safety rules. |
| Run artifact paths | Parent loop recipe plus agent handoff contracts | Parent coordinates builders/reviewers and can provide one directory per issue/MR. | No committed artifacts; docs-only review. |

## Machine-readable handoff schemas

Use fenced YAML blocks with stable begin/end markers. Producers may add fields
under `extra`, but consumers must tolerate absent schemas and fall back to human
prose. Values must not contain secrets, raw private payloads, or unredacted logs.

### Builder final handoff schema

Required fields:

```yaml
agent_handoff:
  kind: "builder-final"
  version: "1"
  status: "ready-for-review | blocked | failed"
  issue:
    iid: "55"
    url: "https://gitlab.example/group/project/-/issues/55"
    title: "Short issue title"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    draft: false
    source_branch: "issue-55-example"
    target_branch: "main"
  base_sha: "40-hex-sha"
  head_sha: "40-hex-sha"
  reviewed_sha: "40-hex-sha"
  pipeline:
    id: "456 | N/A"
    url: "https://gitlab.example/group/project/-/pipelines/456 | N/A"
    status: "success | pending | failed | N/A"
    sha: "40-hex-sha | N/A"
  local_gate:
    status: "PASS | FAIL | N/A"
    command: "npm run check"
    summary: "brief result or rationale"
  tdd:
    red: "command + expected failure, or N/A — docs-only"
    green: "command + result, or N/A — docs-only"
  changed_files:
    - "path/one.md"
  safety_surfaces:
    - "none | credentials | external-system | state | migration | gates | locks | deploy | other"
  decoupling:
    summary: "single MR"
    co_running: []
  reviewer_focus:
    - "path/one.md — design recommendation boundaries"
  open_questions: []
  merge_authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
  next_action: "spawn-reviewer | human-decision | fix-blocker"
  artifacts:
    run_dir: "/tmp/agent-run-issue-55-mr-123"
    review_packet: "/tmp/agent-run-issue-55-mr-123/review-packet.md"
  blockers: []
  extra: {}
```

Example:

```yaml
agent_handoff:
  kind: "builder-final"
  version: "1"
  status: "ready-for-review"
  issue:
    iid: "55"
    url: "https://gitlab.example/agents/skills/-/issues/55"
    title: "Explore project-agnostic MR build/review orchestration improvements"
  mr:
    iid: "78"
    url: "https://gitlab.example/agents/skills/-/merge_requests/78"
    draft: false
    source_branch: "issue-55-mr-orchestration-design"
    target_branch: "main"
  base_sha: "1111111111111111111111111111111111111111"
  head_sha: "2222222222222222222222222222222222222222"
  reviewed_sha: "2222222222222222222222222222222222222222"
  pipeline:
    id: "91011"
    url: "https://gitlab.example/agents/skills/-/pipelines/91011"
    status: "pending"
    sha: "2222222222222222222222222222222222222222"
  local_gate:
    status: "PASS"
    command: "npm run check"
    summary: "Markdown, link, schema, and shell regression checks passed."
  tdd:
    red: "N/A — docs-only design brief"
    green: "N/A — docs-only design brief; local gate passed"
  changed_files:
    - "docs/agents/mr-build-review-orchestration.md"
  safety_surfaces:
    - "none"
  decoupling:
    summary: "single MR"
    co_running: []
  reviewer_focus:
    - "Follow-up issue boundaries"
    - "No premature policy changes"
  open_questions: []
  merge_authority: "approval-only"
  next_action: "spawn-reviewer"
  artifacts:
    run_dir: "/tmp/agent-run-issue-55-mr-78"
    review_packet: "/tmp/agent-run-issue-55-mr-78/review-packet.md"
  blockers: []
  extra: {}
```

### Reviewer final handoff schema

Required fields:

```yaml
agent_handoff:
  kind: "reviewer-final"
  version: "1"
  decision: "approve | request-changes | reject"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
  reviewed_sha: "40-hex-sha"
  pipeline:
    id: "456 | N/A"
    status: "success | pending | failed | N/A"
    sha: "40-hex-sha | N/A"
  local_checks:
    - command: "npm run check"
      status: "PASS | FAIL | not-run"
      summary: "brief evidence"
  findings:
    must_fix:
      - id: "MF-1"
        path: "path/file.ext"
        line: "12"
        problem: "specific problem"
        direction: "specific fix direction"
    should_fix: []
    consider: []
  open_questions_addressed: []
  merge:
    authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
    action_taken: "approved | merged | queued-auto-merge | none"
    blocker: "none | reason"
  next_action: "merge | revise | human-escalation | wait-ci"
  report_url: "https://gitlab.example/group/project/-/merge_requests/123#note_789 | N/A"
  extra: {}
```

Example:

```yaml
agent_handoff:
  kind: "reviewer-final"
  version: "1"
  decision: "request-changes"
  mr:
    iid: "78"
    url: "https://gitlab.example/agents/skills/-/merge_requests/78"
  reviewed_sha: "2222222222222222222222222222222222222222"
  pipeline:
    id: "91011"
    status: "success"
    sha: "2222222222222222222222222222222222222222"
  local_checks:
    - command: "npm run check"
      status: "PASS"
      summary: "Full Check Gate passed locally."
  findings:
    must_fix:
      - id: "MF-1"
        path: "docs/agents/mr-build-review-orchestration.md"
        line: "120"
        problem: "Finish-MR helper implies builder-side approval."
        direction: "State that only reviewer/authorized parent may approve or merge."
    should_fix: []
    consider: []
  open_questions_addressed: []
  merge:
    authority: "approval-only"
    action_taken: "none"
    blocker: "Must Fix remains."
  next_action: "revise"
  report_url: "https://gitlab.example/agents/skills/-/merge_requests/78#note_333"
  extra: {}
```

## Safe file-backed GitLab comment patterns

Recommended pattern for multiline MR comments:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-note.XXXXXX")"
comment_file="$run_dir/comment.md"
cat > "$comment_file" <<'EOF'
## Revision Packet

- MF-1: Fixed by commit abc123.
- Tests: `npm run check` passed.
EOF

glab mr note create "$mr_iid" --message "$(cat "$comment_file")"
```

Recommended pattern for MR descriptions:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/gitlab-mr.XXXXXX")"
description_file="$run_dir/review-packet.md"
cat > "$description_file" <<'EOF'
# Review Packet

Generated from a local file so Markdown is not interpreted by the shell.
EOF

glab mr update "$mr_iid" --description "$(cat "$description_file")"
```

Rules:

- Use quoted heredocs (`<<'EOF'`) so backticks, dollar signs, and command
  substitutions stay literal while writing the file.
- Pass file contents with `--message "$(cat "$file")"` or
  `--description "$(cat "$file")"`.
- Avoid inline heredoc command substitution such as
  `--message "$(cat <<EOF ... EOF)"`; backticks in the body can execute before
  `glab` receives the text.
- Keep generated files under a temp/run directory; do not commit review
  artifacts.
- Redact secrets before writing local files that may be pasted to GitLab.

## CI watcher snippet behavior

A future `gitlab-local` CI watcher snippet should:

Inputs:

- MR IID or source branch;
- expected reviewed SHA;
- timeout and poll interval;
- optional output mode: human summary or machine YAML.

Algorithm:

1. Read MR metadata with `glab mr view <iid> -F json`.
2. Extract MR head SHA and pipeline ID/status/SHA when available.
3. Fail immediately if MR head SHA differs from expected reviewed SHA.
4. If no pipeline is attached yet, poll branch CI with `glab ci status --branch`.
5. Print compact progress: elapsed time, pipeline ID, status, and SHA.
6. Treat `success` for expected SHA as pass.
7. Treat `failed`, `canceled`, `skipped`, missing required jobs, or status for a
   stale SHA as fail.
8. On timeout, emit last observed pipeline/job summary and non-zero exit.

Machine output example:

```yaml
ci_watch:
  mr: "78"
  expected_sha: "2222222222222222222222222222222222222222"
  observed_sha: "2222222222222222222222222222222222222222"
  pipeline_id: "91011"
  status: "success"
  url: "https://gitlab.example/agents/skills/-/pipelines/91011"
  jobs:
    failed: []
    running: []
  result: "pass"
```

## Finish-MR snippet behavior

A future finish helper/snippet should be authority-aware. It must not let a
builder self-approve or self-merge.

Inputs:

- MR IID;
- reviewed SHA;
- merge authority;
- source branch;
- default branch;
- optional worktree path.

Algorithm:

1. Re-read MR metadata and compare current SHA to reviewed SHA.
2. Confirm CI for reviewed SHA is green, safely pending under protected
   auto-merge, or explicitly waived in MR text.
3. Confirm merge authority:
   - `approval-only`: do not merge; report ready for human/reviewer action.
   - `reviewer may merge`: reviewer/authorized parent may merge with `--sha`.
   - `queue auto-merge`: authorized caller may queue auto-merge with `--sha`.
   - `human release`: do not merge; report release handoff.
4. Approve only when caller is the reviewer and approval is part of the review
   workflow; otherwise skip approval.
5. Merge or queue auto-merge with the reviewed SHA when authority allows.
6. Fetch default branch and fast-forward local default branch when safe.
7. Verify linked issue closed or report that closure is pending.
8. Remove worktree only when status is clean and branch is pushed.
9. Delete source branch only after merge/auto-merge policy allows deletion.
10. Emit machine-readable final status.

## Canonical revision loop

1. Reviewer posts `MF-N`, `SF-N`, and `C-N` findings in one Review Report.
2. Parent sends findings and reviewed SHA to builder.
3. Builder creates fix commits; each Must Fix commit subject names the finding ID
   when practical, for example `MF-1: preserve SHA guard`.
4. Builder runs targeted tests for the changed surface.
5. Builder runs the full local Check Gate when the change is substantive or when
   targeted tests do not cover the risk.
6. Builder posts a file-backed revision note that maps each finding ID to fix
   commit(s), tests, and remaining risk.
7. Builder updates MR description, Reviewer Lift, and machine handoff with old
   SHA -> new SHA.
8. Parent spawns a fresh reviewer session for the new SHA. Do not reuse the
   previous reviewer session.
9. Stop after three total review rounds and escalate to human if Must Fix items
   remain.

## Parent spot-check budget

Minimal always-on checks:

- issue URL/IID matches MR `Closes #...`;
- MR is for the expected source branch and target branch;
- `Reviewed SHA` equals current MR head SHA;
- local Check Gate evidence is present;
- changed paths fit issue scope;
- touched safety surfaces are plausible;
- merge authority is explicit;
- no open `OQ-N` placeholder remains.

Deeper checks only when risk warrants:

- inspect full diff before reviewer if safety surfaces include credentials,
  external-system, state, migration, gates, locks, deploy, or other;
- run targeted local tests when builder evidence is weak;
- wait for CI before review if local gate could not run or CI config changed;
- ask human before merge if labels, authority, or issue scope conflict.

## Post-merge verifier recipe

Follow-up issue #62 moved the active verifier contract to
`start-build/BUILD-FLOW.md` section
[Post-merge verifier recipe](../../start-build/BUILD-FLOW.md#post-merge-verifier-recipe).
This design brief keeps the original placement rationale only: post-merge
verification remains separate from MR review so `mr-reviewer` stays review-only.

## Run artifact paths

Parent should allocate one run directory per issue/MR, for example:

```text
${TMPDIR:-/tmp}/agent-gitlab-loop/issue-55-mr-78/
├── builder-handoff.yaml
├── review-packet.md
├── reviewer-report.md
├── revision-1.md
├── ci-watch.yaml
└── finish-mr.yaml
```

Rules:

- Pass the run directory to builder and reviewer prompts.
- Keep local command output redacted before storing.
- Commit none of these files.
- Use GitLab comments/MR descriptions as durable handoff; local artifacts are
  convenience evidence only.

## Fallback-model guidance

Fallback should be parent-owned:

- Agent definitions keep `model: inherit` unless a project intentionally pins a
  model.
- Parent may retry a failed builder/reviewer with an alternate configured model
  only after recording why the prior run failed.
- Retry must use a fresh session and the same issue/MR SHA inputs.
- Retry must not skip safety checks, Reviewer Lift validation, or SHA guards.
- Output schema should include `status: failed` plus `blockers` when usage limits
  stop a run before completion.

## Migration and rollout guidance

1. Add schemas as optional, backwards-compatible blocks first.
2. Teach consumers to prefer machine blocks when present and fall back to current
   human prose when absent.
3. Keep Reviewer Lift as the canonical MR-description handoff; machine blocks
   complement it, not replace it.
4. Update Claude and pi agent definitions in the same MR when changing authority
   boundaries or final handoff expectations.
5. Add schema drift tests before requiring strict field order in agents.
6. Add `gitlab-local` snippets before any helper script; scripts should only
   codify stabilized snippets.
7. Keep examples synthetic and generic.
8. Do not create implementation issues until a maintainer approves this design
   brief.

## Follow-up implementation issue slices

Create these only after maintainer approval:

1. **Parent loop recipe docs** — add the orchestration recipe to `start-build` and
   point repo Dev Workflow docs at it. No agent prompt changes.
2. **Machine handoff templates** — add builder/reviewer machine-output templates,
   examples, and schema drift checks. No `glab` snippet changes.
3. **Safe `gitlab-local` comment guidance** — update multiline comment and MR
   description snippets with quoted-heredoc file-backed patterns.
4. **CI watcher and finish-MR snippets** — add documented snippet behavior with
   SHA pinning and authority checks; no helper scripts yet.
5. **Agent authority and fallback prompt update** — update both Claude and pi
   `mr-builder` / `mr-reviewer` definitions for schema output, summary-first
   reports, fallback failure reporting, and authority boundaries.
6. **Optional helper scripts** — implement tested helpers only after snippets are
   accepted; use fake `glab` fixtures in shell tests.
7. **Post-merge verifier recipe** — define a verifier role/recipe that checks
   merged state without taking review authority.

Each slice should have one MR, one Review Packet, one local Check Gate result,
and one independent review.
