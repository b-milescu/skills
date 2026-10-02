# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

Run the local gate with Node.js 22.x, matching `.nvmrc`, `package.json` `engines.node`, and the GitLab CI `node:22` image. `npm run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which owns the checks it runs and their order. Its Node step, `node --test 'tests/*.mjs'`, is the native test framework for JavaScript tests: every top-level `tests/*.mjs` file runs in parallel under Node's built-in runner, so a new `.mjs` test is gated by adding the file, with no wrapper script.

**Fresh checkout or worktree bootstrap:** A fresh checkout or new worktree must bootstrap before running the gate. Switch to Node 22 per `.nvmrc` (e.g. `nvm use 22`), then run `npm ci` to install dependencies from `package-lock.json`, then run `npm run check`. Skipping either bootstrap step produces spurious failures (wrong Node version or missing `node_modules`).

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

These project-owned facts are declared here and in the confirmed [profile](dev-workflows.md#project-profile-hooks), never inferred from installed shared field guidance.

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
| Agent/install consistency | `./install.sh --check` or `bash agents/check.sh` | Read-only route inventory/parity and runtime schema checks; no external specialist dependency or prose/copy pins. |
| Agent schema validation | `npm run check:agents-schema` | Runtime-specific complete declarations, names/model/effort/role pins and exact/server-scoped selector syntax; native locations accepted, empty requested validation rejected. Metadata is not hard confinement. |
| Install script syntax | `bash -n install.sh` | Verifies shell syntax without mutating repo state. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| JavaScript tests | `node --test 'tests/*.mjs'` | Node 22 built-in runner over every top-level `tests/*.mjs` (plain `node:assert/strict` files); runs in parallel, continues past failures, prints a failure summary. Keep the glob quoted: an empty match then runs nothing instead of Node's repo-wide default patterns, and a directory argument fails on Node 22. |
| Skill install smoke | `./install.sh` then `test -L "$HOME/.claude/skills/<skill>"` and/or `test -L "$HOME/.omp/agent/skills/<skill>"` | Safe local symlink update; confirms new skill is surfaced to installed agents. |
| Agent install smoke | `./install.sh` then `test -L "$HOME/.claude/agents/<agent>.md"` and/or `test -L "$HOME/.omp/agent/agents/<agent>.md"` | Safe local symlink update; confirms new agent dialect file is surfaced to installed agents. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near or under **100 lines** when practical; split distinct or advanced content into one-level references, and check triggers, examples, and reference depth. |
| Gate/finding/text behavior | `node --test tests/gate-receipt-validator.mjs tests/finding-identity-bindings.mjs tests/forge-text-validator.mjs` | Canonical row presence, opaque bindings, receipt/candidate/owner/custody, original finding identity and no-echo Unicode/envelope rejection; native scope verification remains separate. |
| Installed foreign-CWD helpers | `bash tests/installer-smoke-requirement.sh` | Real disposable-HOME installation, resolved helper execution and read-only HOME snapshot; no live operator HOME writes. |
| Runtime route provenance | `bash tests/omp-agent-loader-smoke.sh` | Actual installed OMP loader in fresh processes and independently invoked allocated/revision contexts; not live model execution or hard MCP confinement. Claude precedence requires separate runtime proof. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs `node --test 'tests/*.mjs'` and then every top-level `tests/*.sh` file, keeps going after a failing step, and ends with the failing set (the Node step is listed as `tests/*.mjs`) and a non-zero exit; the pre-loop steps (`bash -n install.sh`, agent schema, `agents/check.sh`, Markdown lint, Markdown links) stay fail-fast. Keep this inventory synchronized when adding, removing, or renaming a shell regression script: `tests/check-gate-inventory.sh` fails closed when these row keys and the `tests/*.sh` disk glob disagree, which is what catches a test present on disk but unregistered.

Each script states its own coverage in a `# Focus:` header comment directly below its shebang; read the script rather than a paraphrase kept here.

| Script |
| --- |
| `tests/agent-check.sh` |
| `tests/agents-schema.sh` |
| `tests/check-gate-inventory.sh` |
| `tests/check-gate-runner.sh` |
| `tests/executable-bit-policy.sh` |
| `tests/install-symlink-ownership.sh` |
| `tests/installer-smoke-requirement.sh` |
| `tests/md-links.sh` |
| `tests/omp-agent-loader-smoke.sh` |
| `tests/regression-harness.sh` |
| `tests/runtime-shared-resources.sh` |

## CI parity

`.gitlab-ci.yml` mirrors the local Check Gate instead of re-encoding individual checks in CI:

- The repo-local runtime contract is Node.js 22.x (`.nvmrc` and `package.json` `engines.node`), and CI runs the same major.
- Advisory GitLab CI job name: `check` (stage `validate`). It runs `npm run check`, the same canonical command used locally.

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
