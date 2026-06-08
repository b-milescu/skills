export const ROUTING_POLICY = Object.freeze({
  builder: Object.freeze({
    role: "builder",
    agent: "mr-builder-opus48",
    model: "anthropic/claude-opus-4-8",
    thinking: "medium",
    verbosity: "high",
  }),
  builder_high_risk: Object.freeze({
    role: "builder_high_risk",
    agent: "mr-builder-opus48-high",
    model: "anthropic/claude-opus-4-8",
    thinking: "high",
    verbosity: "high",
  }),
  final_reviewer: Object.freeze({
    role: "final_reviewer",
    agent: "mr-reviewer-gpt55-xhigh",
    model: "openai-codex/gpt-5.5",
    thinking: "xhigh",
    verbosity: "high",
  }),
  reviewer_fallback: Object.freeze({
    role: "reviewer_fallback",
    agent: "mr-reviewer-opus48-xhigh",
    model: "anthropic/claude-opus-4-8",
    thinking: "xhigh",
    verbosity: "high",
  }),
});

const HIGH_RISK_PATTERNS = Object.freeze([
  Object.freeze({
    category: "security_auth",
    label: "auth/security/crypto/secrets",
    pattern: /\b(auth(?:entication|orization)?|oauth|sso|saml|jwt|token|password|passwd|secret|credential|crypto|encrypt(?:ion)?|decrypt(?:ion)?|tls|ssl|session|csrf|xss|rbac|mfa|2fa)\b/iu,
  }),
  Object.freeze({
    category: "migration_schema",
    label: "migrations/schema/data-loss risk",
    pattern: /\b(migration|migrate|schema|database|db|sql|ddl|alter\s+table|drop\s+(?:table|column|index)|truncate|backfill|data\s*loss|destructive|constraint|foreign\s+key|persistence|persisted)\b/iu,
  }),
  Object.freeze({
    category: "runtime_deploy",
    label: "deploy/runtime/infra",
    pattern: /\b(deploy(?:ment)?|runtime|infra(?:structure)?|kubernetes|k8s|docker|container|helm|terraform|ci|cd|pipeline|production|prod|daemon|worker|service|rollout|rollback|restart|systemd|cron|scheduler)\b/iu,
  }),
  Object.freeze({
    category: "concurrency_state",
    label: "concurrency/locking/state machines",
    pattern: /\b(concurren(?:t|cy)|parallel|race|lock|mutex|lease|deadlock|state\s*machine|atomic|transaction|thread|async|queue|semaphore|idempotenc(?:y|e))\b/iu,
  }),
  Object.freeze({
    category: "permissions_billing",
    label: "permissions/billing",
    pattern: /\b(billing|invoice|payment|subscription|quota|license|entitlement|permission|permissions|access\s+control|acl|role|roles|policy|tenant|plan\s+limit)\b/iu,
  }),
  Object.freeze({
    category: "large_diff_text",
    label: "large diff / many files",
    pattern: /\b(large\s+diff|wide\s+diff|many\s+files|sweeping\s+change|big\s+refactor|repository-wide|repo-wide)\b/iu,
  }),
  Object.freeze({
    category: "unclear_criteria",
    label: "unclear acceptance criteria",
    pattern: /\b(unclear|ambiguous|tbd|to\s+be\s+decided|unknowns?|acceptance\s+criteria\s+(?:missing|unclear|unknown|tbd)|no\s+acceptance\s+criteria|definition\s+of\s+done\s+(?:missing|unclear|unknown|tbd))\b/iu,
  }),
]);

const LARGE_FILE_COUNT = 20;
const LARGE_DIFF_LINES = 1000;

export function classifyHighRisk(input = {}) {
  const summary = String(input.summary ?? "").trim();
  const normalized = summary.toLowerCase();
  const triggers = [];

  if (summary.length === 0) {
    triggers.push({
      category: "unclear_criteria",
      label: "unclear acceptance criteria",
      reason: "no issue/MR/diff summary was supplied",
    });
  }

  for (const trigger of HIGH_RISK_PATTERNS) {
    if (!trigger.pattern.test(normalized)) continue;
    triggers.push({
      category: trigger.category,
      label: trigger.label,
      reason: `matched ${trigger.label}`,
    });
  }

  const filesChanged = normalizeNonNegativeInteger(input.filesChanged);
  if (filesChanged !== undefined && filesChanged >= LARGE_FILE_COUNT) {
    triggers.push({
      category: "large_diff_files",
      label: "large diff / many files",
      reason: `filesChanged ${filesChanged} >= ${LARGE_FILE_COUNT}`,
    });
  }

  const diffLines = normalizeNonNegativeInteger(input.diffLines);
  if (diffLines !== undefined && diffLines >= LARGE_DIFF_LINES) {
    triggers.push({
      category: "large_diff_lines",
      label: "large diff / many files",
      reason: `diffLines ${diffLines} >= ${LARGE_DIFF_LINES}`,
    });
  }

  const uniqueTriggers = dedupeTriggers(triggers);
  const rationale = uniqueTriggers.length > 0
    ? uniqueTriggers.map((trigger) => `${trigger.label}: ${trigger.reason}`)
    : ["no high-risk trigger matched"];

  return Object.freeze({
    highRisk: uniqueTriggers.length > 0,
    triggers: Object.freeze(uniqueTriggers),
    rationale: Object.freeze(rationale),
  });
}

export function selectRoute(input = {}) {
  const classification = classifyHighRisk(input);
  const builder = classification.highRisk ? ROUTING_POLICY.builder_high_risk : ROUTING_POLICY.builder;
  const fallbackRequested = input.reviewerFallback === true;
  const reviewer = fallbackRequested ? ROUTING_POLICY.reviewer_fallback : ROUTING_POLICY.final_reviewer;
  const highRiskRationale = classification.rationale;

  const selectedRoutes = [
    routeMetadata(builder, highRiskRationale),
    routeMetadata(reviewer, highRiskRationale, fallbackRequested
      ? "explicit provider-failure fallback path invoked"
      : "default final reviewer route"),
  ];

  return Object.freeze({
    command: input.command ?? "mr-route",
    input: Object.freeze({
      summary: String(input.summary ?? ""),
      filesChanged: normalizeNonNegativeInteger(input.filesChanged),
      diffLines: normalizeNonNegativeInteger(input.diffLines),
      reviewerFallback: fallbackRequested,
    }),
    highRisk: classification.highRisk,
    highRiskRationale,
    triggers: classification.triggers,
    selectedRoutes: Object.freeze(selectedRoutes),
    routes: Object.freeze({
      builder: routeMetadata(ROUTING_POLICY.builder, highRiskRationale),
      builder_high_risk: routeMetadata(ROUTING_POLICY.builder_high_risk, highRiskRationale),
      final_reviewer: routeMetadata(ROUTING_POLICY.final_reviewer, highRiskRationale, "default final reviewer route"),
      reviewer_fallback: routeMetadata(ROUTING_POLICY.reviewer_fallback, highRiskRationale, "provider-failure fallback only; never a cost downgrade"),
    }),
    fallbackInvoked: fallbackRequested,
  });
}

export function parseRouteArgs(rawArgs = "", command = "mr-route") {
  const tokens = tokenizeArgs(rawArgs);
  const summaryTokens = [];
  let filesChanged;
  let diffLines;
  let reviewerFallback = false;
  let json = false;
  let delimiterSeen = false;

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (delimiterSeen) {
      summaryTokens.push(token);
      continue;
    }
    if (token === "--") {
      delimiterSeen = true;
      continue;
    }
    if (token === "--json") {
      json = true;
      continue;
    }
    if (token === "--provider-failure-fallback" || token === "--reviewer-fallback") {
      reviewerFallback = true;
      continue;
    }
    if (token.startsWith("--files=")) {
      filesChanged = normalizeNonNegativeInteger(token.slice("--files=".length));
      continue;
    }
    if (token === "--files" || token === "--file-count") {
      filesChanged = normalizeNonNegativeInteger(tokens[index + 1]);
      index += 1;
      continue;
    }
    if (token.startsWith("--file-count=")) {
      filesChanged = normalizeNonNegativeInteger(token.slice("--file-count=".length));
      continue;
    }
    if (token.startsWith("--diff-lines=")) {
      diffLines = normalizeNonNegativeInteger(token.slice("--diff-lines=".length));
      continue;
    }
    if (token === "--diff-lines" || token === "--lines") {
      diffLines = normalizeNonNegativeInteger(tokens[index + 1]);
      index += 1;
      continue;
    }
    if (token.startsWith("--lines=")) {
      diffLines = normalizeNonNegativeInteger(token.slice("--lines=".length));
      continue;
    }
    summaryTokens.push(token);
  }

  return Object.freeze({
    command,
    summary: summaryTokens.join(" ").trim(),
    filesChanged,
    diffLines,
    reviewerFallback,
    json,
  });
}

export function routeFromArgs(rawArgs = "", command = "mr-route") {
  const parsed = parseRouteArgs(rawArgs, command);
  return selectRoute(parsed);
}

export function formatRoute(route, options = {}) {
  if (options.json === true) return `${JSON.stringify(route, null, 2)}\n`;
  const riskLabel = route.highRisk ? "high-risk" : "normal";
  const builder = route.selectedRoutes[0];
  const reviewer = route.selectedRoutes[1];
  const fallbackNote = route.fallbackInvoked
    ? "explicit provider-failure fallback invoked"
    : "fallback not selected; final reviewer remains GPT-5.5 xhigh";

  return [
    "# MR route",
    "",
    `Risk: ${riskLabel}`,
    `High-risk rationale: ${route.highRiskRationale.join("; ")}`,
    "",
    "## Selected routes",
    formatRouteLine(builder),
    formatRouteLine(reviewer),
    `- reviewer fallback: ${ROUTING_POLICY.reviewer_fallback.agent} (${fallbackNote})`,
    "",
    "## Route metadata",
    "```json",
    JSON.stringify({
      highRisk: route.highRisk,
      highRiskRationale: route.highRiskRationale,
      selectedRoutes: route.selectedRoutes,
    }, null, 2),
    "```",
  ].join("\n") + "\n";
}

export function formatDeliveryInstruction(route, options = {}) {
  if (options.json === true) {
    return `${JSON.stringify({
      route,
      deliveryInstruction: buildDeliveryInstruction(route),
    }, null, 2)}\n`;
  }

  const instruction = buildDeliveryInstruction(route);
  return [
    "# MR delivery instruction",
    "",
    "This router is deterministic and non-mutating. It does not edit GitLab, files, canonical skills, approvals, ready state, or merges.",
    "The parent coordinator still owns issue-delivery-loop orchestration, parent-owned local gate, ready transition, independent review, and finish/merge authority.",
    "",
    "## Selected route",
    ...route.selectedRoutes.map(formatRouteLine),
    "",
    "## Builder launch body",
    "```text",
    instruction.builderPrompt,
    "```",
    "",
    "## Final reviewer launch body",
    "```text",
    instruction.reviewerPrompt,
    "```",
    "",
    "## Fallback rule",
    instruction.fallbackRule,
    "",
    "## Route metadata",
    "```json",
    JSON.stringify({
      highRisk: route.highRisk,
      highRiskRationale: route.highRiskRationale,
      selectedRoutes: route.selectedRoutes,
      fallbackInvoked: route.fallbackInvoked,
    }, null, 2),
    "```",
  ].join("\n") + "\n";
}

export function formatCommandOutput(rawArgs = "", command = "mr-route") {
  const parsed = parseRouteArgs(rawArgs, command);
  const route = selectRoute(parsed);
  return command === "mr-deliver"
    ? formatDeliveryInstruction(route, { json: parsed.json })
    : formatRoute(route, { json: parsed.json });
}

function routeMetadata(route, highRiskRationale, routeRationale = undefined) {
  return Object.freeze({
    role: route.role,
    selected_agent: route.agent,
    model: route.model,
    thinking: route.thinking,
    verbosity: route.verbosity,
    high_risk_rationale: highRiskRationale,
    ...(routeRationale ? { route_rationale: routeRationale } : {}),
  });
}

function buildDeliveryInstruction(route) {
  const builder = route.selectedRoutes[0];
  const reviewer = route.fallbackInvoked ? ROUTING_POLICY.reviewer_fallback : ROUTING_POLICY.final_reviewer;
  const summary = route.input.summary.trim() || "the supplied issue/MR scope";

  return Object.freeze({
    builderPrompt: [
      `Use ${builder.selected_agent} for builder delivery on: ${summary}`,
      `Pinned route: model=${builder.model}; thinking=${builder.thinking}; verbosity=${builder.verbosity}.`,
      "Mode: start-build child-builder with parent-owned gate when delegated by a parent.",
      "Required ownership fields: local_gate_owner: parent; builder_gate_status.status: not-run; builder_gate_status.not_run_reason: parent-owned; ready_transition_owner: parent.",
      "Do not mark ready, start review, approve, merge, queue auto-merge, delete branches, or mutate canonical skills outside the assigned issue scope.",
      "High verbosity is required in Review Packet and builder-final handoff prompt bodies.",
    ].join("\n"),
    reviewerPrompt: [
      `Use ${reviewer.agent} for final review after the parent gate/ready transition is complete.`,
      `Pinned route: model=${reviewer.model}; thinking=${reviewer.thinking}; verbosity=${reviewer.verbosity}.`,
      "Mode: start-review on one MR/SHA with SHA-bound evidence and authority checks.",
      "Never downgrade the final reviewer for cost. The Opus reviewer fallback is valid only for an explicit provider-failure fallback path.",
      "High verbosity is required in review prompt bodies and Review Report evidence.",
    ].join("\n"),
    fallbackRule: route.fallbackInvoked
      ? "Fallback invoked explicitly for provider failure; route uses mr-reviewer-opus48-xhigh."
      : "Fallback not invoked. Final gate-eligible review stays on mr-reviewer-gpt55-xhigh / openai-codex/gpt-5.5 / thinking xhigh.",
  });
}

function formatRouteLine(route) {
  return `- ${route.role}: ${route.selected_agent} — model=${route.model}; thinking=${route.thinking}; verbosity=${route.verbosity}`;
}

function tokenizeArgs(rawArgs) {
  const input = String(rawArgs ?? "");
  const tokens = [];
  const pattern = /"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|(\S+)/gu;
  let match;
  while ((match = pattern.exec(input)) !== null) {
    const value = match[1] ?? match[2] ?? match[3] ?? "";
    tokens.push(value.replace(/\\(["'\\])/gu, "$1"));
  }
  return tokens;
}

function normalizeNonNegativeInteger(value) {
  if (value === undefined || value === null || value === "") return undefined;
  const number = Number(value);
  if (!Number.isInteger(number) || number < 0) return undefined;
  return number;
}

function dedupeTriggers(triggers) {
  const seen = new Set();
  const unique = [];
  for (const trigger of triggers) {
    const key = `${trigger.category}:${trigger.reason}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(Object.freeze(trigger));
  }
  return unique;
}
