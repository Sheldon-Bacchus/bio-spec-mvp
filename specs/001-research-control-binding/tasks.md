---
description: "Dependency-ordered tasks for separating generic Spec Kit control from domain bindings"
---

# Tasks: Generic Research Control and Binding

**Input**: Design documents from `specs/001-research-control-binding/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/`, and `quickstart.md`.

**Tests**: No biological or domain execution tests are requested. Validation is
limited to text-contract checks, bounded scans, YAML/JSON parsing, and official
Spec Kit list/resolve commands.

**Binding rule**: The generic preset selects no concrete Skill. The task
binding register below binds this implementation work to the control Skill
`speckit-implement` (and validation to `speckit-converge`) while using
`research-control` only as the generic artifact preset. Future research
features must replace these control bindings with their own plan-time selected
domain bindings.

## Phase 1: Setup

**Purpose**: Establish the feature scope and preserve the official project
artifact conventions before changing runtime sources.

- [x] T001 [P] Inspect `specs/001-research-control-binding/spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`; confirm the implementation scope and evidence paths.
- [x] T002 [P] Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` with `SPECIFY_FEATURE_DIRECTORY` set to `specs/001-research-control-binding`; record the resolved feature directory and available documents.
- [x] T003 [P] Record the current `git status --short --branch`, installed preset/workflow registries, and extension list as the pre-change baseline in the implementation session output.

## Phase 2: Foundational contracts

**Purpose**: Establish generic source contracts before installing or documenting
the corrected runtime.

- [x] T004 Remove concrete `component_contract_bindings` and project-specific Skill references from `03-package-sources/preset/preset.yml`; set the generic preset identity to `research-control` and verify the manifest contains only reusable templates/policies.
- [x] T005 Update `03-package-sources/preset/contracts/research-core-profile.yml` so it defines generic ownership boundaries without `multiqc`, `bulk-pa-luad`, dataset paths, or concrete component bindings; verify with a bounded `rg` scan.
- [x] T006 Add explicit capability discovery and selection fields to `03-package-sources/preset/templates/plan-template.md`: `capability_id`, candidate/selected `skill_id`, `preset_id`, selection reason, phase/label, inputs, outputs, verifier, failure policy, and provenance.
- [x] T007 Add an executable-task binding section to `03-package-sources/preset/templates/tasks-template.md` with `task_id`, `phase`, `skill_id`, `preset_id`, inputs, outputs, dependencies, verifier, acceptance, failure behavior, and provenance while retaining the official checklist format.
- [x] T008 Add `02-skills/skill-catalog.yml` as a lookup index for the five callable adapter Skills; mark reference-stack material as non-executable reference data and do not create a fixed execution sequence.
- [x] T009 Replace the concrete MultiQC steps and inputs in `03-package-sources/workflow/workflow.yml` with a generic `research-control` control workflow that invokes the feature lifecycle only; do not add domain execution, compression, score, repair, or experiment steps.

## Phase 3: User Story 1 - Create a domain-independent research feature (Priority: P1) 🎯 MVP

**Goal**: The installed preset and workflow are generic and preserve the
canonical Spec Kit artifact lifecycle.

**Independent Test**: `specify preset resolve spec-template` resolves the
`research-control` template; `specify workflow resolve research-control` resolves
the control-only workflow; neither source or installed manifest requires a
MultiQC/project input.

- [x] T010 [US1] Remove the installed legacy `bio-research-mvp` preset using the official `specify preset remove` command, install `03-package-sources/preset` with `specify preset add --dev`, and verify `specify preset list` and `specify preset resolve spec-template`; evidence: `.specify/presets/.registry`.
- [x] T011 [US1] Remove the installed legacy `bio-research-mvp` workflow using the official `specify workflow remove` command, install `03-package-sources/workflow/workflow.yml` with `specify workflow add --dev`, and verify `specify workflow list` and `specify workflow resolve research-control`; evidence: `.specify/workflows/workflow-registry.json`.
- [x] T012 [US1] Update `README.md`, `03-package-sources/README.md`, and `requirements.txt` to describe `research-control` as generic, MultiQC as an independently scoped optional Extension, and the old `bio-research-mvp` vertical slice as historical/reference context only.
- [x] T013 [US1] Scan generic preset/workflow source and installed copies for `multiqc_input`, `multiqc_output`, `multiqc_config`, `fastqc`, `tests/fixtures`, `.bio/runs`, and `component_contract_bindings`; acceptance: zero hits in generic files; evidence: command output from `quickstart.md` step 2.

## Phase 4: User Story 2 - Select and freeze a capability binding (Priority: P1)

**Goal**: Planning can discover candidates without a fixed preset list, and
tasks can freeze an explicit implementation handoff.

**Independent Test**: Inspect the plan/tasks templates, catalog, and the two
feature contracts; every required binding field is represented structurally and
an unresolved candidate has an explicit blocked/failure path.

- [x] T014 [US2] Align `02-skills/skill-catalog.yml` entries with the frontmatter and contract sections of `.agents/skills/bulk-pa-luad/SKILL.md`, `.agents/skills/cross-branch-integration/SKILL.md`, `.agents/skills/multiqc/SKILL.md`, `.agents/skills/pathway-enrichment/SKILL.md`, and `.agents/skills/wgcna-module-constraint/SKILL.md`; acceptance: each entry has capability hints, inputs, outputs, contract path, and executable/reference classification.
- [x] T015 [US2] Update the plan binding guidance in `03-package-sources/preset/templates/plan-template.md` to require catalog lookup, selection rationale, and explicit `unresolved`/`blocked` status when no complete contract exists; evidence: template diff and `contracts/capability-binding.schema.yml`.
- [x] T016 [US2] Update the tasks binding guidance in `03-package-sources/preset/templates/tasks-template.md` to require a trace from each executable task to a selected capability and to preserve failures; evidence: template diff and `contracts/task-binding.schema.yml`.
- [x] T017 [US2] Run the binding-field scan from `specs/001-research-control-binding/quickstart.md` and inspect `specs/001-research-control-binding/data-model.md`; acceptance: no required field is represented only by an unstructured prose placeholder.

## Phase 5: User Story 3 - Extend without contaminating the control plane (Priority: P2)

**Goal**: Skills, reference material, and Extensions keep separate ownership
boundaries while the generic lifecycle remains domain-neutral.

**Independent Test**: `specify extension list` still shows independently
installed Extensions, while the generic preset/workflow source contains no
domain-specific execution parameters or shell call.

- [x] T018 [P] [US3] Update `02-skills/MANIFEST.md` and `02-skills/README.md` to point planners to `skill-catalog.yml`, distinguish five callable adapters from eight reference-only components, and state that neither group is an automatic workflow sequence.
- [x] T019 [P] [US3] Update `03-package-sources/extensions/bio-multiqc/extension.yml`, `03-package-sources/extensions/bio-review/extension.yml`, or their documentation only as needed to state their independent inputs/outputs/failure boundaries; do not add either Extension to the generic workflow.
- [x] T020 [US3] Verify the existing `bio-multiqc` and `bio-review` Extensions remain independently installed/resolvable after the generic preset/workflow migration; acceptance: the extension registry is unchanged except for intentional source/version metadata.

## Phase 6: User Story 4 - Navigate the six-plus-three command map (Priority: P2)

**Goal**: The registry is precise and readable without mislabeling the project
classification as an official universal Spec Kit taxonomy.

**Independent Test**: Parse/read the registry and map; exactly six entries are
`core`, exactly three are `optional_quality_control`, and every entry points to
the canonical `speckit-*` command/Skill.

- [x] T021 [P] [US4] Correct `03-package-sources/suite-registry.yml` to use stable `spec-*`, `plan-*`, `implement-*`, and `review-*` navigation IDs with explicit `role` values: six core commands (`constitution`, `specify`, `plan`, `tasks`, `implement`, `converge`) and three optional QC commands (`clarify`, `checklist`, `analyze`); state that this is not a universal official nine-stage taxonomy.
- [x] T022 [P] [US4] Rewrite `suites/README.md` as the concise human map for the same six-plus-three classification, retaining canonical `speckit-*` names and explaining that `spec.md`, `plan.md`, and `tasks.md` remain the only feature artifact names.
- [x] T023 [US4] Update the command, package, and runtime sections of `README.md` to link the corrected map and distinguish official control Skills, generic preset/workflow, domain Skills, reference material, and independently installed Extensions.

## Phase 7: Polish and convergence

**Purpose**: Validate the complete change and leave no untracked convergence
gap before handoff.

- [x] T024 [P] Run YAML/JSON parse checks for `03-package-sources/preset/preset.yml`, `03-package-sources/preset/contracts/research-core-profile.yml`, `03-package-sources/workflow/workflow.yml`, `02-skills/skill-catalog.yml`, `03-package-sources/suite-registry.yml`, `.specify/presets/.registry`, and `.specify/workflows/workflow-registry.json`; preserve failures and fix malformed files.
- [x] T025 Run every command in `specs/001-research-control-binding/quickstart.md`; acceptance: generic resolution, binding-field, six-plus-three, and no-pollution checks pass without running a domain dataset.
- [x] T026 Run `.specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` for `specs/001-research-control-binding`, review `spec.md`, `plan.md`, and `tasks.md` against the constitution, and record any remaining gap for the official `speckit-converge` pass.
- [x] T027 Run the official convergence assessment against this feature after all implementation tasks are complete; if it appends a remaining task, implement and re-run convergence until the feature is clean; evidence: final task state and convergence output.

## Dependencies and execution order

```text
T001-T003 (setup)
        ↓
T004-T009 (generic contracts and sources)
        ↓
T010-T013 (US1 installed generic control) ─┐
T014-T017 (US2 binding discovery/freeze)   ├─→ T024-T027 (validation/converge)
T018-T020 (US3 boundaries)                 │
T021-T023 (US4 command map)               ─┘
```

- T001-T003 are read-only baselines and can run in parallel.
- T004-T009 are foundational; source files with overlapping ownership run in
  listed order.
- US1 depends on the generic source contracts. US2, US3, and US4 can proceed in
  parallel after the foundational phase when they touch different files.
- T024-T027 run only after all desired user stories are complete.

## Task Binding Register

The table is the frozen handoff for this feature's implementation. `N/A` means
the task does not invoke a domain preset; it does not authorize an implicit
fallback.

| task_id | phase | skill_id | preset_id | inputs | outputs | dependencies | verifier | acceptance | failure_behavior |
|---|---|---|---|---|---|---|---|---|---|
| T001 | setup | speckit-implement | research-control | feature docs | scope confirmation | none | file inspection | scope matches spec/plan | stop and report missing doc |
| T002 | setup | speckit-implement | research-control | feature pointer, prereq script | resolved paths | none | check-prerequisites.ps1 | JSON names target feature | block until pointer fixed |
| T003 | setup | speckit-implement | N/A | registries, git state | baseline output | none | git/specify list commands | baseline captured | preserve output and stop |
| T004 | foundation | speckit-implement | research-control | preset.yml | generic preset manifest | T001-T003 | rg + YAML parse | no concrete binding keys | fail closed; do not install |
| T005 | foundation | speckit-implement | research-control | profile contract | generic ownership contract | T004 | rg + YAML parse | no component-specific entries | stop and preserve evidence |
| T006 | foundation | speckit-implement | research-control | plan template, capability contract | plan binding section | T004 | required-field scan | all plan fields present | block template release |
| T007 | foundation | speckit-implement | research-control | tasks template, task contract | task binding section | T004 | required-field scan | all task fields present | block template release |
| T008 | foundation | speckit-implement | N/A | five adapter SKILL.md files, MANIFEST | candidate index | T001 | YAML parse + path check | adapters callable, references excluded | mark entry blocked; no fallback |
| T009 | foundation | speckit-implement | research-control | concrete workflow source | control-only workflow | T004-T008 | YAML parse + pollution scan | no domain inputs/steps | do not install workflow |
| T010 | US1 | speckit-implement | research-control | source preset, CLI registry | installed generic preset | T004-T009 | specify preset list/resolve | research-control resolves | restore/stop; retain failing registry |
| T011 | US1 | speckit-implement | research-control | source workflow, CLI registry | installed generic workflow | T009 | specify workflow list/resolve | research-control resolves | restore/stop; retain failing registry |
| T012 | US1 | speckit-implement | N/A | root/package docs, requirements | corrected usage docs | T010-T011 | rg for legacy active claims | no generic MVP claim | report docs mismatch |
| T013 | US1 | speckit-implement | research-control | source/installed generic files | boundary scan output | T010-T011 | quickstart step 2 | zero concrete hits | fail closed and list paths |
| T014 | US2 | speckit-implement | N/A | adapter frontmatter/contracts | aligned catalog entries | T008 | path/field scan | each candidate is contract-complete | mark unresolved; no invocation |
| T015 | US2 | speckit-implement | research-control | plan template, capability schema | fail-closed selection guidance | T006,T014 | template/contract review | unresolved state is explicit | block plan generation |
| T016 | US2 | speckit-implement | research-control | tasks template, task schema | traceable task guidance | T007,T015 | template/contract review | task→capability trace required | block implementation handoff |
| T017 | US2 | speckit-converge | research-control | templates, data model, contracts | binding scan output | T014-T016 | quickstart step 3 | no prose-only required fields | append gap for repair |
| T018 | US3 | speckit-implement | N/A | Skill manifest/readme/catalog | source/runtime boundary docs | T008 | rg + doc review | adapter/reference split visible | stop on classification conflict |
| T019 | US3 | speckit-implement | N/A | Extension manifests/docs | independent extension contracts | T009 | manifest parse + diff | no generic workflow dependency | leave extension unchanged and report |
| T020 | US3 | speckit-implement | N/A | installed extension registry | independent resolution evidence | T010-T011,T019 | specify extension list | extensions remain discoverable | do not claim success |
| T021 | US4 | speckit-implement | N/A | suite registry | six-plus-three registry | T001-T003 | YAML parse + count | exactly 6 core/3 optional QC | stop on count/name mismatch |
| T022 | US4 | speckit-implement | N/A | suites README, registry | concise human map | T021 | map review | canonical names and disclaimer present | report documentation gap |
| T023 | US4 | speckit-implement | N/A | root README, map, package docs | aligned navigation docs | T021-T022 | rg/doc review | no competing artifact names | preserve old text and report |
| T024 | polish | speckit-converge | research-control | YAML/JSON manifests | parse evidence | T004-T023 | parser commands | all listed files parse | stop before convergence |
| T025 | polish | speckit-converge | research-control | quickstart commands | validation output | T010-T024 | quickstart.md | all architecture checks pass | preserve failing output |
| T026 | polish | speckit-converge | research-control | feature artifacts, constitution | review record | T025 | prereq + artifact review | no unresolved required gap | append explicit gap |
| T027 | polish | speckit-converge | research-control | current code and feature docs | convergence result | T026 | official convergence pass | no actionable findings | append only traceable remediation |

## Implementation strategy

1. Complete setup and generic contracts first.
2. Deliver the MVP as User Story 1: the installed preset/workflow become generic
   and the existing domain Extensions remain independent.
3. Add plan/task binding discovery and freezing as User Story 2.
4. Correct boundaries and navigation as User Stories 3 and 4.
5. Run structural validation and official convergence. No real dataset,
   compression, aggregate review, score, repair, or experiment is part of this
   feature's MVP.
