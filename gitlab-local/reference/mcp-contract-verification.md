# gitlab-mcp contract verification reference

Phase-0 foundation reference for the **gitlab-mcp transport refactor** of `/gitlab-local` and `/gitlab-to-issues` (MCP-first; `glab` being dropped per maintainer decision). It records the verified behaviour of the `gitlab-mcp` tools the refactor depends on so Phase 1+ can rely on these contracts instead of re-deriving them.

Scope discipline for this reference:

- **Evidence is read-only / schema-level only.** No live mutation was performed against any real issue or merge request to produce this doc.
- Each area below states the **fact**, the **verification method**, and — where a claim is not confirmed in this environment (whether it would need a mutation or only a read-only call to confirm) — a **deferred procedure** to run later against a maintainer-provided sandbox MR or real server (or the Phase-1/2 fake harnesses), not an asserted live result.
- Command-syntax and flag ownership for the legacy `glab` path stays in [`gitlab-local/SKILL.md`](../SKILL.md); this reference owns only the MCP tool-contract facts.

## Verification status legend

| Status | Meaning |
| --- | --- |
| `live-read` | Confirmed by a read-only call against the real server (no mutation). |
| `schema` | Confirmed from the tool input/output JSON schema (client-side validation), no network mutation. |
| `sandbox-procedure` | Not confirmed in this environment; recorded here as a deferred procedure (read-only or mutating) to run later against a sandbox/real server or fake harness, **not** asserted as a live result. |

## 1. `confirm:true` enforcement (schema-level)

**Fact.** The destructive tools `approve_merge_request` and `merge_merge_request` declare `confirm` in their input schema as a **required** property constrained to `const: true` (equivalently `enum: [true]`). A call that omits `confirm`, or sends `confirm:false`/any non-`true` value, therefore fails **client-side JSON-schema validation before any network request is issued**. The schema is the enforcement point; server-side rejection is a second line of defence, not the first.

**Verification method.** `schema` — inspect the tool input schema (`tools/list` MCP listing or the published tool definition). Confirm for each destructive tool that `required` contains `"confirm"` and that the `confirm` property carries `const: true` (or `enum: [true]`). No call is sent.

**Refactor consequence.** Agent code must pass `confirm: true` explicitly on every `approve_merge_request` / `merge_merge_request` call. The missing-`confirm` failure is a **local validation error**, not a network/authorization error, and must be classified as a programming bug (fix the call site), never retried.

## 2. `update_merge_request` atomicity (designed contract + test procedure)

**Designed contract.**

- A single `update_merge_request` call that sends both `description` (new body) and `draft:false` toggles the MR to ready **and** sets the body in one atomic server-side update — the body is not lost.
- A call that sends `draft:false` **alone** (no `description` field) must **preserve the existing description**. Omitting `description` means "leave unchanged"; it must never be treated as "set body to empty".

**Verification method.** `schema` for the shape (confirm `description` and `draft` are independent optional fields and that omission means unchanged), plus `sandbox-procedure` for the live atomicity/preservation behaviour. The live mutation check is verified later via the Phase-1/2 fake harnesses, not asserted here.

**Sandbox test procedure** (run against a maintainer-provided sandbox MR only):

1. Read the current state: `get_merge_request` → record `description` (call it `body0`) and `draft` (expect `true`).
2. **Combined-toggle case.** Call `update_merge_request` with `description: <body1>` and `draft: false` in one call. Re-read `get_merge_request`; assert `draft == false` **and** `description == <body1>` (body present, equals what was sent).
3. **Preserve-on-toggle case.** On a fresh sandbox MR still in draft with a known `description` (`body0`), call `update_merge_request` with `draft: false` and **no** `description` field. Re-read `get_merge_request`; assert `draft == false` **and** `description == body0` (unchanged — not emptied).
4. Record both observed bodies in the test artifact. Any divergence (body emptied, body partially applied, draft not toggled) is a contract violation and blocks the refactor's ready-toggle path.

**Refactor consequence.** The "mark ready" path may safely combine a final description refresh with `draft:false` in one call. It must **never** send an empty/placeholder `description` merely to toggle draft state; omit the field instead.

## 3. `list_*` pagination and limits

**Fact.** The list tools `list_issues`, `list_merge_requests`, `list_pipelines`, and `list_branches` use a page-size of **20 by default** and **100 maximum**. A request for more than 100 items in one call is capped at 100; the remainder is only reachable by paginating.

| Tool | Default page size | Max page size |
| --- | --- | --- |
| `list_issues` | 20 | 100 |
| `list_merge_requests` | 20 | 100 |
| `list_pipelines` | 20 | 100 |
| `list_branches` | 20 | 100 |

**Filter / search ordering (documented expectation — not yet observed).** From the tool/API contract, `search=` and structured filters (state, labels, etc.) are expected to be applied **server-side before** the page cap: the server filters the full set, then returns at most one capped page of the already-filtered results. On that contract the cap is a cap on *returned matches per page*, not a cap on the candidate set that gets filtered, and a single call can still under-report when matches exceed the page size. This ordering was **not** confirmed by a live read in this environment; it is documented from the contract and carries a read-only procedure to confirm later (below). The required agent-side over-cap handling is conservative either way, so it does not depend on observing this ordering first.

**Verification method.** `schema` for the default/max page-size bounds (the pagination parameters and their min/max in the tool input schema) and for the documented filter-then-cap contract. The filter-before-cap *ordering* is **not** tagged `live-read`: no read-only `gitlab-mcp` call was performed in this environment to observe it (only the §5 GitLab REST projection was available). It is recorded as a `sandbox-procedure` read-only check to run later (below), not asserted as a live result. No mutation.

**Read-only ordering check** (`sandbox-procedure`; read-only `list_*` calls, no mutation — run later to confirm the documented ordering):

1. Pick a `list_*` tool and a `search=`/filter value known to match more records than one page (or set a small page size so matches exceed it).
2. Issue the filtered call and record the returned count and whether every returned item satisfies the filter.
3. Issue the same call paginated to exhaustion; assert the total filtered matches exceed a single capped page (proving the cap bounds *returned matches per page*, not the pre-filter candidate set).
4. Assert no returned item violates the filter (i.e. filtering was applied to the full set server-side, then capped — not cap-first). Record the observed counts in the test artifact. Any result where the cap appears to bound the pre-filter candidate set contradicts the documented ordering and must be surfaced.

**Required agent-side over-cap handling.** Because any single list page can silently truncate at 100:

- Never treat a single `list_*` page as authoritative for "all matching" records. Treat a full page (page size == returned count == requested limit) as "possibly more".
- For decision-grade enumeration (for example, "is there an open MR for this branch?"), either pass an explicit narrow filter that bounds the result under the page size, or paginate until a short/empty page is returned.
- When a precise count or exhaustive set is required, paginate explicitly (advance the page parameter) rather than raising the page size beyond 100, which the server ignores past the max.

## 4. Idempotency and partial-failure contract

**Designed rules.**

- **Re-read after every mutation.** After any mutating tool call (`update_merge_request`, `approve_merge_request`, `merge_merge_request`, label/assignee changes), immediately call `get_merge_request` and re-check the SHA pin before trusting the local view. The mutation response alone is not authoritative; the re-read is.
- **SHA-pin re-check.** Compare the re-read head SHA against the reviewed/expected SHA. A mismatch means the head moved under the operation and the action must not be assumed applied to the intended commit.

**Conflict classification.** When a mutation does not produce the expected state, classify the outcome from the re-read before retrying:

| Classification | Detected by | Meaning / action |
| --- | --- | --- |
| `already_merged` | re-read shows a merge or squash commit present / MR state `merged` | The MR is already merged (this op or a prior one succeeded). Treat as success-equivalent; do **not** retry the merge. |
| `stale_head` | re-read head SHA differs from the pinned/expected SHA | The head moved (new push or rebase). Fail closed; the action targeted a SHA that is no longer current. Re-evaluate against the new SHA rather than blindly retrying. |
| `merge_blocked` | re-read MR state is not `opened` (closed, or otherwise not mergeable) and no merge commit is present | The MR is not in a mergeable open state. Fail closed; do not retry the merge. Surface for human/parent decision. |

**Retry guard / fail-closed rule.** A mutation retry loop caps attempts at a small fixed bound (for example, a handful of attempts) and then **fails closed** — it stops, reports the last classification, and does **not** continue retrying. The guard exists so a transient classification (such as a brief `stale_head`) cannot turn into an unbounded retry storm against a live record. `already_merged` short-circuits the loop as success-equivalent; `stale_head` and `merge_blocked` exit the loop into the fail-closed report.

**Verification method.** `schema` for the `get_merge_request` re-read shape (state, head SHA, merge-commit presence) used by the classifier, plus `sandbox-procedure` for the live conflict transitions. The live mutation transitions are verified via the Phase-1/2 fake harnesses, not asserted here.

**Sandbox test procedure** (sandbox MR / fake harness only):

1. `already_merged`: merge a sandbox MR, then re-issue the merge; assert the classifier returns `already_merged` and the retry loop short-circuits without a second merge.
2. `stale_head`: pin a SHA, push a new commit to the source branch, then attempt a SHA-pinned mutation; assert the re-read reports `stale_head` and the loop fails closed.
3. `merge_blocked`: close a sandbox MR, attempt a merge; assert `merge_blocked` and fail-closed (no retry).
4. Retry-guard bound: drive a repeatable `stale_head` and assert the loop stops at the configured attempt cap and reports the last classification.

## 5. Project-path and default-branch validation

**Fact (live-verified, read-only).** `get_project` for `agents/skills` returns, among other fields:

- `pathWithNamespace: "agents/skills"`
- `defaultBranch: "main"`
- `httpUrlToRepo: "https://gitlab.example.com/agents/skills.git"`
- `sshUrlToRepo: "git@gitlab.example.com:agents/skills.git"`

**Verification method.** `live-read` — confirmed read-only against the real server. The same fields are exposed by the underlying GitLab Projects API projection that `get_project` wraps (`path_with_namespace`, `default_branch`, `http_url_to_repo`, `ssh_url_to_repo`); the MCP tool returns them under the camelCase names above. No mutation.

**Validation rule.**

1. Derive the candidate project path from `git remote get-url origin` (strip the scheme/host and the trailing `.git`; for an SSH remote `git@<host>:group/sub/project.git` and an HTTPS remote `https://<host>/group/sub/project.git`, the project path is `group/.../project`).
2. Call `get_project(<candidate-path>)` and compare `pathWithNamespace` to the candidate.
3. **The server is authoritative on mismatch.** If `pathWithNamespace` differs from the locally derived path, trust the server's value and stop to surface the discrepancy rather than acting on the local guess.
4. Resolve the default branch from `get_project().defaultBranch` — **never** assume `main`/`master`. Use the server's `defaultBranch` as the MR target branch and the base for new source branches.

**Failure modes to handle.**

- **Shallow clone.** A shallow/partial clone can lack remote refs and a reliable `origin/HEAD`; do not infer the default branch from local refs. Resolve it from `get_project().defaultBranch`.
- **Default branch renamed on the server.** The server may have renamed the default branch (for example `master` → `main`) since the clone. `get_project().defaultBranch` is authoritative; a stale local assumption must not override it.
- **Stale `origin/HEAD`.** A locally cached `origin/HEAD` can point at an old default branch. Re-derive from the server rather than from `git symbolic-ref refs/remotes/origin/HEAD`.
- **Nested `group/subgroup/project` encoding.** Nested namespaces produce multi-segment paths (`group/subgroup/project`). When a call requires a URL-encoded path identifier, encode `/` as `%2F` (`group%2Fsubgroup%2Fproject`); when the tool accepts a plain path, pass the unencoded `group/subgroup/project`. Validate the full multi-segment `pathWithNamespace`, not just the final `path` segment.

## Cross-references

- Legacy `glab` command mechanics, help-first discipline, and SHA-pinning syntax: [`gitlab-local/SKILL.md`](../SKILL.md#help-first-rule).
- Canonical workflow snippets (preflight, MR read/update, finish guards) the MCP refactor will replace: [`gitlab-local/SKILL.md` canonical snippets](../SKILL.md#canonical-snippets).
