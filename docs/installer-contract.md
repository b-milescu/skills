# Public installer contract and compatibility evidence

## Decision and release boundary

This is the retained contract for [#509](https://gitlab.example.com/agents/skills/-/work_items/509), not an executable installer or release announcement. The owner approved the [catalog CLI architecture](https://gitlab.example.com/agents/skills/-/work_items/509#note_59697), [hosting](https://gitlab.example.com/agents/skills/-/work_items/509#note_59700), and [bounded readiness contract](https://gitlab.example.com/agents/skills/-/work_items/509#note_59702). Native plugins are a compatibility comparison, not a newly selected architecture.

Core acquisition uses `https://gitlab.example.com/agents/skills.git`. The npx executable retains `@agents/skills` and explicitly selects `https://gitlab.example.com/api/v4/projects/16/packages/npm/`, without changing the operator's global registry or implying npmjs.com hosting. Normal downloads require no SSH keys or private registry credentials; publishing is authenticated and separately authorized, preferably through the project's CI job token. Consumers need reachable DNS and trusted TLS for this origin; workstation access is not public-internet reachability. No plaintext HTTP exception or automatic TLS downgrade is approved.

Distribution is a standard npm tarball with an explicit payload allowlist, materialized required skill resources and only reusable Claude/OMP agent dialects. Complete project-native `.claude/agents` and `.omp/agents` are excluded. Bind executable and core payload to reviewed immutable commits/versioned snapshots; changed released bytes require a new semver, never replacement of an existing version. The first complete executable release is `0.1.0`, not the repository-only `0.0.0`. No package is published by this slice. Requiring an executable download here would contradict the downstream implementation order; real publication/package-download verification belongs to later installer/release delivery.

## Lifecycle ownership and preservation

| Resource | Sole lifecycle owner |
| --- | --- |
| Public skill acquisition/discovery | Reviewed, pinned upstream skills executable, invoked through its documented CLI only in disposable staging. Staging is not a security sandbox; no arbitrary installation hooks. |
| Managed payload snapshots and runtime projections, including reusable agents | Our catalog CLI publishes, refreshes and retires verified owned content. Upstream locks/state remain in staging, not a competing live ledger. |
| Selected MCP registration/config entries | Narrow native registration or validated additive publication by our CLI; ownership is entry-level, not the entire config file. |
| MCP activation, authentication, account access and deployment | Runtime/operator; no credential copying or automated sign-in. |

Use one managed ownership record. Unknown catalog IDs, unmanaged collisions, invalid config and edited material are conflicts, not takeover requests. Failed acquisition leaves installed material unchanged. Refresh compares all required resources, not just entry-file hashes; installed snapshots are not live developer-checkout links. Preserve unrelated/user/site MCP settings and working extensions.

Legacy recognition requires explicitly identified predecessor checkout/view roots verified against the approved source and resolved symlink targets (absolute or relative). A `.skill-resource-views` name alone is insufficient: its `.source` relationship must resolve to a verified predecessor source. Preserve foreign/ambiguous links, regular files, edited snapshots and unknown roots; no recursive HOME discovery or implicit deletion.

Initial supported clients are Claude Code and OMP. Discover supported installed clients automatically, resolve configured roots and the selected/inherited OMP profile before writes, and write nothing when none are detected. A config directory is a heuristic, not authenticated-client or active-profile proof. Do not target every OMP profile automatically. Optional external skills/MCPs are explicit and off by default. Explicit targeting selects placement, not confinement; disclose shared `.agents/skills` visibility.

## Preserved identities and prerequisites

Retain the eight canonical entries: `setup-dev-skills`, `forge`, `start-build`, `start-review`, `issue-delivery-loop`, `plan-to-issues`, `cleanup-codebase`, `retro`. Preserve distinct unnamespaced `mr-builder` and `mr-reviewer-final` reusable routes and their [runtime dialects](../agents/README.md), independent review and safety floors. Target-owned complete declarations remain scoped to their target; installed resource aliases do not grant a foreign target this repository's profile or identity.

[#510](https://gitlab.example.com/agents/skills/-/work_items/510) must materialize portable resource closure and prove helper runtime dependencies from a foreign CWD before complete installation parity is claimed. Recorded baseline failures (upstream collision deletion, missing `js-yaml` for a copied helper, npm-pack resource-alias omission) are authoritative issue evidence, not failures rerun here. Entry discovery alone cannot satisfy helper readiness. Production installer/cutover, live operator installation/authentication/model invocation, runtime patches and releases remain outside #509.
