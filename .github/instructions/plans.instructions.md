---
applyTo: 'docs/plans/**/*.md'
---

# Implementation plan conventions

Plans describe approved feature work for the interactive fiction engine. New plans use `docs/plans/plan_template.md` and `docs/plans/task_template.md`; neither template is an executable plan or task.

## Sources and ownership

- `docs/GamePRD.md` defines product direction; feature specs in `docs/specs` define bounded requirements.
- Applicable accepted ADRs in `docs/ADRs` constrain implementation. Templates, draft ADRs, and brainstorming transcripts are not accepted decisions.
- Plans are the durable source of task scope, dependencies, progress, and verification. Session-local todos and agent messages do not replace them.
- `implementation-planner` creates and amends plans; it does not dispatch or implement tasks.
- `governance` reviews readiness before the first implementation task and after material changes invalidate the review. Record its decision and evidence in Inputs; stop for blocking findings.
- `next-step-dispatcher` coordinates execution only on explicit user request. It does not implement or mark another agent's task complete.
- Task owners implement and verify their assigned work. Use exact agent names, never generic `coding` or role labels; `human-developer` is the explicit non-agent owner for human testing.

| Owner             | Responsibility                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| `world-engine`    | Simulation rules and authoritative state transitions in `packages/world-engine`                     |
| `backend-coding`  | Fastify orchestration in `apps/server` and provider integrations in `packages/llm-adapters`         |
| `frontend-coding` | React/Vite browser behavior in `apps/web`                                                           |
| `database-design` | SQLite/Prisma models, migrations, and persistence contracts in `packages/persistence`               |
| `uxd`             | Player/author flows and prototypes in `docs/uxd`                                                    |
| `human-developer` | All UI and accessibility testing, performed manually by the human developer; not an invokable agent |
| `governance`      | Read-only readiness review; the planner records findings and review evidence                        |
| `closeout`        | Bounded completed-work documentation reconciliation                                                 |

Shared contracts in `packages/shared-schema` belong to the task's domain owner, coordinated with affected consumers. Missing gameplay decisions go to `business-requirements`; unresolved architectural choices go to `adr-architect`.

## Formats and authoritative records

- **New plans:** declare `Plan format: linked-v1` in the numbered index `docs/plans/NNNN-feature.md`. Keep one logical plan per spec, with a matching `docs/plans/NNNN-feature/` folder containing permanent `tasks/T-01.1.md` files for all tasks. Create task files during planning, not only when they become active.
- **Legacy plans:** an unmarked numbered plan with the existing inline effort/task structure remains a single-file plan. Read and update it in place; do not migrate existing plans without explicit authorization.
- Unknown format markers, mixed inline/linked task definitions, or missing/ambiguous records are inconsistencies, not permission to guess, convert, or execute.
- Plan numbers mirror their originating spec. Without a spec, require an explicit override in Inputs and use an unused number across specs and plans.
- The index owns plan status, sources, current execution authorization, readiness evidence, shared constraints, effort goals/dependencies/exit gates, task directory, shared risks, and Revisions.
- Each linked task file owns its ID, parent-plan link, effort membership, Status, Owner, Depends on, Files, Intent, ADRs/source references, Verify, Notes, and current outcome. The index task directory contains IDs, titles, and relative links, not competing task definitions.
- Progress in a linked index is a **derived summary** of task records, not authoritative task status. Recheck task records and effort gates before dispatch. Legacy inline task records remain authoritative in their plan file.
- Task IDs are scoped to their plan. Resolve dependency IDs through that plan's task directory; validate file existence, unique IDs, matching task ID/effort/backlink, valid owners, and acyclic dependencies. Missing or contradictory records block affected dispatch.

Use relative links between index, tasks, and sources. Keep task filenames stable when titles change. A task must be independently actionable through precise references, not self-contained by duplicating every source.

## Context and shared handoffs

For plan status, coordination, or assigned task work, load the [plan-execution skill](../skills/plan-execution/SKILL.md) through the host's skill support when available. Otherwise read its `SKILL.md` directly with existing read tools. The skill supplies a procedure, not new tools, authorization, or authority; these conventions and agent ownership rules remain mandatory.

- **Task owners:** read index essentials, relevant effort gates, the assigned task, dependency status and relevant accepted outcomes, applicable spec/ADR/UX sections, and actual affected source. Do not routinely read every sibling task or completed investigation; expand when correctness requires it.
- **Dispatcher:** inspect authoritative task metadata (including Verify and Files where needed) to compute readiness and file overlap. Load full instructions/outcomes for assigned or affected work, not unrelated histories.
- **Planner and governance:** inspect the complete logical plan and required feature/source context. Splitting files must not reduce planning rigor, requirement traceability, or governance coverage.
- **Closeout:** reconcile all relevant task outcomes and completion evidence against the actual diff.
- **Debugging:** read the index and defect-relevant task records, accepted handoffs, and governing sources; preserve the existing paired debugging-log workflow.

For a substantial accepted cross-task contract, use an optional `NNNN-feature/handoffs/<name>.md` only when needed. If created, it must identify its owner, approval state/evidence, consumers, and governing source/task references. Proposals are not accepted handoffs. Prefer links to canonical code, API/schema docs, ADRs, and UX artifacts over a second competing contract.

Separate a task's current accepted outcome from historical Notes. Record concise changes, evidence, blockers, and supersession references, not session transcripts or repeated source inventories. Preserve material history and completed task content; use a new task, plus a handoff revision if needed, when accepted completed work must change. Do not impose arbitrary token limits or omit necessary constraints for brevity.

## Human UI and accessibility testing

- Never plan or dispatch automated UI or accessibility testing. Assign rendered UI, browser/end-to-end, visual, keyboard/focus, screen-reader, contrast, target-size, zoom, and responsive/reflow testing to `human-developer`.
- Separate human acceptance tasks from agent-owned implementation and non-rendered state/API/domain/persistence unit tests. Builds, typechecks, static inspection, and those unit tests do not establish UI or accessibility acceptance.
- Human tasks need concrete setup, scenarios, expected results, and evidence requirements, not an agent-run browser harness or accessibility scanner.
- Dispatchers hand these tasks to the human and wait for reported results; they never invoke an agent named `human-developer` or substitute another agent.
- The planner may record the human's explicit status and results with attribution. Unperformed or failed required checks keep the task incomplete and dependent gates unsatisfied.

## Structure and statuses

- Use two levels: effort (`E-01`) and task (`T-01.1`). Each effort has a goal, dependencies, and an observable exit gate.
- Every task has Status, Owner, Depends on, Files, Intent, ADRs, Verify, and Notes.
- Linked tasks also identify their ID, parent plan, effort, source references, and a concise Current outcome (pending until verified/accepted). The outcome does not replace Status, Verify, or approval gates.
- Task statuses are `pending`, `in-progress`, `blocked`, `done`, and `cancelled`. Cancelled work retains its ID and reason.
- Plan statuses are `draft`, `active`, `blocked`, `complete`, and `superseded`.
- IDs are permanent. Add fresh IDs; never renumber, reuse, or delete existing tasks.
- Dependencies must exist and be acyclic. Numeric order alone is not a dependency.
- A task is ready only when pending, all required dependencies are done, and relevant effort exit gates are satisfied. A cancelled dependency is satisfied only when the plan explicitly records why it is no longer required.
- Require design and implementation tasks for substantive persistence changes. Engine/API consumers depend on the implemented persistence contract, not merely a proposed design.
- Never require every layer for every feature. Include UX, persistence, and other work only where applicable.

## Execution and updates

- The owner sets a task to `in-progress` before work and to `done` only after its Verify condition passes. Otherwise record the blocker and mark it `blocked`.
- Before reporting a status change, append factual Notes/evidence and refresh Progress (current/completed efforts, blocked tasks, next recommended task, last updated date) as one coherent change. For linked plans, update the task file and index; for legacy plans, update the inline task and Progress in the same file.
- Re-read affected records before updating shared summaries, especially during explicitly authorized parallel work. Preserve other owners' edits; cross-file updates are not filesystem-atomic.
- If interruption leaves Progress stale, task records remain authoritative. The dispatcher stops affected execution, reports the inconsistency, and requests the owner or planner reconcile the summary before continuing. It must not silently repair statuses or bypass gates. Owners/planner may reconcile derived summaries from unchanged authoritative records, not mark another owner's task done.
- A read-only governance task is the exception: the planner records its review outcome and task status based on evidence, without changing the findings.
- For `human-developer` tasks, the planner records the human's explicitly reported status and evidence; it does not infer completion or perform the testing.
- Report missing relevant artifacts or decisions explicitly. Optional references such as schema docs, tech-debt checklists, or machine-readable UX contracts are not prerequisites unless the task needs them.
- Scope/dependency amendments belong to the planner. When replanning, amend in place, preserve completed task records, cancel obsolete pending tasks with reasons and retain their files/directory entries, add fresh tasks for reversals, and record the trigger in Revisions. Never renumber, reuse, or delete IDs. Material changes require the existing governance readiness review before affected execution resumes.

## Active plan selection and closeout

- Consider numbered feature-plan indexes or legacy files directly in `docs/plans` with status `active` or `blocked`; exclude all templates, nested task/handoff files, supporting documents, drafts, and `closed`.
- If none exist, report no active plan. If multiple qualify and the user did not select one, ask rather than picking by modification time.
- Named draft or historical plans may be reviewed explicitly, but draft plans are not execution-ready.
- A plan is complete only when every task is done or cancelled with a reason.
- `closeout` recommends archival to `docs/plans/closed`; move or delete documents only with explicit user authorization.
- Archive a linked index and its matching task/handoff folder together under `closed`, preserving their names and mutual links. Check and repair relative source links and inbound references affected by relocation; moving the pair does not preserve every external link automatically. Legacy plans retain single-file archival support.
