#!/usr/bin/env node
/*
 * Find open GitLab issues whose title/body/labels overlap newly-created issues.
 * Requires glab authenticated in the target repo. This is a candidate finder;
 * the agent must still classify duplicates/overlaps/conflicts by reading scope.
 */
const { execFileSync } = require('node:child_process');

const args = process.argv.slice(2).filter(Boolean);
if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
  console.error('Usage: check-issue-overlap.js <issue-iid> [<issue-iid> ...]');
  process.exit(args.length === 0 ? 2 : 0);
}

function glabJson(argv) {
  const out = execFileSync('glab', argv, {
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  return JSON.parse(out);
}

function glabText(argv) {
  return execFileSync('glab', argv, {
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function getRepoProject() {
  const repo = glabJson(['repo', 'view', '-F', 'json']);
  if (repo.id || repo.ID || repo.project_id) return String(repo.id || repo.ID || repo.project_id);
  const web = repo.web_url || repo.webUrl || repo.url;
  if (!web) throw new Error('Could not determine GitLab project id or web_url from glab repo view -F json');
  const path = new URL(web).pathname.replace(/^\//, '');
  return encodeURIComponent(path);
}

const project = getRepoProject();

function fetchOpenIssues() {
  const all = [];
  for (let page = 1; page <= 20; page++) {
    const batch = glabJson(['api', `projects/${project}/issues?state=opened&per_page=100&page=${page}`]);
    if (!Array.isArray(batch) || batch.length === 0) break;
    all.push(...batch);
    if (batch.length < 100) break;
  }
  return all;
}

function fetchIssue(iid) {
  return glabJson(['api', `projects/${project}/issues/${iid}`]);
}

const openIssues = fetchOpenIssues();
const byIid = new Map(openIssues.map((i) => [Number(i.iid), i]));

const stop = new Set(`
the a an and or to of in for with by on from as is are be this that these those it its into via
issue issues add define build make move create update implement implementation architecture arch phase plan
scope goal problem acceptance criteria out of source target using use used should will can must not no yes new
current existing future follow-up followup related parent depends dependency tests testing tdd docs tooling risk medium
`.trim().split(/\s+/));

function words(text) {
  return (text || '')
    .toLowerCase()
    .match(/[a-z][a-z0-9_./-]{2,}/g)?.filter((w) => !stop.has(w) && w.length >= 3) || [];
}

function section(text, name) {
  const re = new RegExp(`(^|\\n)## ${name}\\n([\\s\\S]*?)(?=\\n## |$)`, 'i');
  const m = (text || '').match(re);
  return m ? m[2].trim().replace(/\s+/g, ' ').slice(0, 700) : '';
}

function topTerms(issue) {
  const titleWords = words(issue.title || '');
  const bodyWords = words(issue.description || '');
  const counts = new Map();
  for (const w of bodyWords) counts.set(w, (counts.get(w) || 0) + 1);
  for (const w of titleWords) counts.set(w, (counts.get(w) || 0) + 4);
  for (const label of issue.labels || []) for (const w of words(label)) counts.set(w, (counts.get(w) || 0) + 3);
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 80)
    .map(([w]) => w);
}

function sharedLabels(a, b) {
  const bs = new Set(b.labels || []);
  return (a.labels || []).filter((l) => bs.has(l));
}

function scoreCandidate(target, candidate) {
  const targetTerms = new Set(topTerms(target));
  const candidateTerms = new Set(words(`${candidate.title}\n${candidate.description || ''}\n${(candidate.labels || []).join(' ')}`));
  const overlap = [...targetTerms].filter((w) => candidateTerms.has(w));
  const targetTitleTerms = new Set(words(target.title || ''));
  const candidateTitleTerms = new Set(words(candidate.title || ''));
  const titleOverlap = [...targetTitleTerms].filter((w) => candidateTitleTerms.has(w));
  const labels = sharedLabels(target, candidate);

  const targetProblemTerms = new Set(words(section(target.description || '', 'Problem')));
  const candidateProblemTerms = new Set(words(section(candidate.description || '', 'Problem')));
  const problemOverlap = [...targetProblemTerms].filter((w) => candidateProblemTerms.has(w));

  const score = overlap.length * 2 + titleOverlap.length * 5 + labels.length * 3 + Math.min(problemOverlap.length, 10) * 2;
  return { score, overlap, titleOverlap, labels, problemOverlap };
}

console.log(`# GitLab issue overlap check`);
console.log(`Project: ${project}`);
console.log(`Open issues scanned: ${openIssues.length}`);
console.log(`Note: candidate finder only; classify by reading Problem/Goal/Scope/Out-of-scope.\n`);

for (const rawId of args) {
  const iid = Number(String(rawId).replace(/^#/, ''));
  if (!Number.isFinite(iid)) {
    console.log(`## ${rawId}\nInvalid issue iid.\n`);
    continue;
  }
  const target = byIid.get(iid) || fetchIssue(iid);
  const candidates = [];
  for (const candidate of openIssues) {
    if (Number(candidate.iid) === iid) continue;
    const result = scoreCandidate(target, candidate);
    if (result.score >= 12) candidates.push({ candidate, ...result });
  }
  candidates.sort((a, b) => b.score - a.score || Number(a.candidate.iid) - Number(b.candidate.iid));

  console.log(`## #${iid}: ${target.title}`);
  console.log(`${target.web_url || ''}`);
  if (candidates.length === 0) {
    console.log(`No material open-issue candidates found.\n`);
    continue;
  }
  console.log(`Candidates: ${Math.min(candidates.length, 10)} shown of ${candidates.length}`);
  for (const row of candidates.slice(0, 10)) {
    const issue = row.candidate;
    console.log(`\n### #${issue.iid} score=${row.score} labels=${(issue.labels || []).join(', ')}`);
    console.log(issue.title);
    console.log(issue.web_url || '');
    console.log(`shared labels: ${row.labels.join(', ') || '(none)'}`);
    console.log(`overlap terms: ${row.overlap.slice(0, 24).join(', ') || '(none)'}`);
    const problem = section(issue.description || '', 'Problem');
    const goal = section(issue.description || '', 'Goal');
    const scope = section(issue.description || '', 'Scope');
    const out = section(issue.description || '', 'Out of Scope') || section(issue.description || '', 'Out of scope');
    if (problem) console.log(`Problem: ${problem}`);
    if (goal) console.log(`Goal: ${goal}`);
    if (scope) console.log(`Scope: ${scope}`);
    if (out) console.log(`Out of scope: ${out}`);
  }
  console.log('');
}
