# Dev Workflow reference split plan

Issue #90 records a planning-only slice for oversized active Dev Workflow reference docs. This plan is intentionally non-mutating: it does not move active workflow content, change GitLab command semantics, change stable snippet names, or change build/review authority policy.

## Scope and non-goals

In scope for this plan:

- Inventory current inbound links to anchors in `gitlab-local/SKILL.md` and `start-build/BUILD-FLOW.md`.
- Propose an anchor-preserving split strategy for future MRs.
- Identify tests likely to need updates when future MRs move content.
- Suggest independently reviewable follow-up issues.

Non-goals for this issue:

- No active workflow content moves.
- No GitLab command syntax or snippet semantics change.
- No review/build authority policy change.
- No stable snippet name change.
- No broad docs restructuring beyond this planning artifact and its index link.

## Current inbound anchor inventory

Inventory evidence captured on 2026-05-27 from `origin/main` plus this planning branch. Commands used:

- Direct grep for path-qualified anchors: `rg -n --glob '*.md' 'gitlab-local/SKILL\.md#[A-Za-z0-9_-]+' .`
- Direct grep for `BUILD-FLOW.md` anchors: `rg -n --glob '*.md' 'BUILD-FLOW\.md#[a-z0-9-]+' .`
- Resolved relative Markdown-link sweep over `git ls-files '*.md'`, resolving each local fragment link to its target file.
- Link-check validation command for this MR: `npm run check:links`.

### `gitlab-local/SKILL.md`

No direct `gitlab-local/SKILL.md#...` path-qualified anchor links were found by direct grep. The resolved-link sweep found these inbound relative links:

| Source | Anchor | Current purpose |
| --- | --- | --- |
| `gitlab-local/scripts/README.md:12` | `#snippet-ci-watch-sha-pinned` | Helper docs point from `gitlab-ci-watch.sh` to the canonical snippet contract. |
| `gitlab-local/scripts/README.md:13` | `#snippet-finish-mr-authority-aware` | Helper docs point from `gitlab-finish-mr.sh` to the canonical finish-authority contract. |

Additional non-anchor inbound reference:

| Source | Target | Current purpose |
| --- | --- | --- |
| `docs/agents/mr-build-review-orchestration.md:39` | `gitlab-local/SKILL.md` | Historical design brief points reviewers to GitLab CLI snippets, CI watch, and finish guards. |

### `start-build/BUILD-FLOW.md`

Resolved inbound anchors:

| Anchor | Sources | Current purpose |
| --- | --- | --- |
| `#parent-orchestrator-recipe` | `docs/agents/dev-workflows.md:14`; `docs/agents/mr-build-review-orchestration.md:33`; `setup-dev-skills/dev-workflows-gitlab.md:14` | Active parent loop for issue resolution, child builder handoff, reviewer launch, revision rounds, SHA/CI guards, finish, cleanup, and post-merge verification. |
| `#post-merge-verifier-recipe` | `docs/agents/dev-workflows.md:15`; `setup-dev-skills/dev-workflows-gitlab.md:15` | Active read-only post-merge verification contract. |
| `#builder-invocation-modes` | `docs/agents/mr-build-review-orchestration.md:34` | Child builder vs standalone builder responsibilities and handoff boundary. |
| `#implementation-flow` | `start-build/SAFETY.md:20`; `start-review/REVIEW-FLOW.md:86` | Local gate / CI-ready policy and build implementation sequence. |
| `#mandatory-review-gate` | `start-build/SKILL.md:35`; `start-build/SAFETY.md:21`; `start-build/templates/filling-guide.md:13`; `start-build/templates/filling-guide.md:44`; `start-review/SKILL.md:20`; `start-review/REVIEW-FLOW.md:7` | Independent review gate and review launch/decision contract. |
| `#issue-pickup` | `start-build/SKILL.md:39` | Issue selection and suitability procedure. |

## Anchor-preserving split strategy

Future split MRs should treat `SKILL.md` and `BUILD-FLOW.md` as stable entrypoints. Reduce their size only by moving details behind links while preserving anchors that other docs, tests, agents, or humans already use.

### Compatibility rules

- Keep every currently linked anchor in its original file as a real Markdown heading.
- Keep stable snippet heading text in `gitlab-local/SKILL.md`: `### Snippet: <name>` should remain the source anchor even if expanded prose moves elsewhere.
- If body text moves, replace it with a compatibility stub that states where the canonical detail now lives and whether the stub or target owns executable command syntax.
- Do not change command snippets, SHA guards, approval/merge separation, CI rules, parent/child authority boundaries, or merge authority semantics in the same MR as a content move.
- Do not rename anchors unless a separate migration MR updates every inbound reference and adds a compatibility anchor for at least one release cycle.
- Run `npm run check:links` and `npm run check` after each split MR.

### Proposed `gitlab-local` split shape

Keep `gitlab-local/SKILL.md` as the small loader and stable anchor host:

- Frontmatter, purpose, help-first rule, known pitfalls summary, and canonical snippet registry stay in `SKILL.md`.
- All `### Snippet: ...` headings stay in `SKILL.md` so existing snippet names and generated anchors remain stable.
- High-risk executable snippets should either stay inline or move only after tests learn the new canonical location.
- Long explanatory sections can move first because they are lower-risk than command snippets.

Candidate future files:

| Future file | Candidate content | Anchor handling |
| --- | --- | --- |
| `gitlab-local/reference/help-first.md` | Detailed help-cache contract and context invalidation examples. | Keep `## Help-first rule` and `### Per-run help cache` headings in `SKILL.md` as short stubs linking here. |
| `gitlab-local/reference/multiline-text.md` | File-backed MR/issue note and MR description patterns. | Keep `## Safe multiline GitLab text` in `SKILL.md` as stub. |
| `gitlab-local/reference/snippets.md` | Expanded snippet rationale and non-executable explanations. | Keep each `### Snippet: ...` heading in `SKILL.md`; only move explanatory prose unless tests are updated. |
| `gitlab-local/reference/ci-finish-guards.md` | CI watcher / finish helper rationale, polling rules, and authority guard detail. | Preserve `#snippet-ci-watch-sha-pinned` and `#snippet-finish-mr-authority-aware` in `SKILL.md` for `gitlab-local/scripts/README.md`. |
| `gitlab-local/reference/troubleshooting.md` | Troubleshooting details. | Keep `## Troubleshooting` in `SKILL.md` as stub. |

Recommended first `gitlab-local` move: extract non-executable help-cache and multiline-text explanations while leaving snippet headings and command blocks in place. That avoids breaking `tests/gitlab-local-split-snippets.sh`, which currently extracts snippets from `gitlab-local/SKILL.md`.

### Proposed `start-build` split shape

Keep `start-build/BUILD-FLOW.md` as the active flow entrypoint and stable anchor host:

- `## Issue pickup`, `## Builder invocation modes`, `## Implementation flow`, and `## Mandatory review gate` remain in `BUILD-FLOW.md` as active summary sections or compatibility stubs.
- `## Parent-orchestrator recipe` and `### Post-merge verifier recipe` need extra care because `tests/parent-subagent-placement.sh` currently asserts parent-only runtime-discovery guidance stays inside `BUILD-FLOW.md` section bounds.
- Do not move parent-only subagent discovery text without updating that test and verifying child builder prompts remain free of runtime-specific subagent calls.

Candidate future files:

| Future file | Candidate content | Anchor handling |
| --- | --- | --- |
| `start-build/reference/issue-pickup.md` | Full issue selection and suitability procedure. | Keep `## Issue pickup` in `BUILD-FLOW.md` with compatibility stub. |
| `start-build/reference/multiple-worktrees.md` | Multi-issue worktree mode and Decoupling Contract producer guidance. | Keep `## Multiple issue worktree mode` in `BUILD-FLOW.md` or add explicit anchor stub if linked later. |
| `start-build/reference/parent-orchestrator.md` | Parent loop, child builder launch boundaries, reviewer launch boundaries, SHA/CI guards, finish authority. | Keep `## Parent-orchestrator recipe` in `BUILD-FLOW.md`; either keep parent-only subagent discovery inline or update `tests/parent-subagent-placement.sh` in the same MR. |
| `start-build/reference/post-merge-verifier.md` | Read-only verifier contract. | Keep `### Post-merge verifier recipe` in `BUILD-FLOW.md` with compatibility stub. |
| `start-build/reference/implementation-flow.md` | Full implementation flow, local gate, CI-pending review policy, post-ready push protocol. | Keep `## Implementation flow` in `BUILD-FLOW.md` with compatibility stub. |
| `start-build/reference/review-gate.md` | Mandatory review gate, launch protocol, review loop, timeout handling, human bypass. | Keep `## Mandatory review gate` in `BUILD-FLOW.md` with compatibility stub. |

Recommended first `start-build` move: extract post-merge verifier detail or stuck/timeout detail only after adding tests that accept the new canonical file. Delay moving parent-orchestrator discovery text until the placement test is updated.

## Test impact plan for future split MRs

| Test | Why affected | Future adjustment |
| --- | --- | --- |
| `tests/gitlab-local-help-cache.sh` | Greps exact help-cache guidance in `gitlab-local/SKILL.md`. | Either keep required sentences in the `SKILL.md` stub or update the test to assert both stub and new `gitlab-local/reference/help-first.md` detail. |
| `tests/gitlab-local-split-snippets.sh` | Extracts snippet bodies from `gitlab-local/SKILL.md` and verifies approval/merge snippets stay split. | Keep executable snippets in `SKILL.md` for first split; if moved later, update `extract_snippet` to read the new canonical snippet file and add a separate assertion that old anchors remain as stubs. |
| `tests/gitlab-workflow-helpers.sh` | Helper behavior should not change, but helper docs point to `gitlab-local/SKILL.md` anchors. | Keep helper behavior untouched; update helper README links only if old anchors remain valid and link-check passes. |
| `tests/parent-subagent-placement.sh` | Hard-codes `start-build/BUILD-FLOW.md` section bounds for parent-only runtime-discovery guidance. | Keep parent-orchestrator guidance in `BUILD-FLOW.md` until the test is updated to recognize the new canonical parent recipe file and still reject child-prompt placement. |
| `tests/md-links.sh` and `npm run check:links` | Any split adds or rewrites relative links and fragment anchors. | Run after every split; add compatibility anchors before updating links. |
| `tests/agent-check.sh` | Checks canonical pointers and prompt drift across installed agent docs. | Expect updates if agent prompts point at newly split reference docs. |

## Follow-up issue suggestions

1. Split low-risk `/gitlab-local` reference detail while preserving snippet anchors.
   - Move help-cache and multiline text examples into `gitlab-local/reference/`.
   - Keep required help-cache text and all snippet headings in `gitlab-local/SKILL.md`.
   - Update `tests/gitlab-local-help-cache.sh` only if the exact required text moves.

2. Add split-aware snippet-anchor regression coverage before moving executable snippets.
   - Teach tests to verify both canonical snippet body location and compatibility anchors.
   - Keep approval, direct-merge, auto-merge, CI watch, and finish snippets separated.
   - No command semantics change.

3. Split `start-build` post-merge verifier detail into a reference file.
   - Keep `### Post-merge verifier recipe` in `start-build/BUILD-FLOW.md` as an anchor stub.
   - Update inbound links only if they still point through the compatibility anchor or link directly to the new canonical file.
   - Run `tests/parent-subagent-placement.sh` to prove parent-only discovery guidance stayed put.

4. Split `start-build` parent-orchestrator detail after updating placement tests.
   - Update `tests/parent-subagent-placement.sh` in the same MR.
   - Preserve `## Parent-orchestrator recipe` anchor in `BUILD-FLOW.md`.
   - Prove child builder prompts still do not include runtime-specific subagent discovery.

5. Add a small anchor inventory helper if more splits are planned.
   - Script resolved relative Markdown links to `gitlab-local/SKILL.md` and `start-build/BUILD-FLOW.md`.
   - Use it as reviewer evidence before any content-move MR.
   - Keep it read-only and wire it into `npm run check` only after review.

## Acceptance check for future content-move MRs

Before any future MR moves active Dev Workflow reference content, reviewers should be able to verify:

- Old anchors still resolve in `npm run check:links`.
- Stable snippet names still exist or tests explicitly verify compatibility stubs.
- `npm run check` passes.
- MR scope states whether content moved, which anchors were preserved, and which tests changed.
- Review Packet states: no GitLab command semantics changed; no review/build authority policy changed; no external-system, credential, state, migration, gates, locks, or deploy surfaces changed.
