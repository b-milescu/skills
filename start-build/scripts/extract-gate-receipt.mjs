import { readFileSync, writeFileSync } from "node:fs";

const usage = `usage: bun <start-build-dir>/scripts/extract-gate-receipt.mjs --input <complete-note.md> --output <fresh-receipt.yaml>
       bun <start-build-dir>/scripts/extract-gate-receipt.mjs --help`;
function fail(reason) {
  console.error(`gate-receipt extraction failed: ${reason}\n${usage}`);
  process.exit(1);
}

const argv = process.argv.slice(2);
if (argv.length === 1 && argv[0] === "--help") {
  console.log(usage);
  process.exit(0);
}
if (argv.length !== 4) fail("invalid arguments");
const args = new Map();
for (let index = 0; index < argv.length; index += 2) {
  const [flag, value] = argv.slice(index, index + 2);
  if (!["--input", "--output"].includes(flag) || !value || value.startsWith("--") || args.has(flag)) fail("invalid arguments");
  args.set(flag, value);
}

let bytes;
try { bytes = readFileSync(args.get("--input")); }
catch { fail("cannot read input"); }
let body;
try { body = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes); }
catch { fail("invalid UTF-8 input"); }

// Decode strictly, but retain byte offsets: extraction never round-trips YAML or text.
let offset = 0;
const parts = body.split("\n");
const lines = parts.map((part, index) => {
  const start = offset;
  const hasNewline = index < parts.length - 1;
  offset += Buffer.byteLength(part) + (hasNewline ? 1 : 0);
  return { text: hasNewline && part.endsWith("\r") ? part.slice(0, -1) : part, start, next: offset };
});
const childLine = (line) => /^[ \t]/.test(line) || line === "";
let receipt;
if (lines[0].text === "gate_receipt:") {
  if (!lines.slice(1).every((line) => childLine(line.text))) fail("invalid receipt wrapper");
  receipt = bytes;
} else {
  let fence = null;
  let candidates = 0;
  let malformed = false;
  for (const line of lines) {
    if (!fence) {
      const opening = line.text.match(/^(`{3,}|~{3,})(.*)$/);
      if (opening) fence = { marker: opening[1], receipt: line.text === "```yaml", start: line.next, count: 0, rows: 0, invalid: false };
      continue;
    }
    if (!fence.receipt) {
      // Outer example/non-receipt fences suppress nested receipt-looking content.
      const closing = line.text.match(/^(`+|~+)[ \t]*$/);
      if (closing && closing[1][0] === fence.marker[0] && closing[1].length >= fence.marker.length) fence = null;
      continue;
    }
    if (line.text === "```") {
      if (fence.count) {
        malformed ||= fence.invalid;
        receipt = bytes.subarray(fence.start, line.start);
      }
      fence = null;
      continue;
    }
    if (line.text.startsWith("gate_receipt:")) {
      candidates++;
      fence.count++;
    }
    if (fence.rows === 0 ? line.text !== "gate_receipt:" : !childLine(line.text)) fence.invalid = true;
    fence.rows++;
  }
  if (candidates !== 1 || malformed || (fence?.receipt && fence.count) || !receipt) fail("invalid receipt wrapper");
}

// Exclusive creation also refuses collisions and existing/dangling symlinks.
try { writeFileSync(args.get("--output"), receipt, { flag: "wx" }); }
catch { fail("cannot create output"); }
