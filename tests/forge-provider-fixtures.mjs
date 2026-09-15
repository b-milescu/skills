import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const pass = { gitlab: "success", github: "SUCCESS", "azure-devops": "succeeded" };
function complete(page) { return page && !page.truncated && (page.next_page ?? page.continuationToken ?? null) === null && !(page.hasNextPage ?? page.pageInfo?.hasNextPage); }

function native(f) {
  if (f.provider === "gitlab") return {
    project: f.preflight.path_with_namespace, change: f.snapshot.iid, source: f.snapshot.sha,
    reviewComplete: complete(f.snapshot.diffs) && complete(f.snapshot.discussions) && f.snapshot.approvals.complete && f.snapshot.approvals.approved && f.snapshot.discussions.unresolved_required === 0,
    sourceCi: [f.snapshot.pipeline.sha, f.snapshot.pipeline.status],
    publish: [f.publish.iid, f.publish.description_sha], publishReadback: [f.publish.readback.iid, f.publish.readback.description_sha],
    report: [f.publish.report.note_id, f.publish.report.body_sha], reportReadback: [f.publish.report.readback.note_id, f.publish.report.readback.body_sha],
    action: [f.act.result.iid, f.act.result.sha, f.act.result.merge_when_pipeline_succeeds], actionReadback: [f.act.readback.iid, f.act.readback.sha, f.act.readback.merge_when_pipeline_succeeds],
    result: f.post_merge_snapshot.merge_commit_sha, defaultCommit: f.post_merge_snapshot.default_branch_sha,
    resultCi: [f.post_merge_snapshot.pipeline.sha, f.post_merge_snapshot.pipeline.status], closed: f.post_merge_snapshot.issue.state === "closed",
    sourceExists: f.post_merge_snapshot.source_branch.exists, postComplete: complete(f.post_merge_snapshot.page),
  };
  if (f.provider === "github") return {
    project: f.preflight.nameWithOwner, change: f.snapshot.number, source: f.snapshot.headRefOid,
    reviewComplete: complete(f.snapshot.files.pageInfo) && complete(f.snapshot.reviews.pageInfo) && complete(f.snapshot.threads.pageInfo) && f.snapshot.reviews.reviewDecision === "APPROVED" && f.snapshot.threads.unresolvedRequired === 0,
    sourceCi: [f.snapshot.checkSuites[0].headSha, f.snapshot.checkSuites[0].conclusion],
    publish: [f.publish.number, f.publish.bodyOid], publishReadback: [f.publish.readback.number, f.publish.readback.bodyOid],
    report: [f.publish.report.commentId, f.publish.report.bodyOid], reportReadback: [f.publish.report.readback.commentId, f.publish.report.readback.bodyOid],
    classicComplete: complete(f.snapshot.statusContexts.pageInfo),
    classicStatuses: f.snapshot.statusContexts.contexts.map((status) => [status.sha, status.state]),
    action: [f.act.result.number, f.act.result.headRefOid, f.act.result.autoMergeRequest], actionReadback: [f.act.readback.number, f.act.readback.headRefOid, f.act.readback.autoMergeRequest],
    result: f.post_merge_snapshot.mergeCommit.oid, defaultCommit: f.post_merge_snapshot.defaultBranchRef.target.oid,
    resultCi: [f.post_merge_snapshot.checkSuites[0].headSha, f.post_merge_snapshot.checkSuites[0].conclusion], closed: f.post_merge_snapshot.issue.state === "CLOSED",
    sourceExists: f.post_merge_snapshot.headRef !== null, postComplete: complete(f.post_merge_snapshot.pageInfo),
  };
  const s = f.snapshot;
  return {
    project: `${f.preflight.project.name}/${f.preflight.repository.name}`, change: s.pullRequestId, source: s.lastMergeSourceCommit.commitId,
    sourceBinding: s.iteration.sourceRefCommit.commitId, synthetic: s.iteration.lastMergeCommit.commitId,
    reviewComplete: complete(s.diff) && complete(s.threads) && s.threads.commentsComplete && s.threads.unresolvedRequired === 0 && complete(s.policies) && s.policies.required.length > 0 && s.policies.required.every((p) => p.status === "approved") && complete(s.reviewers) && s.reviewers.votes.length > 0 && s.reviewers.votes.every((vote) => vote.vote > 0) && complete(s.workItems) && s.workItems.revisions.length > 0 && s.workItems.comments.length > 0 && s.workItems.comments.every((comment) => s.workItems.revisions.some((revision) => revision.id === comment.workItemId && revision.rev === comment.revision)),
    sourceCi: [s.build.sourceVersion, s.build.result],
    publish: [f.publish.pullRequestId, f.publish.descriptionHash], publishReadback: [f.publish.readback.pullRequestId, f.publish.readback.descriptionHash],
    report: [f.publish.report.threadId, f.publish.report.contentHash], reportReadback: [f.publish.report.readback.threadId, f.publish.report.readback.contentHash],
    action: [f.act.result.pullRequestId, f.act.result.lastMergeSourceCommit.commitId, f.act.result.completionOptions.deleteSourceBranch], actionReadback: [f.act.readback.pullRequestId, f.act.readback.lastMergeSourceCommit.commitId, f.act.readback.completionOptions.deleteSourceBranch],
    result: f.post_merge_snapshot.lastMergeCommit.commitId, defaultCommit: f.post_merge_snapshot.defaultBranchCommit.commitId,
    resultCi: [f.post_merge_snapshot.build.sourceVersion, f.post_merge_snapshot.build.result], closed: f.post_merge_snapshot.workItem.state === "Closed",
    sourceExists: f.post_merge_snapshot.sourceRef.exists, postComplete: complete(f.post_merge_snapshot),
  };
}

function verify(f) {
  const n = native(f), e = f.expected;
  assert.equal(n.project, e.repository ? `${e.project}/${e.repository}` : e.project, "opaque project identity mismatch");
  assert.equal(n.change, e.change, "opaque change identity mismatch");
  assert.equal(n.source, e.source, "stale/wrong source commit");
  if (f.provider === "azure-devops") {
    assert.equal(n.sourceBinding, e.source, "missing/stale iteration sourceRefCommit");
    assert.equal(n.synthetic, e.synthetic, "missing/stale synthetic merge commit");
    assert.equal(n.sourceCi[0], e.synthetic, "source CI not bound to synthetic merge commit");
  } else assert.equal(n.sourceCi[0], e.source, "wrong source-commit CI");
  assert.equal(n.reviewComplete, true, "incomplete review/snapshot evidence");
  assert.equal(n.sourceCi[1], pass[f.provider], "source CI not pass-eligible");
  if (f.provider === "github") {
    assert.equal(n.classicComplete, true, "incomplete classic status evidence");
    assert.ok(n.classicStatuses.length > 0, "missing classic status contexts");
    assert.ok(n.classicStatuses.every(([sha, state]) => sha === e.source && state === "SUCCESS"), "classic status not pass-eligible at source commit");
  }
  assert.ok(f.act.allowed.includes(f.act.requested), "disallowed transition");
  assert.deepEqual(n.publishReadback, n.publish, "publication readback mismatch");
  assert.deepEqual(n.reportReadback, n.report, "report readback mismatch");
  assert.deepEqual(n.actionReadback, n.action, "action readback mismatch");
  assert.deepEqual(n.action, [e.change, e.source, e.action_flag], "guarded finish result mismatch");
  assert.equal(n.result, e.result, "wrong provider result commit");
  assert.equal(n.defaultCommit, e.result, "provider result not contained by default");
  assert.equal(n.resultCi[0], e.result, "wrong result-commit CI");
  assert.equal(n.resultCi[1], pass[f.provider], "result CI not pass-eligible");
  assert.equal(n.closed, e.close_item, "linked item closure mismatch");
  assert.equal(n.sourceExists, !e.delete_source, "source-ref cleanup/retention mismatch");
  assert.equal(n.postComplete, true, "incomplete post-merge snapshot");
}

for (const provider of Object.keys(pass)) {
  const fixture = JSON.parse(readFileSync(new URL(`./fixtures/forge/${provider}.json`, import.meta.url), "utf8"));
  verify(fixture);
  const failures = [
    ["wrong commit", (x) => { if (provider === "gitlab") x.snapshot.sha = "f".repeat(40); else if (provider === "github") x.snapshot.headRefOid = "f".repeat(40); else x.snapshot.lastMergeSourceCommit.commitId = "f".repeat(40); }, /stale\/wrong source commit/],
    ["incomplete review page", (x) => { if (provider === "gitlab") x.snapshot.discussions.next_page = "2"; else if (provider === "github") x.snapshot.reviews.pageInfo.hasNextPage = true; else x.snapshot.threads.commentsComplete = false; }, /incomplete review\/snapshot evidence/],
    ["failed source CI", (x) => { if (provider === "gitlab") x.snapshot.pipeline.status = "failed"; else if (provider === "github") x.snapshot.checkSuites[0].conclusion = "FAILURE"; else x.snapshot.build.result = "failed"; }, /source CI not pass-eligible/],
    ["failed result CI", (x) => { if (provider === "gitlab") x.post_merge_snapshot.pipeline.status = "failed"; else if (provider === "github") x.post_merge_snapshot.checkSuites[0].conclusion = "FAILURE"; else x.post_merge_snapshot.build.result = "failed"; }, /result CI not pass-eligible/],
    ["disallowed transition", (x) => { x.act.requested = "delete"; }, /disallowed transition/],
    ["mismatched readback", (x) => { if (provider === "gitlab") x.publish.readback.description_sha = "other"; else if (provider === "github") x.publish.readback.bodyOid = "other"; else x.publish.readback.descriptionHash = "other"; }, /publication readback mismatch/],
    ["wrong result CI", (x) => { if (provider === "gitlab") x.post_merge_snapshot.pipeline.sha = x.expected.source; else if (provider === "github") x.post_merge_snapshot.checkSuites[0].headSha = x.expected.source; else x.post_merge_snapshot.build.sourceVersion = x.expected.source; }, /wrong result-commit CI/],
    ["unclosed item", (x) => { if (provider === "gitlab") x.post_merge_snapshot.issue.state = "opened"; else if (provider === "github") x.post_merge_snapshot.issue.state = "OPEN"; else x.post_merge_snapshot.workItem.state = "Active"; }, /linked item closure mismatch/],
    ["unexpected source ref", (x) => { if (provider === "gitlab") x.post_merge_snapshot.source_branch.exists = true; else if (provider === "github") x.post_merge_snapshot.headRef = { name: "issue-381" }; else x.post_merge_snapshot.sourceRef.exists = false; }, /source-ref cleanup\/retention mismatch/],
  ];
  if (provider === "github") failures.push(
    ["missing classic status", (x) => { x.snapshot.statusContexts.contexts = []; }, /missing classic status contexts/],
    ["incomplete classic status", (x) => { x.snapshot.statusContexts.pageInfo.hasNextPage = true; }, /incomplete classic status evidence/],
    ["wrong classic status commit", (x) => { x.snapshot.statusContexts.contexts[0].sha = "f".repeat(40); }, /classic status not pass-eligible/],
    ["failed classic status", (x) => { x.snapshot.statusContexts.contexts[0].state = "FAILURE"; }, /classic status not pass-eligible/],
  );
  if (provider === "azure-devops") failures.push(
    ["stale iteration source", (x) => { x.snapshot.iteration.sourceRefCommit.commitId = "f".repeat(40); }, /iteration sourceRefCommit/],
    ["missing policy", (x) => { x.snapshot.policies.required = []; }, /incomplete review\/snapshot evidence/],
    ["incomplete policy page", (x) => { x.snapshot.policies.continuationToken = "next"; }, /incomplete review\/snapshot evidence/],
    ["wrong synthetic merge", (x) => { x.snapshot.build.sourceVersion = x.expected.source; }, /source CI not bound to synthetic merge commit/],
    ["missing work-item revision", (x) => { x.snapshot.workItems.revisions = []; }, /incomplete review\/snapshot evidence/],
    ["missing work-item comment", (x) => { x.snapshot.workItems.comments = []; }, /incomplete review\/snapshot evidence/],
    ["incomplete work-item page", (x) => { x.snapshot.workItems.continuationToken = "next"; }, /incomplete review\/snapshot evidence/],
    ["mismatched work-item revision", (x) => { x.snapshot.workItems.comments[0].revision = 6; }, /incomplete review\/snapshot evidence/],
    ["missing reviewer vote", (x) => { x.snapshot.reviewers.votes = []; }, /incomplete review\/snapshot evidence/],
    ["disallowed reviewer vote", (x) => { x.snapshot.reviewers.votes[0].vote = -10; }, /incomplete review\/snapshot evidence/],
  );
  for (const [name, mutate, error] of failures) { const copy = structuredClone(fixture); mutate(copy); assert.throws(() => verify(copy), error, `${provider} accepted ${name}`); }
}
console.log("forge-provider-fixtures: PASS");
