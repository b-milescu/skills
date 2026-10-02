import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const helper = resolve(import.meta.dirname, "../forge/scripts/validate-text.mjs");
const work = mkdtempSync(join(tmpdir(), "forge-text-"));
const file = join(work, "envelope.json");
const sentinel = "PRIVATE-BODY-SENTINEL";
function run(body) {
  writeFileSync(file, body);
  return spawnSync(process.execPath, [helper, "--input", file], { cwd: tmpdir(), encoding: "utf8" });
}
function reject(body, expected) {
  const result = run(body);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, "");
  const diagnostic = JSON.parse(result.stderr);
  assert.deepEqual(Object.keys(diagnostic), ["role", "offset", "type"]);
  assert.deepEqual(diagnostic, expected);
  assert.ok(!result.stderr.includes(sentinel));
}
try {
  for (const role of ["title", "description", "note", "review-packet", "receipt", "report", "body"]) {
    assert.equal(run(JSON.stringify({ role, content: "\t\n\r café 日本語 😀\ufffd" })).status, 0);
    reject(JSON.stringify({ role, content: `${sentinel}\u0000` }), { role, offset: sentinel.length, type: "control" });
  }
  assert.equal(run('{"content":"", "role":"body"}').status, 0, "empty content is valid text");
  for (const code of [...Array(32).keys()].filter((code) => ![9, 10, 13].includes(code)).concat(127)) {
    reject(JSON.stringify({ role: "note", content: `x${String.fromCharCode(code)}${sentinel}` }), { role: "note", offset: 1, type: "control" });
  }
  for (const content of ["\ud800", "\udc00", "\ud800x", "\udc00\ud800"]) reject(JSON.stringify({ role: "report", content }), { role: "report", offset: 0, type: "utf16" });
  for (const body of ["{", "null", "[]", '{}', '{"role":"body"}', '{"role":"body","content":1}', '{"role":"body","content":"x","extra":1}', '{"role":"body","role":"note","content":"x"}', JSON.stringify({ content: sentinel }), `{"role":"body","content":"${sentinel}"} trailing`]) {
    reject(body, { role: "body", offset: 0, type: "envelope" });
  }
  reject(JSON.stringify({ role: sentinel, content: sentinel }), { role: "body", offset: 0, type: "role" });
  for (const bytes of [Buffer.from([0xc0, 0xaf]), Buffer.from([0xed, 0xa0, 0x80]), Buffer.concat([Buffer.from('{"role":"note","content":"'), Buffer.from([0xff]), Buffer.from('"}')])]) reject(bytes, { role: "body", offset: 0, type: "decoding" });
  reject(`\u000b${JSON.stringify({ role: "note", content: sentinel })}`, { role: "body", offset: 0, type: "control" });
  console.log("forge-text-validator: PASS");
} finally { rmSync(work, { recursive: true, force: true }); }
