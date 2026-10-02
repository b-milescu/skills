import { readFileSync } from "node:fs";

const roles = new Set(["title", "description", "note", "review-packet", "receipt", "report", "body"]);
function fail(role, offset, type) {
  console.error(JSON.stringify({ role, offset, type }));
  process.exit(1);
}
if (process.argv.length !== 4 || process.argv[2] !== "--input") fail("body", 0, "arguments");
let bytes;
try { bytes = readFileSync(process.argv[3]); } catch { fail("body", 0, "read"); }
let source;
try { source = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes); }
catch { fail("body", 0, "decoding"); }
const rawControl = source.search(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/);
if (rawControl >= 0) fail("body", rawControl, "control");
// Exact two-key shape rejects duplicate keys; never expose parser diagnostics.
const string = String.raw`"(?:[^"\\\u0000-\u001f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"`;
const pair = (key) => `"${key}"\\s*:\\s*${string}`;
const envelope = new RegExp(`^\\s*\\{\\s*(?:${pair("role")}\\s*,\\s*${pair("content")}|${pair("content")}\\s*,\\s*${pair("role")})\\s*\\}\\s*$`);
if (!envelope.test(source)) fail("body", 0, "envelope");
let value;
try { value = JSON.parse(source); } catch { fail("body", 0, "envelope"); }
if (!roles.has(value.role)) fail("body", 0, "role");
for (let offset = 0; offset < value.content.length; offset += 1) {
  const code = value.content.charCodeAt(offset);
  if ((code < 32 && ![9, 10, 13].includes(code)) || code === 127) fail(value.role, offset, "control");
  if (code >= 0xd800 && code <= 0xdbff) {
    const next = value.content.charCodeAt(offset + 1);
    if (!(next >= 0xdc00 && next <= 0xdfff)) fail(value.role, offset, "utf16");
    offset += 1;
  } else if (code >= 0xdc00 && code <= 0xdfff) fail(value.role, offset, "utf16");
}
console.log("text validation: PASS");
