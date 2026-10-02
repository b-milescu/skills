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
the [safety-floor litany](../../start-build/SAFETY.md#safety-floors).

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

Only `scripts/check.sh` (via `npm run check`) keeps its tracked executable bit.
Shell, Node, and regression helpers stay non-executable (`100644`).

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Agent consistency | `bash agents/check.sh` | Read-only route inventory/parity and runtime schema checks; disposable HOME remains unchanged. |
| Agent schema validation | `npm run check:agents-schema` | Runtime-specific complete declarations, names/model/effort/role pins and exact/server-scoped selector syntax; native locations accepted, empty requested validation rejected. Metadata is not hard confinement. |
| Markdown formatting | `npm run check:md` | Runs pinned `markdownlint-cli2` against tracked Markdown with repo-local prompt-friendly rule config. |
| Markdown local links | `npm run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| JavaScript tests | `node --test 'tests/*.mjs'` | Node 22 built-in runner over every top-level `tests/*.mjs` (plain `node:assert/strict` files); runs in parallel, continues past failures, prints a failure summary. Keep the glob quoted: an empty match then runs nothing instead of Node's repo-wide default patterns, and a directory argument fails on Node 22. |
| Native install/lifecycle smoke | Native commands in [README](../../README.md#install-on-a-new-machine), with disposable HOME/config/profile | Observe installation, update/removal, exposed skill/agent identities and foreign-CWD helper/resource execution; preserve unrelated user/site content. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near or under **100 lines** when practical; split distinct or advanced content into one-level references, and check triggers, examples, and reference depth. |
| Gate/finding/text behavior | `node --test tests/gate-receipt-validator.mjs tests/finding-identity-bindings.mjs tests/forge-text-validator.mjs` | Canonical row presence, opaque bindings, receipt/candidate/owner/custody, original finding identity and no-echo Unicode/envelope rejection; native scope verification remains separate. |
| Runtime route provenance | `bash tests/omp-agent-loader-smoke.sh` | Actual installed OMP loader in fresh processes and independently invoked allocated/revision contexts; not live model execution or hard MCP confinement. Claude precedence requires separate runtime proof. |
| Stale naming check | `rg -n "<old-name>\|<rejected-term>" .` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs `node --test 'tests/*.mjs'` and then every top-level `tests/*.sh` file, keeps going after a failing step, and ends with the failing set (the Node step is listed as `tests/*.mjs`) and a non-zero exit; the pre-loop steps (agent schema, `agents/check.sh`, Markdown lint, Markdown links) stay fail-fast. Keep this inventory synchronized when adding, removing, or renaming a shell regression script: `tests/check-gate-inventory.sh` fails closed when these row keys and the `tests/*.sh` disk glob disagree, which is what catches a test present on disk but unregistered.

Each script states its own coverage in a `# Focus:` header comment directly below its shebang; read the script rather than a paraphrase kept here.

| Script |
| --- |
| `tests/agent-check.sh` |
| `tests/agents-schema.sh` |
| `tests/check-gate-inventory.sh` |
| `tests/check-gate-runner.sh` |
| `tests/executable-bit-policy.sh` |
| `tests/md-links.sh` |
| `tests/omp-agent-loader-smoke.sh` |
| `tests/regression-harness.sh` |

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

## Native install smoke requirement

Declare `install_surface` when native marketplace/plugin metadata, exposed skill or agent paths/identities, resource/dependency closure, or runtime-read frontmatter changes discovery or installed behavior. Agent body-only prose changes with unchanged discovery inputs do not trigger this surface.

Schema validation and read-only consistency are not installation evidence. In disposable HOME/config/profile paths, use each affected native manager to install the exact candidate, observe its exposed inventory and selected agent provenance in fresh processes, execute valid and invalid installed helpers from a foreign CWD without coordinator dependencies, and observe native update/remove lifecycle. Preserve unrelated skills, agents, extensions, MCP settings and credentials; legacy user links remain operator-owned.

For parent-owned evidence, name the affected native manager's isolated installation/discovery/lifecycle scenario as the expected confirmation. `tests/omp-agent-loader-smoke.sh` retains actual OMP marketplace installation and fresh discovery/resource checks when its source and Bun are available; `OMP_REQUIRE_LOADER=1` fails instead of reporting N/A. Claude selection needs independent native proof.

Installation/discovery does not prove live model routing or hard MCP confinement. Those remain explicit operator observations from the real spawning session; never infer them from metadata or widen selectors to manufacture proof.

**Session-cache caveat:** Agent definitions are loaded into a coordinator session's spawn inventory at session start. In-session spawn checks therefore reflect pre-change frontmatter after a merge; a live smoke of changed agent definitions using the same session will see the cached (pre-merge) state and is inconclusive by design. Live smoke of changed agent definitions requires a fresh session — record this as an operator step after each merge that touches agent frontmatter or routing.

## When the gate cannot be run

If an affected native runtime is unavailable, record the exact missing prerequisite and installation/discovery evidence as N/A. Required runtime proof remains incomplete; a schema pass or source inspection is not a substitute.
