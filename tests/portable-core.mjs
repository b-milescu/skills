// Focus: Real npm packing/production installation, materialized resource closure,
// foreign-CWD helper contracts and reusable-only runtime routing without network.
import assert from "node:assert/strict";
import { cpSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import yaml from "js-yaml";

const root = resolve(import.meta.dirname, "..");
const work = mkdtempSync(join(tmpdir(), "portable-core-"));
const source = join(work, "source");
const foreign = join(work, "foreign");
const skills = ["cleanup-codebase", "forge", "issue-delivery-loop", "plan-to-issues", "retro", "setup-dev-skills", "start-build", "start-review"];
const sha = "1".repeat(40);
function run(command, args, cwd = foreign) {
  return spawnSync(command, args, { cwd, encoding: "utf8", env: { ...process.env, HOME: join(work, "home"), npm_config_userconfig: join(work, "empty.npmrc"), npm_config_cache: join(work, "cache"), NODE_PATH: "" } });
}
function pass(result) {
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout;
}
function pack(path, scripts = false) {
  const args = ["pack", path, "--json", "--pack-destination", work];
  if (!scripts) args.push("--ignore-scripts");
  return join(work, JSON.parse(pass(run("npm", args)))[0].filename);
}
function files(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap((entry) => {
    const file = join(path, entry.name);
    assert.equal(lstatSync(file).isSymbolicLink(), false, `escaping alias: ${file}`);
    return entry.isDirectory() ? files(file) : [file];
  });
}
try {
  mkdirSync(source); mkdirSync(foreign); mkdirSync(join(work, "home"));
  writeFileSync(join(work, "empty.npmrc"), "");
  for (const path of [...skills, "docs", "templates", "agents", "README.md", "CONTEXT.md", "package.json", "scripts/pack-core.mjs"]) {
    cpSync(join(root, path), join(source, path), { recursive: true });
  }
  // Git without symlinks must produce the same usable resource directories.
  for (const skill of skills) {
    for (const [alias, target] of [["docs", "../docs"], ["shared-templates", "../templates"]]) {
      rmSync(join(source, skill, alias), { recursive: true, force: true });
      writeFileSync(join(source, skill, alias), `${target}\n`);
    }
  }
  const tarball = pack(source, true);
  // Package dependencies from the bootstrapped checkout into a disposable cache;
  // never borrow its node_modules while executing installed helpers.
  const dependencies = Object.fromEntries(["argparse", "js-yaml"].map((name) => [name, `file:${pack(join(root, "node_modules", name))}`]));
  writeFileSync(join(foreign, "package.json"), JSON.stringify({ private: true, overrides: dependencies }));
  pass(run("npm", ["install", "--offline", "--ignore-scripts", "--omit=dev", "--no-audit", "--no-fund", tarball]));
  const installed = join(foreign, "node_modules/@agents/skills");
  const core = join(installed, "core");
  assert.deepEqual(readdirSync(core).filter((name) => existsSync(join(core, name, "SKILL.md"))).sort(), skills);
  assert.equal(existsSync(join(installed, ".claude")), false);
  assert.equal(existsSync(join(installed, ".omp")), false);
  assert.equal(existsSync(join(core, ".claude")), false);
  assert.equal(existsSync(join(core, ".omp")), false);
  for (const dialect of ["claude", "omp"]) {
    assert.deepEqual(readdirSync(join(core, "agents", dialect)).sort(), ["mr-builder.md", "mr-reviewer-final.md"]);
    for (const route of ["mr-builder", "mr-reviewer-final"]) {
      const document = readFileSync(join(core, "agents", dialect, `${route}.md`), "utf8");
      const metadata = yaml.load(document.split("---")[1]);
      assert.equal(metadata.name, route);
      assert.deepEqual(metadata[dialect === "omp" ? "autoload-skills" : "skills"], [route === "mr-builder" ? "start-build" : "start-review", "forge"]);
    }
  }
  const setup = readFileSync(join(core, "setup-dev-skills/SKILL.md"), "utf8");
  assert.equal(yaml.load(setup.split("---")[1])["disable-model-invocation"], true);
  for (const skill of skills) {
    assert.equal(lstatSync(join(core, skill, "docs")).isDirectory(), true);
    assert.equal(lstatSync(join(core, skill, "shared-templates")).isDirectory(), true);
    for (const file of files(join(core, skill)).filter((file) => file.endsWith(".md"))) {
      for (const match of readFileSync(file, "utf8").matchAll(/skill:\/\/([a-z][a-z0-9-]*)(?:\/([a-zA-Z0-9_./-]+))?/g)) {
        if (!skills.includes(match[1])) continue; // Optional external specialists are not core payload dependencies.
        const resource = join(core, match[1], match[2] || "SKILL.md");
        assert.ok(existsSync(resource), `missing declared core resource ${resource} in ${file}`);
      }
    }
  }
  const gate = join(core, "start-build/scripts/validate-gate-receipt.mjs");
  assert.ok(createRequire(gate).resolve("js-yaml").startsWith(join(foreign, "node_modules")));
  const receipt = join(work, "receipt.yml");
  const gateArgs = [gate, "--owner", "builder", "--mode", "pre-post", "--receipt", receipt, "--reviewed-commit", sha, "--gate-command", "npm run check"];
  const body = { gate_receipt: { kind: "gate-receipt", version: "1", owner: "builder", checkout_commit: sha, command: "npm run check", result: "PASS" } };
  writeFileSync(receipt, yaml.dump(body));
  pass(run(process.execPath, gateArgs));
  body.gate_receipt.checkout_commit = "2".repeat(40);
  writeFileSync(receipt, yaml.dump(body));
  const stale = run(process.execPath, gateArgs);
  assert.notEqual(stale.status, 0); assert.match(stale.stderr, /commit/);
  const finding = join(core, "start-review/scripts/validate-finding-bindings.mjs");
  const fixtures = join(root, "tests/fixtures/finding-identities");
  const reports = ["report-round-1.md", "report-round-2.md"].flatMap((name) => ["--report", join(fixtures, name)]);
  assert.match(pass(run(process.execPath, [finding, ...reports, "--packet", join(fixtures, "revision-valid.md")])), /reports=2 identities=2 artifacts=1/);
  const invalidFinding = run(process.execPath, [finding, ...reports, "--packet", join(fixtures, "revision-stale-sha.md")]);
  assert.equal(invalidFinding.status, 2); assert.match(invalidFinding.stderr, /stale finding binding/);
  const text = join(core, "forge/scripts/validate-text.mjs");
  const envelope = join(work, "envelope.json");
  writeFileSync(envelope, JSON.stringify({ role: "note", content: "café 日本語 😀\n" }));
  pass(run(process.execPath, [text, "--input", envelope]));
  writeFileSync(envelope, JSON.stringify({ role: "note", content: "PRIVATE\u0000" }));
  const invalidText = run(process.execPath, [text, "--input", envelope]);
  assert.notEqual(invalidText.status, 0);
  assert.deepEqual(JSON.parse(invalidText.stderr), { role: "note", offset: 7, type: "control" });
  assert.equal(invalidText.stdout, "");
  assert.ok(!invalidText.stderr.includes("PRIVATE"));
  console.log("portable-core: PASS (production npm install; foreign-CWD resources and valid/invalid helpers)");
} finally {
  rmSync(work, { recursive: true, force: true });
}
