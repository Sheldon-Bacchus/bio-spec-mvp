---
description: "Task list template for an evidence-aware research feature"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: `plan.md` and `spec.md`; use `research.md`, `data-model.md`,
`contracts/`, and `quickstart.md` when generated.

**Format**: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel without touching the same files.
- **[Story]**: User story label such as `[US1]`; use `[FOUNDATION]` for shared work.
- Include exact file paths and a validation command or evidence path in every
  task that produces an artifact.

## Task Binding Contract

Every executable task MUST have a corresponding binding record. The generic
preset does not provide a concrete domain Skill; the feature plan supplies the
selection and this task record freezes it for implementation.

| task_id | phase | skill_id | preset_id | inputs | outputs | dependencies | verifier | acceptance | failure_behavior | provenance |
|---|---|---|---|---|---|---|---|---|---|---|
| T[###] | [feature-defined label] | [selected Skill or blocked] | [if applicable] | [paths/metadata] | [artifacts] | [task IDs] | [command/contract] | [observable condition] | [stop/block/preserve evidence] | [source/version/run ID] |

Binding rules:

- `skill_id`, `verifier`, `acceptance`, and `failure_behavior` are mandatory for
  executable tasks. A blocked task records why it cannot be selected.
- `dependencies` names predecessor tasks or required artifacts; it is not an
  implicit workflow order.
- A task binding MUST trace to a selected capability in `plan.md` and MUST
  preserve the source/version and input/output identity needed for replay.
- A failing verifier remains visible and cannot be repaired by silently
  changing the method, contrast, threshold, or result file.

## Phase 1: Setup

- [ ] T001 Record the feature directory, scope, dependencies, and source/version evidence in `specs/[###-feature]/plan.md`.
- [ ] T002 [P] Confirm the required input/output artifacts and verifier references in `specs/[###-feature]/contracts/`.

## Phase 2: Foundational contracts

- [ ] T003 Define the capability contract and unresolved/blocked behavior in `specs/[###-feature]/contracts/`.
- [ ] T004 [P] Define the task binding contract and provenance fields in `specs/[###-feature]/contracts/`.

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 First independently testable slice

**Goal**: [Smallest independently testable value]

**Independent Test**: [Exact command and expected evidence]

- [ ] T005 [US1] Implement the smallest requested artifact or execution path at `[exact path]`; bind the task to the selected capability.
- [ ] T006 [US1] Verify the artifact with `[exact command or contract path]`; preserve the result at `[evidence path]`.

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Second independently testable value, if needed]

**Independent Test**: [Exact command and expected evidence]

- [ ] T007 [US2] Implement the second story at `[exact path]` with a frozen task binding.
- [ ] T008 [US2] Verify the second story with `[exact command or contract path]`; preserve the result at `[evidence path]`.

## Phase 5: Polish and convergence

- [ ] T009 Run the validation commands from `quickstart.md` and preserve machine-readable evidence at `[evidence path]`.
- [ ] T010 Run the official convergence assessment and append only traceable remaining work if a gap is found.

## Dependencies and execution order

- Setup precedes foundational contracts.
- Foundational contracts block all user stories.
- User Story 1 is the first independently testable checkpoint; later stories must remain independently testable.
- Polish and convergence run only after the selected stories and their verifiers complete.

## Implementation strategy

1. Complete setup and contracts.
2. Implement and validate User Story 1 only.
3. Add later stories or domain Extensions only when their plan/task bindings are explicit.
4. Run the official convergence pass; keep failures and unresolved bindings visible.
