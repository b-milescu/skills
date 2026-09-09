// compaction-skill-index — OMP extension that re-injects a compact index of
// loaded skills into the post-compaction context, so a parent session does not
// re-read full `skill://` bodies on the next turn (issue #444, decision #440
// note 48376 host 1).
//
// Capability notes (verified against @oh-my-pi/pi-coding-agent 18.1.15):
// - `session_before_compact` exists but its result (`cancel`, `compaction`)
//   can only cancel or replace the whole compaction — it cannot inject
//   content. The content-injection equivalent is the `session.compacting`
//   extension event whose handler result may return `context?: string[]`
//   ("Additional context lines to include in summary",
//   src/extensibility/shared-events.ts), which the session maintenance layer
//   appends to the compaction summary context
//   (src/session/session-maintenance.ts).
// - Extensions load from `~/.omp/agent/extensions/*.ts|*.js`
//   (src/extensibility/extensions/loader.ts `isExtensionFile` /
//   `discoverExtensionsInDir`; the path is named in src/sdk.ts).
//
// Contract (#444): index entries carry skill name, `skill://` URI, and a
// one-line scope note — never full skill bodies; each entry is capped at
// ~2 KiB and the whole re-injected block at ~16 KiB.
import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const PER_ENTRY_CAP = 2048
const TOTAL_CAP = 16384
const HEADER =
  "Loaded skill index (survives compaction; re-read full bodies on demand via skill:// URIs):"

function skillRoot() {
  // Test seam: point the description reader at a fixture tree.
  return process.env.COMPACT_INDEX_SKILL_ROOT || join(homedir(), ".omp", "agent", "skills")
}

function scopeNote(name) {
  try {
    const md = readFileSync(join(skillRoot(), name, "SKILL.md"), "utf8")
    const m = md.match(/^description:\s*(.+)$/m)
    return m ? m[1].trim() : "(no description in SKILL.md)"
  } catch {
    return "(SKILL.md not readable; re-read skill:// to inspect)"
  }
}

/** Build the re-injected index lines from a session text blob. */
export function buildSkillIndex(text) {
  const names = []
  const seen = new Set()
  for (const m of text.matchAll(/skill:\/\/([A-Za-z0-9][A-Za-z0-9._-]*)/g)) {
    const name = m[1].replace(/\.+$/, "") // trailing sentence punctuation is not part of the name
    if (!seen.has(name)) {
      seen.add(name)
      names.push(name)
    }
  }
  if (names.length === 0) return []

  const lines = [HEADER]
  let total = HEADER.length
  for (const name of names) {
    let entry = `- ${name} — skill://${name} — ${scopeNote(name)}`
    if (entry.length > PER_ENTRY_CAP) {
      entry = entry.slice(0, PER_ENTRY_CAP - 1) + "…"
    }
    if (total + entry.length + 1 > TOTAL_CAP) {
      lines.push(`- (index truncated at ${TOTAL_CAP} bytes; further loaded skills omitted)`)
      break
    }
    lines.push(entry)
    total += entry.length + 1
  }
  return lines
}

export default function compactionSkillIndex(omp) {
  omp.on("session.compacting", (event) => {
    const context = buildSkillIndex(JSON.stringify(event.messages ?? []))
    return context.length > 0 ? { context } : {}
  })
}
