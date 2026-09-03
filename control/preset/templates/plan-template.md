# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

## Summary

[Extract the primary requirement and the smallest technical approach from the
feature specification and research notes.]

## Technical Context

**Language/Version**: [e.g., Python 3.11 or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., domain package, workflow engine, parser or NEEDS CLARIFICATION]

**Storage**: [files, object storage, database, or N/A]

**Testing**: [test command and fixture strategy]

**Target Platform**: [platform or NEEDS CLARIFICATION]

**Project Type**: [library/CLI/pipeline/documentation or NEEDS CLARIFICATION]

**Constraints**: [resource, reproducibility, privacy, or safety constraints]

**Scale/Scope**: [bounded feature scope]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Evidence before automation:
- Domain contracts first:
- Deterministic execution and provenance:
- Human quality/release gates:
- Small, testable, composable skills:

## Research design and analysis contract

- **Question and estimand**:
- **Study/sample unit**:
- **Inputs and reference identity**:
- **Variables, controls, and covariates**:
- **QC thresholds and failure actions**:
- **Statistical or decision procedure**:
- **Validation and claim boundary**:

Do not silently select thresholds, contrasts, or causal interpretations. Record
unresolved choices in `research.md` and resolve them before execution.

## Capability and Skill Selection

The preset does not select a concrete domain Skill. During planning, identify
capabilities from the feature question, search the available Skill catalog, and
record the contextual selection here. Candidate discovery is not execution.

| capability_id | candidate_skill_ids | skill_id | preset_id | selection_reason | phase/label | inputs | outputs | verifier | failure_policy | provenance | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| [capability] | [catalog candidates] | [selected or empty] | [if applicable] | [why this contract fits] | [feature-defined label] | [artifacts/metadata] | [artifacts/metadata] | [command/contract] | [stop/block/unresolved] | [source/version] | [unresolved/candidate/selected/blocked] |

Binding rules:

- `skill_id` remains empty until the plan has a complete Skill or Extension
  contract and a recorded selection reason.
- An unresolved or blocked row MUST include the missing contract field or
  decision; an Agent MUST NOT silently substitute an unspecified method.
- The phase/label is opaque and feature-defined. It does not impose a
  `research-pre`, `research-process`, or `research-post` architecture.
- The selected row is copied into `tasks.md`, where execution details are
  frozen for implementation.

## Pipeline and execution design

```text
specify → plan (select capability) → tasks (freeze binding)
        → implement → converge
```

Spec Kit is the coordination layer. A domain Skill, Extension, Nextflow,
Snakemake, or another engine is selected only by a feature plan/task and keeps
its own execution contract. This generic plan does not require any domain tool,
dataset, or project-specific output path.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

```text
presets/                 # reusable Spec Kit templates
extensions/              # deterministic commands and scripts
workflows/               # official Spec Kit workflow definitions
tests/                   # fixture and integration tests
```

**Structure Decision**: [Select and explain the concrete directories for this feature.]

## Provenance and review gates

- **Inputs**: paths, identifiers, versions, and hashes:
- **Outputs**: artifact paths and content checks:
- **Runtime**: repository revision, parameters, environment, and logs:
- **Review gates**: design, QC/validation, and release:
- **Failure policy**: stop, preserve verdict, and record repair or waiver:

## Validation strategy

- Fixture dataset or dry run:
- Unit/contract checks:
- End-to-end workflow command:
- Expected machine-readable evidence:
- Human-observable report:

## Complexity Tracking

> Fill only if the constitution check has a justified violation.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| [None or documented violation] | | |
