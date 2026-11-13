# Issue: Reduce Coordination Overhead Without Weakening Approval Gates

**Date:** 2026-11-13  
**Status:** Draft for team evaluation  
**Scope:** Harness and workflow improvements; no implementation requested.

## Summary

A small OpenCode launcher/configuration change required at least **26 minutes
36 seconds** from launcher file creation to merge. Initial planning adds
unmeasured time.

The session exposed avoidable review churn, execution-authority ambiguity,
and diagnostic retries. Independent review also caught a real test defect.
The goal is to remove redundant coordination, not weaken safeguards.

## Change Context and Evidence

The request was to create a workspace-root startup script, configure
GPT-6.1-SOL as the startup default, and restrict outside-directory access
through OpenCode permissions. It required migrating existing V1 permission
configuration to V2 without losing existing restrictions.

- Observed local interval: **12:49:51 to 13:16:27**, 2026-11-13.
- No reliable initial-request timestamp was collected; total duration was longer.
- Multiple asynchronous handoffs and repeated gate interpretations occurred.
- Runtime introspection failed because an isolated network namespace had
  loopback disabled. A loopback-only diagnostic subsequently succeeded.
- A security finding reported missing `gem` and `dnf` installation denies.
  Both were present in the staged index; the finding was withdrawn.
- Execution stopped over role and gate interpretation even after the lead
  invoked a reviewer for the specific commit and merge. Reassignment enabled
  the commit, followed by integration by the lead.
- Code review correctly identified a migration test dependent on Git `HEAD`.
  It would fail after committing the migration. An immutable fixture fixed it.
- Runtime evidence covered configuration introspection and independent
  last-match policy evaluation, not actual tool-enforcement tests.
- Numerous progress messages repeated pending states without advancing delivery.

This is evidence from one session, not a population baseline. Individual
handoff, review, execution, and waiting durations were not measured.

## Observed Friction and Possible Causes

| Observed friction | Possible cause to investigate |
| --- | --- |
| A finding contradicted the staged index | Incomplete inspection or inconsistent artifact snapshots |
| An approved operation could not be executed | Unclear distinction between reviewer invocation, authorization, and role capability |
| Diagnostics needed repeated attempts | Missing reusable environment prerequisites and validation tooling |
| Numerous handoffs and status-only turns | Fragmented ownership and insufficient orchestration discipline |
| Review evidence needed additional collection | No standard evidence bundle attached to review requests |

These are hypotheses to investigate, not confirmed explanations of every delay.
Harness changes alone will not replace better orchestration discipline.

## Possible Corrections

### 1. Bind approval to the exact operation

Create a structured record identifying the reviewed staged tree, artifact
identifiers, operation, source and target, applicable reviewer verdicts, and
explicit per-action human-in-the-loop (HIL) acceptance.

Distinguish the reviewed content snapshot from the resulting commit identifier.
Validate both when moving from commit approval to merge approval.

Make a valid operation-specific reviewer invocation visible to the authorized
executor. Do not require another identical invocation merely because the
coordinator and executor are different agents.

Relevant content, action, or target changes must invalidate the affected approval.
This is not blanket permission or approval reusable for unrelated actions.

### 2. Route by capability and authority before execution

Determine whether an agent has the necessary tools and role authorization
before assigning the operation. Keep these states separate:

- Required reviews passed.
- HIL explicitly authorized the action.
- The assigned executor has the tools and role authority to perform it.

Failures should name the missing prerequisite. Reassignment must not bypass
a denial or erase an unresolved finding.

### 3. Provide reusable diagnostics and evidence bundles

Attach a sanitized evidence bundle to each review:

- Exact snapshot identifier and relevant diff.
- Test commands, exit statuses, and immutable fixture identity.
- Configuration version and effective policy evidence.
- Diagnostic environment prerequisites, including local transport requirements.
- Explicit limitations and unresolved questions.

Label results as static inspection, independent policy evaluation, runtime
introspection, or actual enforcement testing. Do not equate these categories.
Do not describe a model default as immutable or permissions as an OS sandbox.

### 4. Reduce unnecessary serialization and handoffs

Use one implementation owner through discovery, implementation, and testing.
Run independent code and security reviews in parallel against the same frozen
snapshot when their prerequisites are satisfied.

Keep dependent gates ordered, especially inspection before downstream use of
external content. Material changes invalidate affected reviews.
Report meaningful milestones rather than every pending state.

### 5. Instrument lead time and evaluate proportional coordination

Record request start, implementation start, review submission and completion,
approval, commit, and integration timestamps. Measure waiting time, execution
time, retries, handoffs, false findings, and genuine defects caught.

Use change scope and measured risk to remove redundant coordination, not to
automatically bypass mandatory reviews or human acceptance.

## Acceptance Criteria

- Explicit per-action HIL commit, push, and merge gates remain intact.
- Required content inspection and independent reviews remain mandatory.
- Approval records identify the exact content, action, and target.
- Relevant changes reliably invalidate prior approvals.
- Executors can verify completed gates without repeating identical reviews.
- Routing checks role authority and tool capability before assignment.
- Findings identify the inspected snapshot and reproducible evidence.
- Migration tests pass before and after commit without mutable history inputs.
- Diagnostics distinguish policy evaluation from actual enforcement.
- Telemetry supports comparison of latency and review effectiveness.
- No change introduces self-approval, automatic security bypass, or secret exposure.

## Requested Team Action

Evaluate this incident as a bounded harness-improvement case. Propose a measured
pilot covering approval handoff, capability-aware routing, and reusable validation.
Preserve the review that caught the real defect while reducing avoidable retries,
inconsistent evidence, and ambiguous execution handoffs.
