import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const detector = "setup-dev-skills/scripts/detect-provider.mjs";
const dir = mkdtempSync(join(tmpdir(), "provider-detector-"));

function run(name, facts, expected, error) {
  const file = join(dir, `${name}.json`);
  writeFileSync(file, JSON.stringify(facts));
  const result = spawnSync(process.execPath, [detector, file], { encoding: "utf8" });
  if (error) {
    assert.notEqual(result.status, 0, `${name} should fail closed`);
    assert.match(result.stderr, error);
  } else {
    assert.equal(result.status, 0, `${name}: ${result.stderr}`);
    assert.deepEqual(JSON.parse(result.stdout), expected);
  }
}

try {
  run("gitlab", { remote: "git@gitlab.example:group/repo.git", profile_provider: "gitlab", profile_id: "team" }, { provider: "gitlab", profile_id: "team", reference: "skill://forge/reference/gitlab.md" });
  run("github", { remote: "https://github.com/group/repo.git" }, { provider: "github", profile_id: "default", reference: "skill://forge/reference/github.md" });
  run("azure", { remote: "https://dev.azure.com/org/project/_git/repo", profile_provider: "azure-devops" }, { provider: "azure-devops", profile_id: "default", reference: "skill://forge/reference/azure-devops.md" });
  run("unknown", { remote: "ssh://code.example/group/repo.git" }, null, /unknown provider evidence/);
  run("ambiguous", { remote: "https://github.example/dev.azure.com/repo" }, null, /ambiguous provider evidence/);
  run("mismatch", { remote: "https://github.com/group/repo.git", profile_provider: "gitlab" }, null, /does not match/);
} finally {
  rmSync(dir, { recursive: true, force: true });
}

console.log("setup-provider-detector: PASS");
