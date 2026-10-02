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

### Portable core packaging boundary

The [source-packaging recipe](../README.md#portable-core-payload-not-an-executable-release)
materializes `core/` during `npm pack`, using an explicit source allowlist.
Keep the installed package plus npm's production dependency tree intact:
`js-yaml` is a package runtime dependency, not a coordinator devDependency.
Helpers are resolved from the installed skill directory and run from the invoked
target CWD. Shared aliases become directories, not new skill entries.

This payload is not the downstream catalog/client installer. Its private
repository-only `0.0.0` version has no executable and is not advertised as a
published npm download. Anonymous immutable HTTPS archive acquisition followed
by real local npm packaging/installation proves this bounded payload; executable
publication and registry-download proof retain the downstream release boundary.
No native project declaration is in the allowlist. Materialized native-policy
documents retain source ownership and cannot configure an unrelated target.

## Isolated observations — 2026-10-02

Source baseline: `90c046df551f5a1de7ba761b83d4a996128692e4`; observed runtimes: Claude Code `2.1.285`, OMP `18.4.10`. Five separate disposable roots were used: Claude standalone/bundle and OMP standalone/Claude-layout bundle/native-layout bundle. Every process used a foreign CWD and `env -i` with only disposable HOME/config roots, executable PATH (and TERM for the terminal observation). No credentials, project-native agents, MCP configuration, hooks or model prompt were supplied. Payloads copied unchanged skill/agent files and dereferenced resource aliases solely for these probes; this is not a portable release or the #510 dependency fix.

### OMP: actual installed discovery and resource resolver

Fresh Bun processes imported the installed OMP modules, following the existing [loader observation seam](../tests/omp-agent-loader-smoke.sh), without running that test or the project gate:

```js
const { loadSkills } = await import(`${pkg}/src/extensibility/skills.ts`);
const { discoverAgents } = await import(`${pkg}/src/task/discovery.ts`);
const { SkillProtocolHandler } = await import(`${pkg}/src/internal-urls/skill-protocol.ts`);
const { skills, warnings } = await loadSkills({ cwd: foreignCwd });
const agents = await discoverAgents(foreignCwd, disposableHome);
const handler = new SkillProtocolHandler();
const resolved = await handler.resolve(new URL("skill://start-build"), { skills });
```

For bundles, the installed `src/discovery/helpers.ts` `injectPluginDirRoots(home, [bundle], cwd)` was called before discovery: the actual loader seam used by `--plugin-dir`, not a fake inventory. Standalone placement was `$HOME/.omp/agent/{skills,agents}`; native bundle placement was `bundle/{skills,agents}` without a Claude manifest. A separate Claude-layout comparison added `.claude-plugin/plugin.json` naming `skills-contract-probe`, while retaining the same OMP agent files.

| Observation | Result |
| --- | --- |
| Standalone skills | All eight preserved names; `native:user` source; no warnings. Selected paths were under the disposable `.omp/agent/skills`, not the developer checkout. |
| Native-layout bundle skills | All eight preserved names; `claude-plugins:user` provider label for this explicit plugin-dir path; no warnings. This provider label does not mean Claude agent metadata was selected. |
| Commands/namespaces | Both layouts returned `skill:start-build`, `skill:start-review`, etc.; no unconditional plugin prefix in this collision-free experiment. OMP observation is not a claim about Claude names or collision behavior. |
| Standalone routes | `mr-builder` and `mr-reviewer-final`, source `user`, selected from disposable `.omp/agent/agents`; `model: ["pi/task"]`, medium/xhigh thinking respectively. Autoloads were `["start-build","forge"]` and `["start-review","forge"]`. |
| Native-layout bundle routes | Same distinct route names, model/thinking and autoloads; selected paths were `bundle/agents/*.md`. |
| Claude-layout bundle with OMP agents | Both routes discovered and thinking/autoloads retained, but **model was absent** in both parsed results. This layout is incompatible with preserving the existing OMP model pins unchanged, despite successful skill discovery. |

In standalone and native-layout bundle processes, these actual `skill://` resolutions returned bytes equal to the canonical source (not just nonempty content):

| Resource | Observed UTF-8 bytes |
| --- | --- |
| `skill://start-build` | 7110 |
| `skill://start-review` | 5496 |
| `skill://forge` | 5059 |
| `skill://issue-delivery-loop` | 8133 |
| `skill://retro` | 8754 |
| `skill://start-build/docs/effort-scaling.md` | 4313 |
| `skill://start-build/shared-templates/adr.md` | 526 |
| `skill://start-build/scripts/validate-gate-receipt.mjs` | 20897 |

Thus the existing canonical entry references and sampled contained resources work through the installed OMP resolver with these materialized payloads. Reading helper source is **not helper execution**. Full resource closure, escaping relative links and dependency readiness remain #510's work. Route parsing is not spawning a model, invoking a workflow or verifying inherited tools/confinement.

### Claude: actual offline bundle inventory; execution limits

The installed binary was invoked from the separate foreign Claude CWDs with disposable HOME and `CLAUDE_CONFIG_DIR`. Commands and outcomes:

```text
claude --plugin-dir <disposable-bundle> plugin details skills-contract-probe
  skills-contract-probe 0.0.0; Source: skills-contract-probe@inline
  Skills (8): cleanup-codebase, forge, issue-delivery-loop, plan-to-issues,
              retro, setup-dev-skills, start-build, start-review
  Agents (2): mr-builder, mr-reviewer-final
  Hooks (0); MCP servers (0); LSP servers (0)

claude plugin details start-build
  Plugin "start-build" not found (exit 1)
```

The bundle contained only the unchanged **Claude** reusable agent dialect, not the OMP files or complete project declarations. The runtime inventory recognizes both distinct roles and all eight entry names. However, `plugin details` is a bundle inventory, not standalone skill discovery: the second result establishes that it cannot prove installed standalone selection. `plugin validate` on the standalone roots returned `contents: []`; that success is likewise not skill/agent discovery proof.

A real bounded terminal startup (`timeout 5s script -q -c 'claude --bare --strict-mcp-config --mcp-config …' /dev/null`, with an empty `mcpServers` map) displayed Claude `2.1.285` onboarding/theme selection and was terminated at the bound. No account setup or prompt was entered. Without a TTY, startup refused with “Input must be provided either through stdin or as a prompt argument when using --print”. We did not substitute an authenticated/model call to force evidence.

**Unsupported in this proof:** effective standalone Claude skill/agent selection, workflow invocation, selected model/effort execution, `skill://` or relative-resource reads by Claude, interactive plugin slash-command dispatch, native MCP connection and tool confinement. Filesystem materialization and offline inventory cannot prove those paths.

The offline inventory reports raw component names, not dispatched slash names. Claude's [plugin skill namespace rule](https://code.claude.com/docs/en/plugins/components#skills) documents `/<plugin>:<skill>` even when frontmatter supplies `name`; [plugin agents](https://code.claude.com/docs/en/plugins/components#agents) are scoped too. For this bundle that implies `/skills-contract-probe:start-build`, rather than the preserved unnamespaced identity. **This namespace implication is documentation-backed, not observed interactive dispatch.** OMP's actual collision-free unnamespaced results cannot be substituted for Claude proof. The approved CLI preserves current identities; no automatic namespace/caller migration follows from this comparison.

### Anonymous immutable-source smoke and retained limits

A new immutable-version acquisition observation, rather than another package-publication attempt:

```text
curl -q --fail --silent --show-error --proto '=https' --tlsv1.2 \
  --output <disposable-readme> --write-out 'HTTP %{http_code}\n' \
  https://gitlab.example.com/agents/skills/-/raw/90c046df551f5a1de7ba761b83d4a996128692e4/README.md
HTTP 200
cmp <disposable-readme> <baseline-readme>
exit 0
```

Curl config was disabled, TLS verified, and no authentication supplied. This proves anonymous acquisition of that immutable source file from this workstation, not the future executable/package download, entire repository acquisition or remote-consumer reachability. The hosting note's empty registry/unpublished package observations stand without rerunning them.

Experimental payloads and probe scripts were removed after observations; only this contract/evidence guide and its README pointer are retained. No runtime metadata changed in the repository. Parent owns the exact-candidate `npm run check` and Node 22/`npm ci` bootstrap; child gate status is `not-run — parent-owned`. No build, lint, formatter or test suite was run for this documentation/proof slice.
