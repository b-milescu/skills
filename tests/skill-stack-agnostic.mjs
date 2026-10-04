// Focus: the shipped skill stack (the 8 skill directories, templates/ and
// reference/) names no code host, agent harness, model or skill outside this
// plugin and carries no machine-specific path; every repo .mjs imports only
// node: builtins or relative paths. All hits are reported together as path:line.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { lstatSync, readFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";

const root = path.dirname(import.meta.dirname);
const SKILLS = ["setup-dev-skills", "forge", "start-build", "start-review", "issue-delivery-loop", "plan-to-issues", "cleanup-codebase", "retro"];
const STACK = [...SKILLS, "templates", "reference"];
const VENDORED = "start-build/scripts/vendor/";

// [name, pattern, example it must match, benign examples it must not match].
// The `gitlab#` breadcrumb is covered by the code-host rule.
const RULES = [
  ["harness name", /\b(?:Claude|OMP|Codex|Cursor|Copilot)\b/, "Claude Code"],
  ["harness name", /oh-my-pi/i, "Oh-My-Pi"],
  ["internal URI", /\b(?:skill|local|agent|xd|artifact|history|mcp):\/\//, "skill://forge/SKILL.md", ["https://example.org"]],
  ["plugin-root variable", /\$\{CLAUDE_/, "${CLAUDE_PLUGIN_ROOT}"],
  ["MCP tool id", /\bmcp__/, "mcp__server__tool"],
  ["harness config path", /\.claude\/|\.omp\/|CLAUDE\.md|AGENTS\.md/, ".claude/agents/x.md"],
  ["harness tool id", /\b(?:TodoWrite|AskUserQuestion|ListAgents|SendMessage)\b/, "TodoWrite"],
  ["harness tool call", /subagent\(/, "subagent(task)"],
  ["harness tool name", /`(?:irc|hub|todo|Task|Agent|Skill)`/, "`Skill`", ["a task", "`task-list`"]],
  // Wider than the bare model names on purpose: `gpt-55` and `gpt-4o` are model ids too.
  ["model id", /\b(?:opus|sonnet|haiku|gemini)\b|\bgpt-[0-9]/i, "Sonnet"],
  ["code host", /\b(?:github|gitlab|bitbucket|gitea|forgejo)\b/i, "GitHub"],
  ["code-host CLI", /`(?:gh|glab) |^\s*(?:gh|glab) /, "`gh pr view`"],
  ["change-request noun", /\b(?:MRs?|PRs?|IID)\b/, "the MR", ["PRIVATE", "a change request"]],
  ["change-request noun", /\b(?:merge|pull) requests?\b/i, "Pull Request"],
  ["bang reference", /(?<![\w/])![0-9]+\b/, "see !193", ["urgent!2", "!important"]],
  ["outside skill", /\b(?:ponytail|mempalace|no-mistakes|caveman|graphify|mattpocock|grill-with-docs|diagnosing-bugs|improve-codebase-architecture|writing-great-skills|security-review|code-review)\b/i, "Ponytail", ["start-review"]],
  ["outside skill", /`simplify`/, "`simplify`"],
  ["slash invocation", new RegExp(`(?:^|[\\s(\`])/(?:${SKILLS.join("|")})\\b`), "run /forge", ["../forge/SKILL.md", "owner/retro"]],
  ["absolute user path", /\/Users\/|\/home\/[a-z]|~\/\.(?:claude|omp|agents)/, "~/.claude/skills"],
];
const GLOBAL_RULES = RULES.map(([name, re]) => [name, new RegExp(re.source, `${re.flags}g`)]);

// The only platform-noun exceptions: the gate-receipt validator accepts provider nouns as
// aliases of `single change request`, and the schema line documents that alias.
const ALLOWED = [
  { file: "start-build/scripts/validate-gate-receipt.mjs", text: "/^single (?:MR|PR|change request)$/" },
  { file: "start-build/templates/reviewer-lift-schema.md", text: "`single MR`/`single PR`" },
];

const SPECIFIER = /(?:\bfrom\s*|\bimport\s*\(?\s*|\brequire\s*\(\s*)(["'])([^"'\n]+)\1/g;
const isLocal = (specifier) => /^(?:node:|\.\.?\/)/.test(specifier);

const git = (...args) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8", maxBuffer: 1 << 28 }).split("\0").filter(Boolean);

// Tracked entries carry their index mode (120000 = symlink, never followed). Untracked,
// non-ignored files are scanned too, so a new file is checked before it is committed.
function repoTextFiles() {
  const tracked = git("ls-files", "-s", "-z").map((entry) => [entry.slice(entry.indexOf("\t") + 1), entry.startsWith("120000")]);
  const untracked = git("ls-files", "-z", "--others", "--exclude-standard").map((file) => [file, lstatSync(path.join(root, file)).isSymbolicLink()]);
  const files = [];
  for (const [file, symlink] of [...tracked, ...untracked]) {
    if (symlink) continue;
    let bytes;
    try { bytes = readFileSync(path.join(root, file)); } catch (error) { if (error.code === "ENOENT") continue; throw error; }
    if (!bytes.includes(0)) files.push([file, bytes.toString("utf8")]);
  }
  return files;
}

function findHits(file, text) {
  const allowed = ALLOWED.filter((entry) => entry.file === file);
  const hits = [];
  text.split(/\r?\n/).forEach((line, index) => {
    const spans = [];
    for (const { text: needle } of allowed) for (let at = line.indexOf(needle); at >= 0; at = line.indexOf(needle, at + needle.length)) spans.push([at, at + needle.length]);
    for (const [name, re] of GLOBAL_RULES) {
      for (const match of line.matchAll(re)) {
        if (spans.some(([from, to]) => match.index >= from && match.index + match[0].length <= to)) continue;
        hits.push(`${file}:${index + 1}: ${name}: ${match[0].trim()}`);
      }
    }
  });
  return hits;
}

// [line, specifier] for every import/require target that is neither node: nor relative.
const foreignSpecifiers = (text) => [...text.matchAll(SPECIFIER)]
  .filter((match) => !isLocal(match[2]))
  .map((match) => [text.slice(0, match.index).split("\n").length, match[2]]);

const files = repoTextFiles();

test("skill stack names no code host, harness, model, outside skill or machine path", () => {
  const hits = files
    .filter(([file]) => STACK.some((dir) => file.startsWith(`${dir}/`)) && !file.startsWith(VENDORED))
    .flatMap(([file, text]) => findHits(file, text));
  assert.equal(hits.length, 0, `${hits.length} coupling hit(s) in the skill stack:\n${hits.join("\n")}`);
});

test("every .mjs imports only node: builtins and relative paths", () => {
  const hits = files
    .filter(([file]) => file.endsWith(".mjs") && !file.startsWith(VENDORED) && !file.startsWith("node_modules/"))
    .flatMap(([file, text]) => foreignSpecifiers(text).map(([line, specifier]) => `${file}:${line}: ${specifier} (only node: builtins and relative paths are allowed)`));
  assert.equal(hits.length, 0, `${hits.length} external specifier(s):\n${hits.join("\n")}`);
});

test("scanner rules match their own examples and the allowlist stays path- and span-scoped", () => {
  for (const [name, re, bad, ok = []] of RULES) {
    assert.match(bad, re, `${name} must match ${bad}`);
    for (const text of ok) assert.doesNotMatch(text, re, `${name} must not match ${text}`);
  }
  const [{ file, text }] = ALLOWED;
  assert.deepEqual(findHits(file, `x ${text} y`), [], "allowlisted span is skipped");
  assert.equal(findHits(file, `x ${text} on GitHub`).length, 1, "other hits on an allowlisted line still count");
  assert.ok(findHits("start-build/SKILL.md", `x ${text}`).length > 0, "allowlist is scoped to its path");
  const sample = [
    "import a from \"node:fs\";", "import b from \"./b.mjs\";", "import c from \"left-pad\";", "import \"side-effect\";",
    "const d = require(\"fs\");", "const e = await import(\"pkg/sub\");", "export { f } from \"../g.mjs\";",
    "import {", "  h,", "} from \"yaml\";",
  ].join("\n");
  assert.deepEqual(foreignSpecifiers(sample).map(([, specifier]) => specifier), ["left-pad", "side-effect", "fs", "pkg/sub", "yaml"]);
});
