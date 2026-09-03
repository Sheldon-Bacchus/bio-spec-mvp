# Implementation Plan: Generic Research Control and Binding

**Branch**: `001-research-control-binding` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-research-control-binding/spec.md`

## Summary

Separate the reusable Spec Kit control plane from concrete domain execution.
Keep the official `speckit-*` runtime and canonical feature artifacts, replace
the current concrete `bio-research-mvp` source preset/workflow with generic
`research-control` packages, and add explicit plan/task binding sections. A
small candidate index makes Skills discoverable without turning the preset into
a fixed list or a workflow into a domain pipeline.

## Technical Context

**Language/Version**: Markdown and YAML; PowerShell 7 for repository validation; existing Python scripts remain extension-owned.

**Primary Dependencies**: Installed Spec Kit CLI/runtime and Codex integration; no new scientific runtime dependency.

**Storage**: Tracked Markdown/YAML manifests and feature artifacts; `.specify/feature.json` remains a local active-feature pointer.

**Testing**: PowerShell path checks, `rg` boundary scans, Spec Kit list/resolve commands, and contract inspection. No biological dataset or MultiQC run is required.

**Target Platform**: Windows Codex project with portable text artifacts.

**Project Type**: Spec Kit project package and control/configuration layer.

**Constraints**: Preserve official command/artifact names; do not add a second lifecycle runtime; do not bind a domain Skill in the generic preset; preserve provenance and fail-closed behavior; leave existing non-`bio-*` names unchanged.

**Scale/Scope**: One independent repository, one generic preset, one generic workflow, one six-plus-three command registry, five callable adapter candidates, and feature-level binding contracts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Evidence before automation: PASS. Selection and validation evidence are explicit fields; no scientific claim is inferred from artifact generation.
- Domain contracts first: PASS. Generic control owns shape/policy; selected Skills and Extensions own their domain contracts.
- Deterministic execution and provenance: PASS. Task bindings require inputs, outputs, verifier, source/version, and failure behavior.
- Human quality/release gates: PASS for scope. This feature stops at control-artifact convergence and does not release a biological result; separate review facilities remain outside this runtime.
- Small, testable, composable skills: PASS. The catalog distinguishes callable adapters from reference-only material and keeps Extensions independently scoped.

## Research design and analysis contract

- **Question and estimand**: The engineering question is whether plan-time selection and task-time freezing preserve reusable control artifacts; a biological estimand is not applicable.
- **Study/sample unit**: One Spec Kit feature directory and its control artifacts.
- **Inputs and reference identity**: `spec.md`, selected Skill/Extension contract, catalog entry, and recorded source/version; no dataset is required.
- **Variables, controls, and covariates**: Capability, candidate set, selected binding, task dependencies, verifier, acceptance, and failure state.
- **QC thresholds and failure actions**: Required binding fields and boundary scans; missing metadata yields `unresolved`/`blocked`, never an implicit fallback.
- **Statistical or decision procedure**: Not applicable. Selection is a documented capability/contract decision, not a biological inference.
- **Validation and claim boundary**: Validate structure, registry classification, installed resolution, and absence of concrete-domain pollution only.

Do not silently select thresholds, contrasts, or causal interpretations. Record
unresolved choices in `research.md` and resolve them before execution.

## Pipeline and execution design

```text
constitution (project initialization)
    → specify → plan → tasks → implement → converge

optional insertion points: clarify, checklist, analyze
domain execution: selected explicitly by task binding, not by this workflow
```

The generic `research-control` workflow invokes the feature lifecycle from
`specify` through `converge`. `constitution` remains the one-time governance
command for the project. `clarify`, `checklist`, and `analyze` remain optional
commands that can be inserted when their quality-control purpose is needed;
they are not a mandatory linear nine-stage pipeline. The workflow does not run
MultiQC, a dataset, a pipeline engine, or a release-verdict recorder. A later
task may invoke a selected Extension with its own contract and evidence.

Planning uses this sequence:

1. Read the feature's question, inputs, outputs, and acceptance boundary.
2. Identify capability needs without naming a tool prematurely.
3. Search `skills/skill-catalog.yml` and the authoritative Skill entry for
   candidates; reference-only material cannot become an executable `skill_id`.
4. Record candidates, selection reason, phase/label, inputs, outputs, verifier,
   failure policy, and provenance in `plan.md`.
5. Mark the binding `unresolved` or `blocked` if no complete contract exists.
6. Freeze the selected binding in `tasks.md` before implementation.

### Capability binding baseline for this feature

This architecture feature itself uses only the control Skill needed to edit and
verify repository artifacts; it does not select a biological method. The row is
included to exercise the same contract that future research features will use.

| capability_id | candidate_skill_ids | skill_id | preset_id | selection_reason | phase/label | inputs | outputs | verifier | failure_policy | provenance | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `control-plane-source-refactor` | `speckit-implement`, `speckit-converge` | `speckit-implement` | `research-control` | Repository artifact changes are implementation work; convergence remains a separate final verifier. | `architecture-implementation` | feature docs, source manifests, installed registries | generic preset/workflow, catalog, command map, aligned docs | quickstart commands and official convergence assessment | stop on malformed manifest or boundary scan hit; preserve evidence | local source tree, preset/workflow v0.2.0, git revision | selected |

The domain candidate set is intentionally empty for this feature. A future
feature adds its own capability rows after reading the catalog and the selected
domain contract.

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
.specify/                         # official Spec Kit runtime and registries
.agents/skills/speckit-*          # official Codex-compatible control Skills
skills/                        # Skill sources, references, catalog, archives
control/preset/        # generic research-control preset source
control/workflow/      # generic research-control workflow source
extensions/    # independently scoped domain Extensions
suites/                           # concise human command map
specs/                            # official feature artifact directories
archive/005-work-package/             # historical/reference work package
examples/bio-multiqc/fixtures/           # domain fixture, not generic workflow input
```

**Structure Decision**: Keep the existing Spec Kit project layout. Generic
template/policy sources stay under `control/preset`; workflow source
stays under `control/workflow`; domain Skills and Extensions remain
separate. Installed copies under `.specify` are updated through the official
CLI, while `specs/001-research-control-binding/` holds this feature's design
artifacts. The historical work package is not rewritten by this feature.

### Planned source changes

- `control/preset/preset.yml`: rename the generic package to
  `research-control` and remove concrete component bindings.
- `control/preset/contracts/research-core-profile.yml`: retain only
  ownership/boundary semantics; remove component-specific entries.
- `control/preset/templates/plan-template.md`: add plan-level
  capability discovery and binding fields.
- `control/preset/templates/tasks-template.md`: add task-level
  frozen binding fields while retaining checklist-compatible task syntax.
- `control/workflow/workflow.yml`: make the workflow generic and
  control-only; remove MultiQC inputs, shell calls, and release-verdict steps.
- `skills/skill-catalog.yml`: index callable adapters separately from
  reference-only material.
- `control/command-registry.yml` and `control/command-map.md`: classify six
  core and three optional QC commands without claiming a universal official
  nine-stage taxonomy.
- Root/package documentation and installed registries: identify
  `research-control` as generic and MultiQC as an independent Extension.

## Provenance and review gates

- **Inputs**: feature `spec.md`, catalog/Skill contract paths, source revisions,
  and any concrete input paths recorded only after task selection.
- **Outputs**: `plan.md` capability records, `tasks.md` frozen records, registry
  classification, and CLI resolution evidence.
- **Runtime**: repository revision, preset/workflow version, selected
  Skill/Extension source/version, command parameters, environment, and hashes
  when a domain task later executes.
- **Review gates**: this feature's requirements checklist and final converge
  check; no compression, aggregate review, score, repair, or dataset experiment
  is introduced here.
- **Failure policy**: stop or mark unresolved/blocked, preserve the reason and
  evidence, and never silently substitute a method or rewrite a verdict.

## Validation strategy

- Fixture dataset or dry run: no biological fixture; use the generated feature
  directory and bounded text/manifests.
- Unit/contract checks: inspect the two feature contracts and required template
  fields; parse YAML/JSON with available repository tooling.
- End-to-end workflow command: `specify workflow resolve research-control` and
  a dry-run/list inspection; do not invoke a domain tool.
- Expected machine-readable evidence: preset/workflow registries, catalog,
  registry classification, and binding contract files.
- Human-observable report: `quickstart.md` command output plus a concise map;
  no domain result or release decision is produced.

## Complexity Tracking

> Fill only if the constitution check has a justified violation.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None | | |
