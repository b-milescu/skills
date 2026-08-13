#!/usr/bin/env node
import { readFileSync } from "node:fs";

const facts = JSON.parse(readFileSync(process.argv[2], "utf8"));
const remote = String(facts.remote ?? "").toLowerCase();
const explicit = facts.profile_provider ?? null;
const matches = [
  ["gitlab", /(^|[.:/@-])gitlab([.:/@-]|$)/],
  ["github", /(^|[.:/@-])github([.:/@-]|$)/],
  ["azure-devops", /dev\.azure\.com|visualstudio\.com|azure-devops/],
].filter(([, pattern]) => pattern.test(remote)).map(([provider]) => provider);

if (matches.length !== 1) throw new Error(matches.length ? "ambiguous provider evidence" : "unknown provider evidence");
if (explicit && explicit !== matches[0]) throw new Error("profile provider does not match remote provider");

const provider = matches[0];
console.log(JSON.stringify({
  provider,
  profile_id: facts.profile_id ?? "default",
  reference: `skill://forge/reference/${provider}.md`,
}));
