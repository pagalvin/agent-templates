# Plan NNNN: Title

- Plan format: linked-v1
- Status: `draft` | `active` | `blocked` | `complete` | `superseded`
- Date: YYYY-MM-DD
- Spec: [NNNN-slug](../specs/NNNN-slug.md)
- Audience: [world-engine, backend-coding, frontend-coding, database-design, uxd, governance, humans]

Follow [plan conventions](../../.github/instructions/plans.instructions.md). This is the index template for future plans, not an active plan. Keep existing legacy plans in their original format.

Create `docs/plans/NNNN-feature.md` and matching `NNNN-feature/tasks/T-<effort>.<seq>.md` files using [task_template.md](task_template.md). Resolve the example paths below for the real plan. All task files must exist before readiness review; do not create executable tasks from this template's placeholders.

## Progress

This block is a derived summary. Task files own task status; recheck their records and effort gates before dispatch. Owners refresh this summary with each task status change; the planner records governance and explicitly reported human testing outcomes.

- Current effort: E-01
- Completed efforts: none
- Blocked tasks: none
- Next recommended task: T-01.1
- Last updated: YYYY-MM-DD

| Effort | Title | Tasks | Done | Status  |
| ------ | ----- | ----- | ---- | ------- |
| E-01   |       | 0     | 0    | pending |

## Summary

Two or three sentences: what this plan delivers and the shape of the approach.

## Inputs

- Spec readiness at planning time:
- Governance readiness review: pending (required before implementation starts)
- Current execution authorization: none; status/recommendation requests do not authorize execution
- ADRs reviewed:
- UX artifacts used:
- Schema reference:
- Intersecting tech debt:

## Applicable ADRs

| ADR | Applies because | Binds efforts |
| --- | --------------- | ------------- |
|     |                 |               |

State explicitly if no ADRs apply.

## Approach

Shared implementation constraints and source links, not every task's instructions or historical investigation. Note patterns/utilities to reuse; do not restate the spec. Put task-specific constraints in task files.

Only when substantial cross-task coordination requires it, link an accepted handoff in `NNNN-feature/handoffs/` with owner, approval evidence, consumers, and governing references. Prefer existing canonical contracts over copying them.

Assign all UI and accessibility testing to `human-developer`, with manual setup, scenarios, expected results, and evidence requirements. Do not plan automated UI/browser or accessibility testing. Keep agent-owned non-rendered unit tests separate from human acceptance and its dependent gates.

## Non-goals

What this plan deliberately does not cover.

---

## Task directory

Task files are authoritative for Owner, Status, Depends on, Files, and Verify. This directory only maps permanent IDs to titles and files. Keep cancelled entries and use fresh IDs for additions.

| Task   | Title                  | File                                   |
| ------ | ---------------------- | -------------------------------------- |
| T-01.1 | First focused task     | [T-01.1](NNNN-feature/tasks/T-01.1.md) |
| T-01.2 | Dependent focused task | [T-01.2](NNNN-feature/tasks/T-01.2.md) |

Example relationship: T-01.1 declares `Depends on: none`; T-01.2 declares `Depends on: T-01.1` in its own file. Replace both with real tasks and verification.

## E-01: Effort title

**Goal:** What this effort delivers.

**Exit gate:** The condition that must hold before dependent efforts begin.

**Depends on:** none

**Tasks:** [T-01.1](NNNN-feature/tasks/T-01.1.md), [T-01.2](NNNN-feature/tasks/T-01.2.md). Read execution order from task dependencies, not numeric order.

---

## Risks and open items

| ID  | Item | Impact | Owning agent | Blocks |
| --- | ---- | ------ | ------------ | ------ |
| R-1 |      |        |              |        |

## Revisions

| Date       | Trigger      | Change                 |
| ---------- | ------------ | ---------------------- |
| YYYY-MM-DD | Initial plan | Created from spec NNNN |
