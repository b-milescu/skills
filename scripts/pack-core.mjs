import { cpSync, mkdirSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";

// A reviewed allowlist, not checkout discovery: native project declarations never ship.
const root = resolve(import.meta.dirname, "..");
const output = join(root, "core");
const skills = [
  "cleanup-codebase", "forge", "issue-delivery-loop", "plan-to-issues",
  "retro", "setup-dev-skills", "start-build", "start-review",
];
rmSync(output, { recursive: true, force: true });
mkdirSync(output);
for (const path of [...skills, "docs", "templates", "agents/claude", "agents/omp", "agents/README.md", "README.md", "CONTEXT.md"]) {
  cpSync(join(root, path), join(output, path), { recursive: true, dereference: true });
}
for (const skill of skills) {
  // Also handle Git's symlink-disabled checkout form (a file containing ../docs).
  for (const [alias, source] of [["docs", "docs"], ["shared-templates", "templates"]]) {
    const destination = join(output, skill, alias);
    rmSync(destination, { recursive: true, force: true });
    cpSync(join(root, source), destination, { recursive: true, dereference: true });
  }
}
console.log("Portable core materialized; npm runtime dependencies remain package-owned.");
