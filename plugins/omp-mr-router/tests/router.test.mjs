import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import registerExtension from "../src/extension.mjs";
import { parseRouteArgs, ROUTING_POLICY, selectRoute } from "../src/router.mjs";

const PLUGIN_ROOT = dirname(dirname(fileURLToPath(import.meta.url)));

function selectedAgent(route, role) {
  return route.selectedRoutes.find((entry) => entry.role === role)?.selected_agent;
}

test("manifest exposes the OMP extension entry", () => {
  const manifest = JSON.parse(readFileSync(join(PLUGIN_ROOT, "package.json"), "utf8"));
  assert.deepEqual(manifest.omp.extensions, ["src/extension.mjs"]);
  assert.deepEqual(manifest.pi.extensions, ["src/extension.mjs"]);
  assert.deepEqual(manifest.omp.agents, ["agents/pi"]);
});

test("/mr-route and /mr-deliver commands are registered", async () => {
  const commands = new Map();
  const sent = [];
  const events = [];
  const pi = {
    registerCommand(name, definition) {
      commands.set(name, definition);
    },
    sendMessage(message) {
      sent.push(message);
    },
    events: {
      emit(name, payload) {
        events.push({ name, payload });
      },
    },
  };

  registerExtension(pi);

  assert.deepEqual([...commands.keys()].sort(), ["mr-deliver", "mr-route"]);
  await commands.get("mr-route").handler("Add README wording. Acceptance criteria: route prints metadata.", { ui: { notify() {} } });
  await commands.get("mr-deliver").handler("Fix auth token handling", { ui: { notify() {} } });

  assert.equal(sent.length, 2);
  assert.match(sent[0].content, /mr-builder-opus48/u);
  assert.match(sent[0].content, /mr-reviewer-gpt55-xhigh/u);
  assert.match(sent[1].content, /MR delivery instruction/u);
  assert.equal(events[0].name, "omp-mr-router:route");
  assert.equal(events[1].name, "omp-mr-router:deliver");
});

test("normal builder route uses Opus 4.8 medium", () => {
  const route = selectRoute({ summary: "Add README wording. Acceptance criteria: route output includes metadata." });

  assert.equal(route.highRisk, false);
  assert.equal(selectedAgent(route, "builder"), ROUTING_POLICY.builder.agent);
  assert.equal(route.selectedRoutes[0].model, "anthropic/claude-opus-4-8");
  assert.equal(route.selectedRoutes[0].thinking, "medium");
  assert.equal(route.selectedRoutes[0].verbosity, "high");
});

for (const [name, summary] of [
  ["security/auth", "Change JWT token validation and session secret handling. Acceptance criteria: invalid tokens fail closed."],
  ["migration/schema", "Add database migration with schema backfill and rollback notes."],
  ["runtime/deploy", "Change production worker runtime deployment and CI rollout behavior."],
  ["concurrency", "Fix race condition in lease locking state machine."],
  ["permissions/billing", "Update billing permissions and tenant quota policy."],
  ["unclear criteria", "Acceptance criteria TBD; ambiguous scope and unknown definition of done."],
]) {
  test(`high-risk classifier covers ${name}`, () => {
    const route = selectRoute({ summary });

    assert.equal(route.highRisk, true);
    assert.equal(selectedAgent(route, "builder_high_risk"), ROUTING_POLICY.builder_high_risk.agent);
    assert.match(route.highRiskRationale.join("\n"), /auth|migration|deploy|concurrency|permissions|unclear|schema|billing|runtime|locking|criteria/iu);
  });
}

test("large diff and many files trigger high-risk builder route", () => {
  const manyFiles = selectRoute({ summary: "Refactor view components. Acceptance criteria: UI still renders.", filesChanged: 20 });
  const manyLines = selectRoute({ summary: "Refactor view components. Acceptance criteria: UI still renders.", diffLines: 1000 });

  assert.equal(manyFiles.highRisk, true);
  assert.equal(selectedAgent(manyFiles, "builder_high_risk"), ROUTING_POLICY.builder_high_risk.agent);
  assert.match(manyFiles.highRiskRationale.join("\n"), /filesChanged 20 >= 20/u);
  assert.equal(manyLines.highRisk, true);
  assert.match(manyLines.highRiskRationale.join("\n"), /diffLines 1000 >= 1000/u);
});

test("final reviewer defaults to GPT-5.5 xhigh and fallback requires explicit provider-failure flag", () => {
  const normal = selectRoute({ summary: "Add docs. Acceptance criteria: output is stable." });
  const fallback = selectRoute({ summary: "Provider failure while reviewing exact SHA.", reviewerFallback: true });

  assert.equal(selectedAgent(normal, "final_reviewer"), ROUTING_POLICY.final_reviewer.agent);
  assert.equal(normal.selectedRoutes[1].model, "openai-codex/gpt-5.5");
  assert.equal(normal.selectedRoutes[1].thinking, "xhigh");
  assert.equal(normal.fallbackInvoked, false);
  assert.equal(selectedAgent(fallback, "reviewer_fallback"), ROUTING_POLICY.reviewer_fallback.agent);
  assert.equal(fallback.fallbackInvoked, true);
});

test("argument parser handles counts, JSON flag, fallback flag, and delimiter", () => {
  const parsed = parseRouteArgs("--json --files 21 --diff-lines=1001 --provider-failure-fallback -- Fix auth token flow", "mr-route");

  assert.equal(parsed.json, true);
  assert.equal(parsed.filesChanged, 21);
  assert.equal(parsed.diffLines, 1001);
  assert.equal(parsed.reviewerFallback, true);
  assert.equal(parsed.summary, "Fix auth token flow");
});

test("pinned pi agent frontmatter and high-verbosity body policy are present", () => {
  const expected = {
    "mr-builder-opus48.md": ["mr-builder-opus48", "anthropic/claude-opus-4-8", "medium"],
    "mr-builder-opus48-high.md": ["mr-builder-opus48-high", "anthropic/claude-opus-4-8", "high"],
    "mr-reviewer-gpt55-xhigh.md": ["mr-reviewer-gpt55-xhigh", "openai-codex/gpt-5.5", "xhigh"],
    "mr-reviewer-opus48-xhigh.md": ["mr-reviewer-opus48-xhigh", "anthropic/claude-opus-4-8", "xhigh"],
  };

  for (const [fileName, [name, model, thinking]] of Object.entries(expected)) {
    const content = readFileSync(join(PLUGIN_ROOT, "agents", "pi", fileName), "utf8");
    const frontmatter = content.match(/^---\n([\s\S]*?)\n---\n/u)?.[1] ?? "";
    assert.match(frontmatter, new RegExp(`^name: ${name}$`, "mu"));
    assert.match(frontmatter, new RegExp(`^model: ${model.replaceAll("/", "\\/").replaceAll(".", "\\.")}$`, "mu"));
    assert.match(frontmatter, new RegExp(`^thinking: ${thinking}$`, "mu"));
    assert.match(content, /High verbosity body policy/u);
    assert.match(content, /Required verbosity: high/u);
  }
});
