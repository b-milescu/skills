# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

Run the local gate with Node.js 22.x, matching `.nvmrc`, `package.json` `engines.node`, and the GitLab CI `node:22` image. `npm run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which runs:

**Fresh checkout or worktree bootstrap:** A fresh checkout or new worktree must bootstrap before running the gate. Switch to Node 22 per `.nvmrc` (e.g. `nvm use 22`), then run `npm ci` to install dependencies from `package-lock.json`, then run `npm run check`. Skipping either bootstrap step produces spurious failures (wrong Node version or missing `node_modules`).

- `bash -n install.sh`
- `npm run check:agents-schema`
- `bash agents/check.sh` against a fabricated disposable HOME containing stub required external skills (not the operator's real HOME)
- `npm run check:md`
- `npm run check:links`
- each `tests/*.sh` regression script

Use `Local gate: PASS — npm run check` in MR Review Packets when it passes.

For parent-owned gate selection, this policy and the bootstrap route above
already support an exact-candidate `npm run check` receipt. A fresh worktree
without `node_modules` needs bootstrap; it does not lack gate policy. Record
the parent as the bootstrap/gate executor without requiring a full gate pass
before implementation. If Node 22 or dependency installation cannot be
provided, report that specific prerequisite, not an N/A parent receipt or an
automatic ownership change. These are selection rules, not a report of an
observed local failure. Generic cases, including issues that add a gate, are
owned by [Check gate discovery](../../start-build/reference/context-and-planning.md#check-gate-discovery).

## Project-profile refs

Use this file as the default `project_profile.gate_policy_ref`, `ci_jobs.ref`,
and `manual_validation_rules.ref` for this repo. The exact-candidate full local
gate is `npm run check`; configured advisory CI jobs are described in
[CI parity](#ci-parity); manual validation rules are in
[Manual validation rules](#manual-validation-rules).

These facts are verified against `setup-dev-skills/reference/project-profile-facts.json`: refs, command, runtime, and observed CI jobs.

Project-profile hooks may specialize project policy, but they must not weaken
the [safety-floor litany](../effort-scaling.md#hard-floors-never-scaled-away).

## Gate coverage for ready handoff

This repo's `Gate coverage` is `exact-candidate-local`. `npm run check` must pass
on the exact MR head SHA; in parent-owned mode the durable Gate Receipt records
that command, candidate, and PASS result. This singular local gate is the
required quality evidence for ready, review, approval, and finish.

The `check` provider job runs the same command after `npm ci`. It is an advisory
parity signal, not another delivery gate. Record its locator, status, and SHA
when available, and attribute the status only when its SHA matches the reviewed
candidate or provider-proven integration commit. Pending, failed, canceled,
skipped, missing, stale, wrong-SHA, or unavailable CI never changes verdict or
action eligibility. Native GitLab protection may still refuse a merge; report
that provider outcome and never bypass it.

## Executable-bit policy

Only these tracked entrypoints keep executable bits: `install.sh`;
`scripts/check.sh` (via `npm run check`).
Shell, Node, and regression helpers stay non-executable (`100644`).

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | The gate uses a fabricated HOME; after install, use no `AGENT_SKILLS_CHECK_HOME` override; only that real-HOME operator run detects installed-runtime external-skill drift. Both forms check agent parity and workflow/prompt drift. |
| Agent schema validation | `npm run check:agents-schema` | Validates Claude/OMP agent frontmatter parsing, required fields, name/filename matches, runtime-only field drift, retired bridge wording in Claude/OMP bodies, dialect-specific tool names, OMP MCP tool inventory, and canonical OMP multiword keys. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.omp/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.omp/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near or under **100 lines** when practical; split distinct or advanced content into one-level references, and check triggers, examples, and reference depth. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs every top-level `tests/*.sh` file. Keep this inventory synchronized when adding, removing, or renaming a shell regression script.

| Script | Focus |
| --- | --- |
| `tests/agent-check.sh` | `agents/check.sh` parity, canonical-pointer coverage for generic and routed MR agents, prompt-drift, external-skill dependency, and no-mutation `install.sh --check` regressions under temporary homes. |
| `tests/agent-handoff-templates.sh` | Builder/reviewer final-handoff locator fields, explicit builder pre-gate `not-created`, no YAML fence, and no live locators. |
| `tests/agents-schema.sh` | Claude/OMP agent frontmatter parsing, required fields, name/filename matching, runtime-only field drift, dialect-specific tool casing, OMP MCP inventory, retired Pi fields/bridge wording, OMP model-provider allowlist, OMP thinking-level values, canonical OMP multiword keys, and model-token-free route names. |
| `tests/authority-verification-schema.sh` | Canonical `gitlab/reference/authority-verification.md` and `.schema.json` own approval/merge authority claim shape, source precedence, conflict/restricted/missing-source outputs, proceed/handoff/ask-human routing, builder/self-approval/self-merge blocks, and separate authority-vs-transport evidence references from Reviewer Lift, Review Report, delivery handoffs, finish result schema, authority matrix, Mutation Guard, and identity docs. |
| `tests/builder-prompt-dedupe.sh` | Claude/OMP builder prompts stay frontmatter plus invoke `start-build`, reject inlined policy headings, and stay below the tiny route-pin body cap. |
| `tests/check-gate-inventory.sh` | Check Gate shipped shell regression inventory stays synchronized with tracked `tests/*.sh` files. |
| `tests/compaction-index.sh` | Compaction skill-index extension keeps `session.compacting` re-injection deduped, within per-entry 2 KiB and total 16 KiB caps, free of full skill bodies, and `install.sh` links it into `~/.omp/agent/extensions/` while skipping and reporting when the OMP agent dir is absent. |
| `tests/executable-bit-policy.sh` | Executable-bit policy enforcement: reads `git ls-files -s` index modes (not filesystem perms) and fails closed when any tracked `100755` file falls outside the documented allowlist (`install.sh`, `scripts/check.sh`); fixture self-tests prove a stray executable test, a non-allowlisted top-level script, and an executable non-allowlisted helper all FAIL while the two documented entrypoints PASS. |
| `tests/finding-identity-bindings.sh` | Pure-local canonical finding identity validator: two Review Reports may both define `MF-5` while `(Report locator, Reviewed SHA, Finding ID)` tuples remain distinct; valid Revision Packet and Reviewer Lift bindings pass; bare/missing/stale/contradictory bindings fail before publication/ready; LF and CRLF inputs produce the same result through platform-neutral Node path handling and no network calls. |
| `tests/finish-result-schema.sh` | `gitlab/reference/finish-result-schema.json` carries the finish result/action/SHA/blocker, optional nullable advisory `ci`, issue state, cleanup, authority/caller evidence, transport, conflict, and retry vocabulary. |
| `tests/gitlab-ci-finish-guards.sh` | `ci-watch-sha-pinned` remains read-only advisory evidence; `finish-mr-authority-aware` requires exact candidate, Gate Receipt, authority/caller, exactly one mutation/readback, nullable advisory CI, and native policy refusal reporting. |
| `tests/gate-receipt-validator.sh` | Cross-platform pure-local Gate Receipt validator: accepts the canonical exact-SHA receipt; rejects missing/malformed/stale/prose-only/unsafe receipt and Reviewer Lift evidence without body leakage; rejects changed tracked files and any tracked-change waiver; proves Windows/UNC path plus CRLF handling; enforces pre-ready ordering; and keeps build/review cards and generated templates pointed at the canonical helper. |
| `tests/handoff-tokens-schema.sh` | Canonical forge-neutral reviewer-handoff token arrays and nine-entry action-blocker crosswalk stay exact; every crosswalk target exists in the mutation-guard or finish-result schema; installed token consumers, the three template pointers, and schema-derived token grep invariants stay synchronized. |
| `tests/gitlab-mcp-first-workflows.sh` | GitLab workflow docs/prompts stay MCP-first for GitLab API actions, preserve stable `/gitlab` snippet names, allow `glab` only as documented fallback/helper/troubleshooting/test coverage, require per-snippet transport contracts, preserve safe-text/content-byte rules for MCP bodies, and record known MCP merge/list gaps. |
| `tests/gitlab-mutation-guard.sh` | `gitlab/reference/mutation-guard.md` and `mutation-guard.schema.json` define the canonical GitLab Mutation Guard seam with ordered exact-candidate Gate Receipt and advisory CI phases, blocker/gap/transport evidence tokens, fallback-forbidden states, approval/finish profiles, top-level merge metadata, successful post-mutation readback classification, and cross-project `skill://gitlab/...` guard resource guidance. |
| `tests/gitlab-snippet-metadata.sh` | `gitlab/reference/snippet-metadata.json` remains the machine-readable source of truth for all 21 stable GitLab workflow snippets; verifies required metadata fields, unchanged snippet names, `skill://gitlab/reference/...` resource references, via evidence tokens, and exact sync between the Markdown transport table and metadata. |
| `tests/delivery-schema.sh` | Neutral compact `delivery.kind=change-delivery` vocabulary remains supported while final handoffs use locator fields and explicit pre-gate absence, without generated delivery blocks. |
| `tests/forge-neutral-workflows.sh` | Shared build/review/delivery workflows bind one provider through the five-operation `/forge` seam; common guard ordering, provider-native GitLab/GitHub/Azure DevOps constraints, neutral delivery schema, routed agents, and setup generation remain forge-neutral. |
| `tests/gitlab-help-cache.sh` | `/gitlab` help-first run-dir cache guidance, context invalidation, and verification-status wording. |
| `tests/gitlab-build-cards.sh` | Deleted GitLab build cards stay gone; `/forge` GitLab branch points at `gitlab/SKILL.md` while generic `/start-build` owns no direct GitLab card links. |
| `tests/gitlab-review-cards.sh` | Deleted GitLab review/CI cards stay gone; `/forge` GitLab branch points at `gitlab/SKILL.md` while generic `/start-review` owns no direct GitLab card links. |
| `tests/gitlab-split-snippets.sh` | GitLab workflow snippets remain split into Draft MR create, MR description update, Draft MR mark-ready, SHA-bound approval, merge, auto-merge, MR-note, issue-note, label-reconcile, safe-mr-json, auto-merge-api-fallback, CI watch, and finish MCP tool guidance. |
| `tests/install-external-deps.sh` | `install.sh` warnings for missing required external skills and silence when they exist under a temporary `HOME`. |
| `tests/install-symlink-ownership.sh` | `install.sh` preserves out-of-repo symlinks, replaces stale in-repo symlinks, and keeps the default builder plus final reviewer installed in each runtime dialect without treating model pins as route names — all under temporary `HOME`. |
| `tests/installer-smoke-requirement.sh` | Installer smoke requirement docs stay present in `docs/agents/check-gate.md`: `install_surface` surface, `agents/`, `install.sh`, runtime routing triggers, temp-HOME installer smoke evidence, parent-owned gate evidence requirement, default MR route symlink ownership in `install-symlink-ownership` inventory entry, `installer-smoke-requirement` self-entry. |
| `tests/md-links.sh` | Markdown local-link checker diagnostics for broken files, anchors, image targets, allowed skill URIs, and external URL host allowlist behavior. |
| `tests/parent-subagent-placement.sh` | Parent-only subagent discovery guidance stays in the parent-orchestrator recipe and out of child builder prompts. |
| `tests/omp-agent-loader-smoke.sh` | See the coverage summary in the [test's header](../../tests/omp-agent-loader-smoke.sh). |
| `tests/post-merge-verifier-read-only.sh` | Canonical post-merge verifier recipe read-only invariant keeps the forbidden-action tokens (approve/merge/queue, force-close, delete-branch, release/deploy/operator), `issue_closure_pending` / `source_branch_cleanup_pending` report tokens, helper wiring, and removed top-level skill absence check, and keeps the post-#152 dropped "promised docs/ADR/follow-ups" check absent. |
| `tests/project-profile-hooks.sh` | `project_profile` extension fields stay documented in the GitLab delivery schema and generated handoff copies; setup-dev-skills seeds/generated docs declare gate, labels, branch naming, CI jobs, domain/ADR, release/deploy, manual validation, language, and auxiliary index hooks; GitLab-specific schema names and safety invariants remain intact. |
| `tests/project-profile-facts.sh` | `setup-dev-skills/reference/project-profile-facts.json` remains the canonical project-profile fact source for Agent Setup Doc paths, Triage Role-to-live-label mappings, Check Gate refs, Dev Workflow refs, branch naming, CI parity, skill resource URIs, and a non-default docs/labels fixture; setup seeds/live docs and GitLab issue pickup avoid globally hardcoded labels. |
| `tests/queued-auto-merge-default-finish.sh` | Advisory-CI policy graph invariant: exact-candidate local Gate Receipt is the singular quality gate; review, authority, mutation/readback, queue non-terminality, post-merge containment/closure/cleanup, and native policy refusal remain mandatory. |
| `tests/regression-harness.sh` | Shared regression harness self-check for shell assertion primitives, command-output capture, marked-section extraction, and schema-sync field extraction. |
| `tests/reviewer-prompt-dedupe.sh` | Claude/OMP reviewer prompts stay frontmatter plus invoke `start-review` below the tiny route-pin body cap, and shared ADR template ownership/drift stays enforced. |
| `tests/reviewer-lift-schema.sh` | Reviewer Lift generated-copy blocks match the canonical schema and stale duplicate field-list tables are rejected. |
| `tests/reviewer-lift-transport.sh` | Reviewer Lift declares a build-side Transport field whose enum matches the finish-result schema exactly, forces naming the eligible MCP gap for `glab-fallback`, and appears in every generated copy. |
| `tests/runtime-shared-resources.sh` | Disposable temp-HOME installs prove Windows, Linux, and macOS shared-resource behavior for both native symlink-preserving checkouts and symlink-disabled checkouts where Git materializes links as relative-target files. Installed Claude and OMP skills expose the canonical shared docs/templates through skill-local `docs/` and `shared-templates/` paths from a foreign project cwd, including the Agent Readiness scorecard; runtime skill roots do not expose `docs`/`templates` as bogus skills; invoked agent prompts and workflow skill entrypoints use explicit `skill://<skill>/...` URIs for reusable skill-owned docs/templates/scripts while preserving target-rooted `docs/agents/...` policy references. |
| `tests/setup-dev-skills-guardrails.sh` | `setup-dev-skills` coding guardrails seed, generated pointer, and no upstream prose vendoring regressions. |
| `tests/setup-dev-skills-invocation.sh` | `setup-dev-skills` remains manual-invocation only and docs preserve ask-before-running guidance. |
| `tests/start-build-mode-cards.sh` | Deleted `start-build` mode cards stay gone; `SKILL.md` points at canonical child-builder, parent-owned-gate, implementation-flow, and parent-orchestrator docs. |
| `tests/start-review-mode-cards.sh` | Deleted `start-review` mode cards stay gone; `SKILL.md` points at REVIEW-FLOW, review-report, and reviewer-final-handoff instead of checklist cards. |
| `tests/token-grep-invariants.sh` | Table-driven collapse of the token-grep farm and five `*-invariants.sh` scripts: same needles via `tests/lib/assertions.sh`, fewer files. |


## CI parity

`.gitlab-ci.yml` mirrors the local Check Gate instead of re-encoding individual checks in CI:

- The repo-local runtime contract is Node.js 22.x (`.nvmrc` and `package.json` `engines.node`).
- GitLab CI uses the Node 22 image.
- Advisory GitLab CI job name: `check` (stage `validate`).
- The `check` job runs `npm ci` so dependencies come from `package-lock.json`.
- The `check` job then runs `npm run check`, the same canonical command used locally.
- Pipeline workflow rules create pipelines for merge requests, the default branch, and tags.
- CI caches npm's download cache under `.npm/`, keyed by `package-lock.json`; `npm ci` remains the correctness boundary, so cache misses only make installs slower.

Do not add CI-only validation here unless it is first added to `npm run check` and documented as part of the local Check Gate.

## Manual validation rules

Manual validation is supporting evidence only when automation cannot cover the
change. Record exact commands or observations, redact secrets, and bind the
evidence to the reviewed SHA. Manual validation does not replace `npm run check`
for ready-marking unless the MR records a specific, reviewed exception.

## Installer smoke requirement

When a change alters the **install surface** — the topology the installer actually materializes — declare `install_surface` in `Acceptance surfaces` and include installer smoke evidence. The install surface is the set of inputs that change what `./install.sh` links or exposes, not every file under `agents/`. A change is on the install surface when it touches any of:

- agent **frontmatter** that the installer or runtime routing reads: an agent's `name`, its routing identity (route filename / basename), or its `skills:` / `autoload-skills:` lists;
- `install.sh` itself, or the runtime agent routing / symlink topology it produces (which agent and skill symlinks exist, and where they point);
- adding, removing, renaming, or moving a tracked file under `agents/` (a new agent dialect file, a deleted route, a renamed skill), since that changes which symlinks the installer creates.

A change is **not** on the install surface — and does not by itself require installer smoke — when it edits only an agent file's prose **body** while leaving that file's frontmatter (`name`/routing/`skills:`/`autoload-skills:`), filename, and symlink topology byte-identical. A body-prose-only edit under `agents/` therefore does not trigger this requirement on its own.

This requirement cannot be satisfied by `npm run check:agents-schema` or `./install.sh --check` alone; an actual `./install.sh` run in a temp HOME confirms installer output behavior.

Required evidence: run `HOME=<tmpdir> ./install.sh` and verify that expected agent and skill symlinks exist and no unintended additions or removals occurred. Use a safe temp HOME to avoid mutating the live `$HOME`.

For parent-owned gate evidence, name `./install.sh` or a temp-HOME installer smoke as the expected confirmation when `install_surface` is present.

`tests/install-symlink-ownership.sh` regression covers default MR route symlink ownership in both runtime dialects under `npm run check`. A live temp-HOME installer smoke supplements rather than replaces it.

**Session-cache caveat:** Agent definitions are loaded into a coordinator session's spawn inventory at session start. In-session spawn checks therefore reflect pre-change frontmatter after a merge; a live smoke of changed agent definitions using the same session will see the cached (pre-merge) state and is inconclusive by design. Live smoke of changed agent definitions requires a fresh session — record this as an operator step after each merge that touches agent frontmatter or routing.

## When the gate cannot be run

If agent directories do not exist on a host, `./install.sh` skips them. Treat skipped agent targets as N/A and report the observed `skip:` lines rather than failing the change.
