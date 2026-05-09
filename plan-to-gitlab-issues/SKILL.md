---
name: plan-to-gitlab-issues
description: Convert a markdown implementation plan into GitLab issues via the glab CLI — one issue per phase/section, with dry-run preview, labels, parent/epic links, and mandatory post-create overlap checks for duplicates, scope conflicts, and misaligned dependencies. Use when the user asks to "create issues from this plan", "open GitLab issues from PLAN.md", "split this plan into tickets", "make a ticket per phase", or wants implementation phases tracked as GitLab issues.
---

# Plan → GitLab issues

Turn a markdown plan into a set of GitLab issues, one per phase, using `glab`. **Always dry-run first** — preview every issue and wait for explicit user confirmation before any `glab issue create` runs. Issue creation is hard to undo cleanly.

## Inputs

- **Plan file** (required): path to a markdown file. Default to `PLAN.md` in the current working directory if the user doesn't name one.
- **Labels** (optional): comma-separated list applied to every created issue. Resolution order:
  1. Explicit user-supplied labels (CLI args / chat).
  2. Auto-detected from the plan's preamble (everything before the first phase heading): a line matching `**Labels:** foo, bar` or `Labels: foo, bar` (case-insensitive). YAML frontmatter `labels: [foo, bar]` also accepted.
  3. Per-phase override: a `**Labels:** ...` line *inside* a phase section adds to that phase's labels only, on top of the global set.
  4. If none of the above, ask the user once before previewing — don't guess from heading text.

  Always echo the resolved labels per issue in the dry-run preview so the user can catch a misread.
- **Parent link** (optional): one of
  - `--linked-issues <iid>` — existing issue to link all phase issues under (creates a "relates to" link), or
  - `--epic <id>` — existing epic (only on GitLab tiers that support epics).
  - If the user wants a parent but hasn't created one, offer to create a tracking parent issue first.
- **Repo** (optional): `glab` resolves the repo from `git remote` by default. Only pass `--repo OWNER/REPO` if the user names a different one.

## Workflow

1. **Confirm target project.** Run `glab repo view` and show owner/name/host so the user can catch a wrong remote before issues land in the wrong project.

2. **Read & parse the plan.**
   - First scan the **preamble** (everything before the first phase heading) for global labels (see Inputs § Labels).
   - Then look for phase/section headings — typically `### Phase N — Title` or `## Phase N: Title`.
   - Within each phase, capture: numbered/bulleted sub-tasks, any `**Done when:** ...` line, any per-phase `**Labels:** ...` line, and any fenced code blocks verbatim.
   - Skip sections that aren't implementation phases (e.g., "Context", "Architecture summary", "Verification", "Open items") — list them as **skipped** in the preview.

3. **Propose granularity — don't pick it silently.** A phase is usually too coarse to be a *single* actionable issue: each sub-task inside it is typically its own commit/PR. Before building the issue list, present granularity options to the user and let them choose:
   - **(a) One issue per phase** — phase title is the issue title, sub-tasks become a `- [ ]` checklist in the body. Use only for short phases (≤2 sub-tasks) or when the user explicitly wants epic-style tracking.
   - **(b) One issue per sub-task** *(recommended default for plans with numbered sub-tasks)* — each numbered/bulleted sub-task becomes its own issue, titled e.g. `[Phase N.M] <sub-task summary>`. Phase title appears as a `Parent phase:` line in each body.
   - **(c) Hybrid: parent issue per phase + child issue per sub-task** — creates a tracking issue per phase plus one issue per sub-task, with `--linked-issues` from each child to its phase parent. Best when the user wants both rollup and granular tickets.
   - **(d) Per-phase choice** — let the user mark which phases to split and which to keep single (e.g., split big phases, keep small ones whole).

   Show: per-phase sub-task counts (e.g., "Phase 1: 6 sub-tasks, Phase 5: 3 sub-tasks") so the user can judge. Recommend (b) when most phases have ≥3 sub-tasks; recommend (a) only when phases are uniformly short. Wait for the user's pick before continuing.

4. **Build the issue list in memory.** Based on the chosen granularity:
   - **Per-phase issue** — Title: `[Phase N] <phase title>`. Body: phase intro + sub-tasks as `- [ ]` checklist + `**Done when:**` preserved + any code blocks.
   - **Per-sub-task issue** — Title: `[Phase N.M] <first line of sub-task, ≤72 chars>`. Body: full sub-task text + relevant code blocks + `Parent phase: Phase N — <title>` line + the phase's `**Done when:**` only on the *last* sub-task of the phase (or omit and put it on the parent if hybrid).
   - **Hybrid** — produce one parent per phase (no checklist; just intro + child URL placeholders, backfilled in step 9) plus per-sub-task children.
   - All bodies lead with `Source: <plan-file> § Phase N[.M]`.
   - **Labels**: union of global labels (from CLI args or plan preamble) and any per-phase `**Labels:** ...` line, deduplicated. Sub-task issues inherit their phase's labels.

5. **Print the dry-run preview.** Show: total issue count, target project (owner/name/host), planned labels, planned parent link, and for each issue: the title plus the first ~10 lines of the body. End with: "Reply `create` to proceed, or describe edits."

6. **Wait for explicit confirmation.** Don't proceed without "create" / "yes" / equivalent. If the user requests edits, adjust the in-memory plan and re-preview — don't partially create.

7. **(Optional) Create the parent issue first.** If the user opted for a tracking parent, create it with a body that lists each phase title (the children IIDs aren't known yet — leave a placeholder line, or update the parent body after step 9). Capture the parent IID from the URL `glab issue create` prints.

8. **Create the phase issues.** For each, write the body to a temp file (avoids shell-quoting issues with backticks, code fences, and quotes), then run:
   ```sh
   body_file=$(mktemp -t issue-body.XXXXXX.md)
   # ...write body to "$body_file"...
   glab issue create \
     --yes \
     --title "[Phase N] <title>" \
     --description "$(cat "$body_file")" \
     --label "<labels>" \
     --linked-issues <parent-iid>      # OR --epic <epic-id>, OR omit
   ```
   Capture the issue URL from each command's stdout.

9. **(If parent created)** Edit the parent issue body to replace the placeholder list with the real child issue URLs:
   ```sh
   glab issue update <parent-iid> --description "$(cat parent-body.md)"
   ```

10. **Mandatory post-create overlap check.** Immediately after issue creation, scan open GitLab issues for duplicates, overlaps, scope conflicts, and dependency misalignments before reporting success.

   Run the bundled helper from the skill directory (or equivalent scripted analysis if the harness cannot execute it):
   ```sh
   node scripts/check-issue-overlap.js <created-iid> [<created-iid> ...]
   ```

   Classify each candidate by reading Problem / Goal / Scope / Out-of-scope, not by keyword score alone:
   - **Duplicate** — same deliverable and same scope. Stop and ask before closing or superseding anything.
   - **Overlap / sibling** — shared surface, different layer. Add `relates_to` links and a breadcrumb comment on the new issue clarifying the scope split.
   - **Dependency** — one issue should happen before another. Add `relates_to` links and comment with the dependency chain.
   - **Mismatch / conflict** — contradictory ownership, canonical source, safety invariant, rollout order, or deploy assumption. Stop and ask the user how to resolve.
   - **Unrelated** — generic word overlap only. Ignore.

   For material non-duplicates, add concise comments like:
   ```md
   Overlap check after creation: no duplicate found.

   Scope breadcrumb:
   - #<new> owns <specific layer>.
   - #<existing> owns <other layer>.
   ```

   Use GitLab relation links for navigation:
   ```sh
   glab api -X POST \
     "projects/<project-id>/issues/<new-iid>/links?target_project_id=<project-id>&target_issue_iid=<existing-iid>&link_type=relates_to"
   ```
   Treat "already exists" / 409 responses as success. Do not silently close duplicate issues; ask first unless the user explicitly pre-authorized cleanup.

11. **Report.** Print a numbered list `[Phase N] <title> — <url>` plus the parent URL if any. Include post-create overlap results: duplicates found, links/comments added, conflicts needing user decision, and any failed creations. Mention any phases that failed to create and stop — don't keep going past a failure.

## Notes & gotchas

- **Don't use `git add -A` mistakes here either** — this skill only creates GitLab issues, it doesn't touch the working tree. If the plan references files that don't exist yet, that's fine; issues describe future work.
- **`--linked-issues` is "relates to"**, not strict parent/child. For a strict hierarchy on a tier that supports it, use `--epic`.
- **Multi-line bodies via temp file**, not `-d "$(cat <<EOF ...)"`. Heredocs with embedded backticks and code fences inside the plan break shell parsing.
- **Flat-checklist plans** (no phase headings, just `- [ ] item` at the top level): fall back to one issue per top-level checklist item and confirm explicitly in the preview that this is the intended granularity — don't silently switch modes.
- **Authentication**: assume the user has run `glab auth login` for the target host. If `glab repo view` fails with auth errors, stop and tell the user, don't try to recover.
- **Idempotence / overlap hygiene**: the dry-run prevents accidental creation, and the mandatory post-create check catches duplicates/overlaps that were not obvious from the plan. If the user re-runs after a partial failure, warn them they may create duplicates; search existing open issues before creating replacements when titles are predictable, and always run the post-create overlap check for newly-created IIDs.
