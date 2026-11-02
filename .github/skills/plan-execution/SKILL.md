---
name: plan-execution
description: Navigate, resume, report status, or coordinate explicitly authorized implementation-plan tasks in this repository. Use for linked or legacy plan assignments, prerequisite checks, and durable task evidence/progress updates; respect the current agent's role.
---

# Plan execution

Follow [plan conventions](../../instructions/plans.instructions.md) and the current agent's ownership/authority rules.

This skill defines procedures, not permission to execute, new tools, or an exemption from governance. If skill invocation is unavailable, read this file directly using existing tools.

## Locate and resolve

1. **Discover the plan.** Prefer `scripts/Get-PlanStatus.ps1` with `-RepositoryRoot` and optionally `-Plan`. Select only eligible active/blocked plans unless the user explicitly names another plan. If none qualify, report that; if multiple qualify, request selection. Never select by modification time.

2. **Resolve the format.** `Plan format: linked-v1` identifies an index with permanent task files. Unmarked inline plans are legacy and remain unchanged. Stop on unknown/mixed formats, missing links, or ambiguous records. Script `valid: true` means basic structural validity, not execution readiness.

3. **Discover tasks.** For linked-v1 plans, prefer `scripts/Get-TaskStatus.ps1` with `-RepositoryRoot` and `-Plan`, optionally `-Task`. Use its structured task IDs, owners, statuses, and declared dependencies. Legacy plans use inline records.

4. **Validate dependencies.** For linked-v1 plans, run `scripts/Test-PlanDependencies.ps1` with `-RepositoryRoot` and `-Plan`. Inspect missing references, cycles, inconsistent completion states, and dependency-ready candidates. Treat errors as blockers to affected dispatch. Dependency readiness is not execution authorization.

5. **Validate consistency.** For linked-v1 plans, run `scripts/Test-PlanConsistency.ps1` with `-RepositoryRoot` and `-Plan`. Inspect structural errors, Progress discrepancies, and warnings. Investigate findings before affected dispatch. Route plan/task reconciliation to `implementation-planner`; never silently modify authoritative records.

6. **Resolve readiness and authority.** Read index Progress, current authorization, governance evidence, relevant effort gates, and assigned task records. Linked task files own metadata/status; Progress is derived. Confirm accepted dependency outcomes, cancellation rationale, verification requirements, and execution scope. Script results never substitute for governance approval or explicit authorization.

If command execution is unavailable, perform the corresponding checks directly against authoritative records using read tools and disclose which scripts were not run. Never claim script-based validation from manual inspection. Stop on unresolved errors rather than treating missing results as success.

For lightweight status requests, dependency and consistency validation may be omitted when not needed to answer the question. Before dispatching new work, run all applicable validation checks.

## Load context for the role

- **Implementation/UX owner:** Read assigned instructions/Verify, relevant dependency outcomes, governing spec/ADR/UX sections, and affected source/contracts. Avoid unrelated sibling histories.
- **Dispatcher:** Use structured script results to identify candidate tasks. Read authoritative records to evaluate gates, evidence, ownership, and file overlap. For dispatch, provide task paths, scope, accepted handoffs, constraints, and evidence/update requirements—not the full plan transcript.
- **Planner/governance:** Retain whole-feature planning and complete logical-plan review. Splitting files does not reduce readiness or traceability obligations.
- **Closeout/debugging:** Inspect completion evidence, defect-relevant tasks, and actual source/diff as appropriate.

Read a task's Current outcome before historical Notes. Proposals and superseded discussion are not accepted contracts. Expand context whenever a decision, invariant, or source remains unclear.

## Check before action

Only `next-step-dispatcher` coordinates explicitly authorized plan execution. Status and recommendation requests are read-only, except for the separately authorized documentation-reconciliation exception below.

A new task must be `pending`, have valid ID/owner/effort/backlink and concrete Verify, satisfied dependencies and effort gates, and fall within explicit authorization. A cancelled dependency counts as satisfied only with documented rationale.

Report `in-progress` tasks as underway; never duplicate their execution. An owner resuming its own task must recheck gates and evidence.

Missing task records, duplicate IDs, cycles, conflicting metadata, stale Progress, or unresolved decisions require investigation and owner/planner reconciliation before affected dispatch. Never repair another owner's task status or bypass a gate.

`human-developer` is a human owner, not an invokable agent. All rendered UI and accessibility testing requires human evidence.

Governance remains read-only; `implementation-planner` records governance decisions and explicit human results. No agent may infer either.

## Automatic documentation reconciliation

`next-step-dispatcher` may delegate narrowly scoped, nonsemantic documentation corrections to `business-requirements` under its standing authorization, without separate approval for each eligible correction.

Eligible changes include:

- Obvious typographical and formatting errors.
- Broken documentation links with unambiguous intended destinations.
- Terminology inconsistencies where a canonical term is established.
- Incorrect descriptive references supported by authoritative sources.
- Other mechanical documentation corrections that do not change meaning.

This authorization does not permit changing requirements, acceptance criteria, product behavior, ADRs, implementation plans, task records, governance decisions, code, or tests.

Only documents owned by `business-requirements` may be changed under this exception.

The dispatcher must:

1. Identify the discrepancy and its authoritative source.
2. Delegate only the bounded correction to `business-requirements`.
3. Require a report of changed files and the correction made.
4. Review the resulting diff to confirm the change is nonsemantic and within scope.
5. Report the correction transparently.

Ambiguous, semantic, cross-owner, or material discrepancies require escalation.

This exception never authorizes implementation, task completion, dependency satisfaction, or governance gate closure.

## Execute and record

1. **Begin work.** The assigned owner marks its authoritative task `in-progress` before work and refreshes derived Progress. Linked plans update the task file and index; legacy plans update inline records.

2. **Implement and verify.** Implement only assigned scope using approved contracts. Run the smallest appropriate checks satisfying the task's observable Verify condition. Failed or unavailable verification is a blocker, not success.

3. **Record the outcome.** Record the current outcome and evidence, append material Notes/blockers, and mark `done` only after verification passes; otherwise mark `blocked` with evidence. Refresh Progress. Re-read shared state before edits because cross-file writes are not atomic.

4. **Revalidate before continuing.** After each delegated task, the dispatcher re-runs relevant discovery, dependency, and consistency checks, then inspects durable outcomes, evidence, and gates before dependent dispatch. A subagent's narrative alone is insufficient.

5. **Handle interruptions.** On interruption or inconsistency, report stale summaries and stop affected execution. Owners/planner may reconcile derived Progress without changing another owner's authoritative task status.

6. **Preserve history.** Preserve IDs, cancellation reasons, completed content, and meaningful history. Scope/dependency replanning belongs to the planner and material changes require renewed readiness review. Changed completed results require new tasks, not rewritten history.

## Finish within the role

Report the bounded result, verification evidence, outstanding blockers, and next handoff. Do not dispatch additional work outside authorization.

Recommend archival only when every task is `done` or `cancelled` with documented rationale and required gates are satisfied. Move linked indexes and folders together only with explicit authorization and link verification.

Never automatically migrate, archive, commit, or push.

For future plan authoring, use the [index template](../../../docs/plans/plan_template.md) and [task template](../../../docs/plans/task_template.md).