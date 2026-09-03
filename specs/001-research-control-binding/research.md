# Research Notes: Generic Research Control and Binding

## Decision 1: Keep the official lifecycle and classify the project view separately

- **Decision**: Keep the official command identifiers and artifact names. The
  project registry will classify six commands as `core` and three as
  `optional_quality_control`.
- **Rationale**: Spec Kit's generated runtime is the execution source of truth.
  The repository needs a concise navigation view, but that view must not claim
  that Spec Kit has a universal fixed nine-stage taxonomy. `constitution` is a
  project-governance command; it is not repeated for every feature.
- **Alternatives considered**: Treating all nine entries as one mandatory linear
  pipeline was rejected because it makes optional quality checks mandatory and
  misrepresents the official lifecycle. Creating new executable `spec-*` or
  `plan-*` commands was rejected because it duplicates the `speckit-*` runtime.

## Decision 2: Make the preset generic and delay concrete selection to plan

- **Decision**: The source preset is named `research-control`. It owns template
  structure, research metadata, provenance, acceptance, and fail-closed rules;
  it contains no component, dataset, project path, MultiQC, or Skill binding.
- **Rationale**: A preset is reusable policy and artifact shape. A capability
  request is not yet a scientific method, so binding it in the preset would
  make every future feature inherit an arbitrary method.
- **Alternatives considered**: A fixed list of all current Skills in the preset
  was rejected because it couples unrelated methods and cannot express why one
  candidate was selected. A preset per concrete project was rejected because
  it recreates the current `bio-research-mvp` contamination problem.

## Decision 3: Use an inventory for discovery, not a fixed workflow

- **Decision**: Add a small machine-readable candidate index under
  `02-skills/skill-catalog.yml`. It distinguishes callable adapter Skills from
  reference-only material and records paths, capability hints, inputs, outputs,
  and fail-closed cues. The plan template instructs the planner to search this
  index and then read the selected Skill's contract.
- **Rationale**: Discovery needs structured metadata, while execution needs the
  full Markdown-led Skill contract. An index provides fast lookup without
  turning the index into a workflow or silently combining all 13 components.
- **Alternatives considered**: Searching only file names was rejected because
  it cannot distinguish executable adapters from references. Copying every
  reference component into `.agents/skills` was rejected because it would make
  non-runtime material appear callable.

## Decision 4: Freeze execution details in tasks

- **Decision**: `plan.md` records capability candidates and the selection reason;
  `tasks.md` records the immutable execution binding and verifier for each
  executable task. Both artifacts use explicit fields rather than prose-only
  instructions.
- **Rationale**: Plan is the first point where a method can be chosen in context;
  tasks are the handoff consumed by implementation. Separating these records
  preserves adaptability during planning and determinism during execution.
- **Alternatives considered**: Binding at implementation time was rejected
  because the task list would not be reproducible. Binding only in the preset
  was rejected because it removes feature-specific method selection.

## Decision 5: Keep Extensions and Skills as different boundaries

- **Decision**: Skills remain Markdown-led domain capabilities with references
  and supporting scripts. Extensions remain independently installed commands,
  configurations, tool adapters, or execution scripts. The generic workflow
  does not call a concrete Extension.
- **Rationale**: The two forms have different ownership, installation, and
  failure surfaces. The distinction lets a plan select either kind explicitly
  without turning either into a lifecycle phase.
- **Alternatives considered**: Flattening both into one suite type was rejected
  because it hides whether an item is guidance or an executable integration.

## Decision 6: Remove the concrete workflow binding, retain domain extensions

- **Decision**: Replace the source and installed `bio-research-mvp` workflow
  with a generic `research-control` workflow that runs only the feature control
  lifecycle. Keep `bio-multiqc` and `bio-review` independently discoverable as
  optional Extensions; do not invoke them from the generic workflow.
- **Rationale**: MultiQC is a valid domain integration but not a universal
  research-control step. Leaving the Extension available preserves the existing
  bounded artifact capability without polluting every feature.
- **Alternatives considered**: Deleting the MultiQC Extension was rejected
  because it removes a usable independently scoped integration. Keeping the
  old workflow was rejected because its required inputs make the core project a
  concrete MultiQC project.

## Decision 7: Keep efficiency/review facilities outside this feature

- **Decision**: Do not add compression, aggregate review, scoring, repair, or
  data-level experiment facilities to the preset, workflow, registry, or
  `speckit-*` Skills. They can be designed as separate future facilities.
- **Rationale**: They are cross-project productivity and evaluation concerns,
  not the control-plane contract for a new research feature.
- **Alternatives considered**: Adding them as optional workflow steps was
  rejected because optional steps still become project runtime surface and
  would mix evaluation utilities with scientific execution.

## Resolved planning unknowns

- The repository uses Markdown/YAML/PowerShell and the installed Spec Kit CLI;
  no new runtime language or pipeline engine is needed for this feature.
- The generic workflow is allowed to stop after control-artifact convergence;
  it does not claim to execute or release a biological result.
- Candidate selection is recorded as `unresolved` or `blocked` when metadata is
  incomplete. There is no implicit Agent fallback.
