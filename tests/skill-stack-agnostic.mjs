// Focus: the shipped skill stack (the 8 skill directories, templates/ and
// reference/) names no code host, agent harness, model or skill outside this
// plugin, invokes no Node toolchain (Bun is its one declared runtime), carries no
// machine-specific path or binary (NUL-byte) file and symlinks only into itself
// with relative targets; every repo .mjs imports only node: builtins or relative
// paths. The scan walks the file system, not git, so it also runs in an installed
// copy. A plain node:assert/strict script: every check runs, all hits are
// reported together as path:line, and any failure exits non-zero.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, readlinkSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const root = path.dirname(import.meta.dirname);
const SKILLS = ["setup-dev-skills", "forge", "start-build", "start-review", "issue-delivery-loop", "plan-to-issues", "cleanup-codebase", "retro"];
const STACK = [...SKILLS, "templates", "reference"];
const SKILL = SKILLS.join("|");
const VENDORED = "start-build/scripts/vendor";
const SKIPPED = new Set([".git", "node_modules"]);

// [name, pattern, examples it must match, benign examples it must not match]. Patterns run
// over the whole file text, so a [\s_-]+ separator also catches a phrase wrapped across lines.
// The `gitlab#` breadcrumb is covered by the code-host rule.
const RULES = [
  ["harness name", /\b(?:claude(?:code)?|omp|codex|cursor|copilot)s?\b|\b(?:claude|omp)_/i, ["Claude Code", "claude code", "claude plugin install skills@skills", "omp plugin install skills@skills", "OMPs", "ClaudeCode", "claude-code", "claude_code", "Claude_Code", "claude_plugin_root", "omp_agent_dir"], ["compile", "cursory", "comp_x", "claudette"]],
  ["harness name", /\boh[\s_-]?my[\s_-]?pi\b|\bpi-coding-agent\b/i, ["Oh-My-Pi", "oh my pi", "ohmypi", "oh_my_pi", "Oh\nMy\nPi", "pi-coding-agent", "@oh-my-pi/pi-coding-agent"], ["ohm pi", "pie-coding-agents"]],
  ["internal URI", /\b(?:skill|local|agent|xd|artifact|history|mcp):\/\//, ["skill://forge/SKILL.md"], ["https://example.org"]],
  ["harness env variable", /\$?\{?(?:CLAUDE|OMP)_[A-Z_]+/, ["${CLAUDE_PLUGIN_ROOT}", "$CLAUDE_PLUGIN_ROOT/forge/SKILL.md", "CLAUDE_CODE_SUBAGENT_MODEL", "${OMP_AGENT_DIR}", "$OMP_PLUGIN_ROOT/forge", "OMP_REQUIRE_LOADER"], ["OMPLIB"]],
  ["MCP tool id", /\bmcp__/, ["mcp__server__tool"]],
  ["harness config path", /\.claude(?:-plugin)?\b|\.omp(?:-plugin)?\b|CLAUDE\.md|AGENTS\.md/, [".claude/agents/x.md", ".claude-plugin/plugin.json", ".omp-plugin", ".omp/agents"]],
  ["harness skill namespace", new RegExp(`\\bskills?:(?:${SKILL})\\b`), ["skills:start-build", "skill:retro"]],
  ["harness frontmatter key", /\bautoload-skills\b/, ["autoload-skills: start-build, forge"]],
  ["harness runtime key", /worktree:\s*true|isolation:\s*worktree|thinking-level|model:\s*inherit|subagent_type/, ["worktree: true", "isolation: worktree", "thinking-level", "model: inherit", "subagent_type"]],
  ["harness tool id", /\b(?:TodoWrite|AskUserQuestion|ListAgents|SendMessage|TaskCreate|TaskList|TaskGet|TaskUpdate)\b/, ["TodoWrite", "TaskCreate", "TaskList", "TaskGet", "TaskUpdate"]],
  ["harness tool call", /subagent\(/, ["subagent(task)"]],
  ["harness tool prose", /\bthe (?:Read|Bash|Edit|Write|Grep|Glob|Agent|Skill) tool\b/i, ["the Read tool", "the Bash tool"], ["the tool"]],
  ["harness tool name", /`(?:Bash|Read|Edit|Write|Glob|Grep|Agent|Skill|Task|task|read|bash|edit|write|grep|glob|ask|todo|hub|irc)`/, ["`Skill`", "`Bash`", "`task`", "`read`", "`bash`", "`todo`", "`hub`", "`irc`"], ["a task", "`task-list`"]],
  // Wider than the bare model names on purpose: `gpt-55`, `gpt5` and `claude-fable-5` are model ids too.
  ["model id", /\b(?:opus|sonnet|haiku|gemini|fable|anthropic|openai|grok|llama|mistral|deepseek|qwen)\b|\bgpt[- ]?[0-9]|\bclaude-[a-z]+-[0-9]|\bo[1-9]\b/i, ["Sonnet", "fable", "claude-fable-5", "Anthropic", "OpenAI", "gpt5", "GPT 5", "gpt-4o", "o3", "Grok", "Llama", "Mistral", "DeepSeek", "Qwen"]],
  ["code host", /\b(?:github|gitlab|bitbucket|gitea|forgejo)\b/i, ["GitHub"]],
  ["code-host CLI", /`(?:gh|glab) |^[ \t]*(?:gh|glab) /m, ["`gh pr view`", "text\n  gh pr view"]],
  ["change-request noun", /\b(?:MRs?|PRs?|IID)\b/, ["the MR"], ["PRIVATE", "a change request"]],
  ["change-request noun", /\b(?:merge|pull)[\s_-]+requests?\b/i, ["Pull Request", "pull-request", "merge_request", "merge-request", "merge\nrequest"]],
  ["bang reference", /(?<![\w/])![0-9]+\b/, ["see !193"], ["urgent!2", "!important"]],
  ["outside skill", /\b(?:ponytail|mempalace|no-mistakes|caveman|graphify|mattpocock|grill-with-docs|diagnosing-bugs|improve-codebase-architecture|writing-great-skills|security-review|code-review|codebase-memory|superpowers|hindsight)\b/i, ["Ponytail", "codebase-memory", "superpowers", "hindsight"], ["start-review"]],
  ["outside skill", /`simplify`|\bsimplify skill\b|\btdd[\s-]+skill\b|\/(?:simplify|verify)\b/i, ["`simplify`", "simplify skill", "tdd skill", "TDD-skill", "/simplify", "/verify"], ["the `tdd` field", "tdd:", "| tdd | RED/GREEN |"]],
  ["slash invocation", new RegExp(`(?<![\\w./-])/(?:skills?:)?(?:${SKILL})\\b`), ["run /forge", "Run **/forge preflight** first", "Run \"/retro\" after the batch", "[/plan-to-issues](x)", "/skills:forge", "/skill:retro"], ["../forge/SKILL.md", "owner/retro"]],
  ["absolute user path", /\/Users\/|\/home\/[a-z]|~\/\.(?:claude|omp|agents)/, ["~/.claude/skills"]],
  // Bun is the stack's one declared runtime: no node invocation (flag, script path with or
  // without an extension, shell/template variable), no other Node package or version manager,
  // /bin/node path, "node" manifest key, node@N pin or Node.js version requirement.
  // `node:` imports and `node_modules` stay legal.
  ["Node toolchain", /\bnode\s+(?:-{1,2}\w|-\s*<<|[<./~${"']|[\w./-]+\.[cm]?[jt]s\b|[\w.-]+\/[\w./-]*)|\benv\s+node\b|\b(?:npm|npx|nvm|pnpm|yarn|corepack|fnm|volta)(?:rc)?\b|\bnode\.?js\b|\bnode(?:\s+v?|\s*(?:>=?|≥|[~^])\s*v?)\d|\/bin\/node\b|["']node["']\s*:|\bnode@\d[\w.]*/i, ["node scripts/x.mjs", "node --test", "node -e 1", "node <dir>/x.mjs", "node ./x", "node - <<'JS'", "node\n  x.js", "#!/usr/bin/env node", "npx foo", "npm run check", "nvm use 22", ".nvmrc", "Node.js 22", "nodejs", "Node 22.x", "Node >=22", "node v22", "pnpm install", "yarn add x", "corepack enable", "fnm use 22", "volta install node", ".yarnrc", "/usr/bin/node x", "#!/usr/local/bin/node", "{\"engines\":{\"node\":\">=22\"}}", "'node': '22'", "node@22", "node {{skill_dir}}/x.mjs", "node ${SKILL_DIR}/x.mjs", "node scripts/x", "node forge/scripts/validate-text"], ["import fs from 'node:fs'", "graph node", "node_modules", "node_modules/.bin/x", "the leaf node, then", "node - the root", "node-based", "a tree node and its parent", "node/edge pairs", "{\"nodes\": 3}"]],
];
const GLOBAL_RULES = RULES.map(([name, re]) => [name, new RegExp(re.source, `${re.flags}g`)]);

// Contract tokens the stack keeps on purpose: no rule may flag them.
const KEPT = [
  "Roles: `title`, `description`, `note`, `review-packet`", "post-note receipt/Lift validation", "Durable note id", "CI pipeline",
  "Change-request locator", "Report locator", "| tdd | RED/GREEN commands and outcomes |", "tdd:\n  red: targeted test failed",
  "[forge](../forge/SKILL.md) and owner/retro",
];

// The only platform-noun exceptions: the gate-receipt validator accepts provider nouns as
// aliases of `single change request`, and the schema line documents that alias.
const ALLOWED = [
  { file: "start-build/scripts/validate-gate-receipt.mjs", text: "/^single (?:MR|PR|change request)$/" },
  { file: "start-build/templates/reviewer-lift-schema.md", text: "`single MR`/`single PR`" },
];

const SPECIFIER = /(?:\bfrom\s*|\bimport\s*\(?\s*|\brequire\s*(?:\.resolve\s*)?\(\s*)(["'`])([^"'`\n]+)\1/g;
// The require factory resolves packages at run time. Never spelled out in this file (it is itself scanned).
const FACTORY = "create\u0052equire";
const REQUIRE_FACTORY = new RegExp(`\\b${FACTORY}\\b`, "g");
const isLocal = (specifier) => /^(?:node:|\.\.?\/)/.test(specifier);
const lineAt = (text, offset) => text.slice(0, offset).split("\n").length;
const inStack = (file) => STACK.some((dir) => file === dir || file.startsWith(`${dir}/`));

// Walks rootDir without git. Entries are read as directory entries (an lstat view): symlinks
// are listed, never followed, so content is scanned once, at its source. A file holding a NUL
// byte (binary, or UTF-16 text) cannot be scanned as text, so it is listed, never skipped.
function walk(rootDir) {
  const texts = [];
  const links = [];
  const binaries = [];
  const visit = (dir, prefix) => {
    for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const file = prefix + entry.name;
      if (SKIPPED.has(entry.name) || file === VENDORED) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) visit(full, `${file}/`);
      else if (entry.isSymbolicLink()) links.push(file);
      else if (entry.isFile()) {
        const bytes = readFileSync(full);
        if (bytes.includes(0)) binaries.push(file);
        else texts.push([file, bytes.toString("utf8")]);
      }
    }
  };
  visit(rootDir, "");
  return { texts, links, binaries };
}

// A symlink inside the stack must be relative and resolve to a path inside the stack. An
// absolute target is machine-specific wherever it resolves; any other target outside the
// stack ships a repo directory (docs/, ...) whose content the stack scan never reads.
function linkHits(rootDir, links) {
  const realRoot = realpathSync(rootDir);
  const inside = STACK.map((dir) => path.join(realRoot, dir));
  return links.filter(inStack).flatMap((link) => {
    const target = readlinkSync(path.join(rootDir, link));
    if (path.win32.isAbsolute(target)) return [`${link}: absolute symlink target (${target})`];
    let real;
    try { real = realpathSync(path.join(rootDir, link)); } catch (error) { return [`${link}: symlink does not resolve (${error.code})`]; }
    if (inside.some((dir) => real === dir || real.startsWith(dir + path.sep))) return [];
    return [`${link}: symlink resolves outside the skill stack (${path.relative(realRoot, real)})`];
  });
}

function findHits(file, text) {
  const spans = [];
  for (const entry of ALLOWED) {
    if (entry.file !== file) continue;
    for (let at = text.indexOf(entry.text); at >= 0; at = text.indexOf(entry.text, at + entry.text.length)) spans.push([at, at + entry.text.length]);
  }
  const hits = [];
  for (const [name, re] of GLOBAL_RULES) {
    for (const match of text.matchAll(re)) {
      if (spans.some(([from, to]) => match.index >= from && match.index + match[0].length <= to)) continue;
      hits.push([match.index, `${file}:${lineAt(text, match.index)}: ${name}: ${match[0].replace(/\s+/g, " ").trim()}`]);
    }
  }
  return hits.sort((a, b) => a[0] - b[0]).map(([, hit]) => hit);
}

const stackHits = (rootDir, { texts, links, binaries }) => [
  ...texts.filter(([file]) => inStack(file)).flatMap(([file, text]) => findHits(file, text)),
  ...binaries.filter(inStack).map((file) => `${file}: binary file in skill stack (NUL byte: its text cannot be scanned)`),
  ...linkHits(rootDir, links),
];

// [line, finding] for every loader form that is neither a node: nor a relative specifier.
const importHits = (text) => [
  ...[...text.matchAll(SPECIFIER)].filter((match) => !isLocal(match[2])).map((match) => [lineAt(text, match.index), `${match[2]} (only node: builtins and relative paths are allowed)`]),
  ...[...text.matchAll(REQUIRE_FACTORY)].map((match) => [lineAt(text, match.index), `${match[0]} (only node: builtins and relative paths are allowed)`]),
].sort((a, b) => a[0] - b[0]);

// A NUL byte in a .mjs would exempt the whole file from the loader scan, so it is a hit too.
const loaderHits = ({ texts, binaries }) => [
  ...binaries.filter((file) => file.endsWith(".mjs")).map((file) => `${file}: NUL byte in .mjs (its loader forms cannot be scanned)`),
  ...texts.filter(([file]) => file.endsWith(".mjs")).flatMap(([file, text]) => importHits(text).map(([line, finding]) => `${file}:${line}: ${finding}`)),
];

// Every check runs even after one fails; failures are listed together and set a non-zero exit.
const failures = [];
function check(name, run) {
  try {
    run();
    console.log(`ok   ${name}`);
  } catch (error) {
    failures.push(name);
    const detail = error instanceof assert.AssertionError ? error.message : error?.stack ?? String(error);
    console.log(`FAIL ${name}\n${detail.replace(/^/gm, "     ")}`);
  }
}

const scanned = walk(root);

check("skill stack names no code host, harness, model, outside skill or machine path, ships no binary file and links only into itself", () => {
  const hits = stackHits(root, scanned);
  assert.ok(!hits.length, `${hits.length} coupling hit(s) in the skill stack:\n${hits.join("\n")}`);
});

check("every .mjs imports only node: builtins and relative paths", () => {
  const hits = loaderHits(scanned);
  assert.ok(!hits.length, `${hits.length} external loader form(s):\n${hits.join("\n")}`);
});

check("scanner rules match their probes, spare benign text and kept contract tokens, and the allowlist stays path- and span-scoped", () => {
  for (const [name, re, bad, ok = []] of RULES) {
    for (const text of bad) assert.match(text, re, `${name} must match ${JSON.stringify(text)}`);
    for (const text of ok) assert.doesNotMatch(text, re, `${name} must not match ${JSON.stringify(text)}`);
  }
  for (const text of KEPT) assert.deepEqual(findHits("forge/SKILL.md", text), [], `kept token flagged: ${JSON.stringify(text)}`);
  assert.deepEqual(findHits("forge/SKILL.md", "x\nmerge\nrequest"), ["forge/SKILL.md:2: change-request noun: merge request"], "a wrapped phrase is reported at its first line");
  for (const { file, text } of ALLOWED) assert.deepEqual(findHits(file, `x ${text} y`), [], "allowlisted span is skipped");
  const [{ file, text }] = ALLOWED;
  assert.equal(findHits(file, `x ${text} on GitHub`).length, 1, "other hits on an allowlisted line still count");
  assert.ok(findHits("start-build/SKILL.md", `x ${text}`).length > 0, "allowlist is scoped to its path");
});

check("loader scan flags every non-node:, non-relative form", () => {
  const sample = [
    "import a from \"node:fs\";", "import b from \"./b.mjs\";", "import c from \"left-pad\";", "import \"side-effect\";",
    "const d = require(\"fs\");", "const e = await import(\"pkg/sub\");", "export { f } from \"../g.mjs\";",
    "import {", "  h,", "} from \"yaml\";",
    "const i = require.resolve(\"yaml\");", "const j = require.resolve(\"./k.cjs\");",
    "const l = await import(\u0060js-yaml\u0060);", "const m = await import(\u0060./n.mjs\u0060);",
    `import { ${FACTORY} } from \"node:module\";`,
  ].join("\n");
  assert.deepEqual(importHits(sample).map(([, finding]) => finding.split(" ")[0]), ["left-pad", "side-effect", "fs", "pkg/sub", "yaml", "yaml", "js-yaml", FACTORY]);
});

check("the walk skips .git, node_modules and vendored code; stack symlinks must be relative and resolve inside the stack; NUL-byte files are hits", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "skill-stack-"));
  const put = (file, body) => { mkdirSync(path.dirname(path.join(dir, file)), { recursive: true }); writeFileSync(path.join(dir, file), body); };
  const link = (file, target) => { mkdirSync(path.dirname(path.join(dir, file)), { recursive: true }); symlinkSync(target, path.join(dir, file)); };
  try {
    put("docs/agents/x.md", "GitHub"); // outside the stack: only a link into it can ship this
    put("docs/logo.bin", "a\0b"); // outside the stack: a binary there is no stack hit
    put("templates/adr.md", "clean");
    put("forge/note.md", "GitHub");
    put("forge/blob.bin", "a\0b");
    put("tools/x.mjs", "// \0\nimport a from \"left-pad\";"); // a NUL hides the whole file from the loader scan
    for (const skipped of [".git/HEAD", "node_modules/p/i.md", "forge/node_modules/p/i.md", `${VENDORED}/y.mjs`]) put(skipped, "GitHub");
    put(`${VENDORED}/blob.bin`, "a\0b"); // the vendor exclusion also covers binaries
    link("forge/docs", "../docs"); // the regression: a skill shipping the repo docs
    link("forge/gone", "../nowhere");
    link("retro/x.md", "../docs/agents/x.md");
    link("forge/abs-in", path.join(dir, "templates/adr.md")); // absolute: a hit even though it resolves inside the stack
    link("retro/abs-out", path.join(dir, "docs/agents/x.md")); // absolute and outside the stack
    link("forge/shared-templates", "../templates"); // allowed: stays inside the stack
    link("forge/adr.md", "../templates/adr.md"); // allowed
    const walked = walk(dir);
    assert.deepEqual(walked.texts.map(([file]) => file), ["docs/agents/x.md", "forge/note.md", "templates/adr.md"], "no .git, no node_modules, no vendor, no followed symlink, no NUL-byte file");
    assert.deepEqual(walked.binaries, ["docs/logo.bin", "forge/blob.bin", "tools/x.mjs"], "NUL-byte files are listed, vendored ones are not");
    assert.deepEqual(walked.links, ["forge/abs-in", "forge/adr.md", "forge/docs", "forge/gone", "forge/shared-templates", "retro/abs-out", "retro/x.md"]);
    const hits = stackHits(dir, walked);
    assert.deepEqual(hits.map((hit) => hit.split(":")[0]).sort(), ["forge/abs-in", "forge/blob.bin", "forge/docs", "forge/gone", "forge/note.md", "retro/abs-out", "retro/x.md"]);
    for (const [file, reason] of [["forge/abs-in", "absolute symlink target"], ["retro/abs-out", "absolute symlink target"], ["forge/blob.bin", "binary file in skill stack"], ["forge/docs", "symlink resolves outside the skill stack"], ["forge/gone", "symlink does not resolve"]]) {
      assert.ok(hits.some((hit) => hit.startsWith(`${file}: ${reason}`)), `${file} must be reported as: ${reason}`);
    }
    assert.deepEqual(loaderHits(walked), ["tools/x.mjs: NUL byte in .mjs (its loader forms cannot be scanned)"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

if (failures.length) {
  console.error(`\nskill-stack-agnostic: FAIL - ${failures.length} failing check(s)`);
  process.exitCode = 1;
} else console.log("skill-stack-agnostic: PASS");
