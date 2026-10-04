# Check Gate

Local commands agents should run before claiming a change is ready in this repo.

## Full local gate

Run the local gate with Bun 1.4+, matching `.bun-version` (the CI pin), `package.json` `engines.bun`, and the GitHub Actions `check` job (Bun from `.bun-version`). `bun run check` is the canonical full Check Gate for this repo. It delegates to the read-only shell wrapper at `scripts/check.sh`, which owns the checks it runs and their order. Its JavaScript steps run every top-level `tests/*.mjs` file in its own Bun process, gated on that process's exit code, so a new `.mjs` test is gated by adding the file, with no wrapper script.

**Fresh checkout or worktree bootstrap:** A fresh checkout or new worktree must bootstrap before running the gate. Install the Bun release pinned in `.bun-version`, then run `bun install --frozen-lockfile` to install dependencies from `bun.lock`, then run `bun run check`. Skipping either bootstrap step produces spurious failures (wrong Bun version or missing `node_modules`). The gate also needs `bash` and `git` on `PATH`.

Use `Local gate: PASS — bun run check` in PR Review Packets when it passes.

For parent-owned gate selection, this policy and the bootstrap route above
already support an exact-candidate `bun run check` receipt. A fresh worktree
without `node_modules` needs bootstrap; it does not lack gate policy. Record
the parent as the bootstrap/gate executor without requiring a full gate pass
before implementation. If Bun 1.4+ or dependency installation cannot be
provided, report that specific prerequisite, not an N/A parent receipt or an
automatic ownership change. These are selection rules, not a report of an
observed local failure. Generic cases, including issues that add a gate, are
owned by [Check gate discovery](../../start-build/reference/context-and-planning.md#check-gate-discovery).

## Project-profile refs

Use this file as this repo's confirmed `project_profile.gate_policy_ref`.
The declared `ci_parity.reference` points to [CI parity](#ci-parity);
`manual_validation_rules.reference` points to
[Manual validation rules](#manual-validation-rules).
The exact-candidate full local gate is `bun run check`; CI is advisory.

These project-owned facts are declared here and in the confirmed [profile](dev-workflows.md#project-profile-hooks), never inferred from installed shared field guidance.

Project-profile hooks may specialize project policy, but they must not weaken
the [safety-floor litany](../../start-build/SAFETY.md#safety-floors).

## Gate coverage for ready handoff

This repo's `Gate coverage` is `exact-candidate-local`. `bun run check` must pass
on the exact PR head SHA; in parent-owned mode the durable Gate Receipt records
that command, candidate, and PASS result. This singular local gate is the
required quality evidence for ready, review, approval, and finish.

The `check` provider job runs the same command after `bun install --frozen-lockfile`. It is an advisory
parity signal, not another delivery gate. Record its locator, status, and SHA
when available, and attribute the status only when its SHA matches the reviewed
candidate or provider-proven integration commit. Pending, failed, canceled,
skipped, missing, stale, wrong-SHA, or unavailable CI never changes verdict,
authority, or action eligibility. Native GitHub branch protection on `main` (pull
request required, `check` status required, force-push and deletion blocked) may
still hold or refuse a merge; report that provider outcome and never bypass it. A
merge held only by pending `check` is waited out as in
[native integration](native-integration.md#wait-for-required-checks), then the
guarded finish re-runs.

## Executable-bit policy

Only `scripts/check.sh` (via `bun run check`) keeps its tracked executable bit.
Shell, JavaScript, and regression helpers stay non-executable (`100644`).

## Targeted checks

| Area | Command | Notes |
| --- | --- | --- |
| Agent consistency | `bash agents/check.sh` | Read-only route inventory/parity and runtime schema checks; disposable HOME remains unchanged. |
| Agent schema validation | `bun run check:agents-schema` | Runtime-specific declarations, canonical names and optional model/effort metadata; routes declare no `tools`, and a declared `tools` is checked for syntax only. Native locations accepted, empty requested validation rejected. Metadata is not effective model/effort proof. |
| Markdown formatting | `bun run check:md` | Runs the pinned `markdownlint-cli2` on Bun (`bunx --bun --no-install`) against tracked Markdown with repo-local prompt-friendly rule config; without a prior `bun install` it fails loudly instead of fetching a different release. |
| Markdown local links | `bun run check:links` | Validates tracked Markdown relative links, image targets, anchors, and allowlisted external URL hosts without live network calls. |
| JavaScript tests | `bun tests/<file>.mjs`, or `bun test ./tests/<file>.mjs` for a file that imports `node:test` | `scripts/check.sh` runs every top-level `tests/*.mjs` in its own process and gates on its exit code, so one file's late async throw or `process.exit(0)` cannot hide or skip another file's result; it continues past failures and lists each failing file. A `node:test` file runs through `bun test` (the only runner it works under) with an explicit `./` path, because `bun test` treats a bare `tests/x.mjs` or a quoted glob as a name filter that matches nothing; every other file is a plain `node:assert/strict` script run as `bun tests/<file>.mjs`. An empty `tests/*.mjs` match runs nothing, and a bare `bun test` never runs (it discovers `*.test.*` files repo-wide). |
| Native install/lifecycle smoke | Native commands in [README](../../README.md#install-on-a-new-machine), with disposable HOME/config/profile | Observe installation, update/removal, exposed skill/agent identities and foreign-CWD helper/resource execution; preserve unrelated user/site content. |
| Skill size/readability | `wc -l <skill>/SKILL.md` | Keep `SKILL.md` near or under **100 lines** when practical; split distinct or advanced content into one-level references, and check triggers, examples, and reference depth. |
| Gate/finding/text behavior | `bun tests/gate-receipt-validator.mjs`, `bun tests/finding-identity-bindings.mjs`, `bun tests/forge-text-validator.mjs` | Canonical row presence, opaque bindings, receipt/candidate/owner/custody, original finding identity and no-echo Unicode/envelope rejection; native scope verification remains separate. |
| Skill-stack agnosticism | `bun test ./tests/skill-stack-agnostic.mjs` | Walks the file system (no git; `.git`, `node_modules` and `start-build/scripts/vendor/` skipped) over the eight skill directories, `templates/` and `reference/` and fails with every `path:line` that names a code host, agent harness, model or vendor, outside skill or carries a machine-specific path; fails on any Node toolchain use in the stack (a `node` invocation, a Node package-manager or version-manager command, a Node runtime version requirement; `bun`, `node:` imports and `node_modules` stay allowed); fails on any stack symlink that does not resolve inside the stack; also fails on any repo `.mjs` loader form that is neither a `node:` builtin nor a relative path. |
| Runtime route provenance | `bash tests/omp-agent-loader-smoke.sh` | Actual installed OMP loader in fresh processes and independently invoked allocated/revision contexts; not live model execution. Claude precedence requires separate runtime proof. |
| Stale naming check | `git grep -nE "<old-name>\|<rejected-term>"` | Use after renames or terminology decisions. |
| Markdown presence | `find <skill> -maxdepth 1 -type f -print \| sort` | Confirms expected seed docs exist. |

## Shipped shell regression inventory

`scripts/check.sh` runs every top-level `tests/*.mjs` file and then every top-level `tests/*.sh` file, each in its own process, keeps going after a failing step, and ends with each failing file listed (for example `tests/foo.mjs`) and a non-zero exit; the pre-loop steps (agent schema, `agents/check.sh`, Markdown lint, Markdown links) stay fail-fast. Keep this inventory synchronized when adding, removing, or renaming a shell regression script: `tests/check-gate-inventory.sh` fails closed when these row keys and the `tests/*.sh` disk glob disagree, which is what catches a test present on disk but unregistered.

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

`.github/workflows/check.yml` mirrors the local Check Gate instead of re-encoding individual checks in CI:

- The repo-local runtime contract is Bun 1.4+ (`.bun-version` and `package.json` `engines.bun`), and CI installs that release with `oven-sh/setup-bun`.
- Advisory GitHub Actions workflow `check`, job `check`. After `bun install --frozen-lockfile` it runs `bun run check`, the same canonical command used locally.

Do not add CI-only validation here unless it is first added to `bun run check` and documented as part of the local Check Gate.

## Manual validation rules

Manual validation is supporting evidence only when automation cannot cover the
change. Record exact commands or observations, redact secrets, and bind the
evidence to the reviewed SHA. Manual validation does not replace `bun run check`
for ready-marking unless the PR records a specific, reviewed exception.

## Native install smoke requirement

Declare `install_surface` when native marketplace/plugin metadata, exposed skill or agent paths/identities, resource/dependency closure, or runtime-read frontmatter changes discovery or installed behavior. Agent body-only prose changes with unchanged discovery inputs do not trigger this surface.

Schema validation and read-only consistency are not installation evidence. In disposable HOME/config/profile paths, use each affected native manager to install the exact candidate, observe its exposed inventory and selected agent provenance in fresh processes, execute valid and invalid installed helpers from a foreign CWD without coordinator dependencies, and observe native update/remove lifecycle. Preserve unrelated skills, agents, extensions, MCP settings and credentials; legacy user links remain operator-owned.

For parent-owned evidence, name the affected native manager's isolated installation/discovery/lifecycle scenario as the expected confirmation. `tests/omp-agent-loader-smoke.sh` retains actual OMP marketplace installation and fresh discovery/resource checks when its source and Bun are available; `OMP_REQUIRE_LOADER=1` fails instead of reporting N/A. Claude selection needs independent native proof.

Installation/discovery does not prove live model/effort selection. Follow [native model and effort selection](../../start-build/reference/parent-orchestrator.md#native-model-and-effort-selection) and record explicit operator observations from the real fresh spawning session; never infer them from metadata.

**Session-cache caveat:** Agent definitions are loaded into a coordinator session's spawn inventory at session start. In-session spawn checks therefore reflect pre-change frontmatter after a merge; a live smoke of changed agent definitions using the same session will see the cached (pre-merge) state and is inconclusive by design. Live smoke of changed agent definitions requires a fresh session — record this as an operator step after each merge that touches agent frontmatter or routing.

## When the gate cannot be run

If an affected native runtime is unavailable, record the exact missing prerequisite and installation/discovery evidence as N/A. Required runtime proof remains incomplete; a schema pass or source inspection is not a substitute.
