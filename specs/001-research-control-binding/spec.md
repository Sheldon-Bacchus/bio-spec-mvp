# Feature Specification: Generic Research Control and Binding

**Feature Branch**: `001-research-control-binding`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "Separate the generic Spec Kit research control plane from domain-specific skills and extensions, and make plan/task skill bindings explicit."

## Research framing

<!-- This feature specifies a reusable control plane; it does not specify a biological study. -->

- **Scientific question**: Can one domain-independent Spec Kit preset preserve the research question, evidence boundary, and reproducibility requirements while allowing a plan to select the appropriate domain capability later?
- **Hypothesis**: Delaying concrete Skill selection until planning, then freezing the selection in tasks, will keep the control artifacts reusable without hiding the method, inputs, outputs, or failure behavior used by an implementation.
- **Primary estimand**: Not applicable to a biological experiment. The feature is evaluated by the proportion of generated control artifacts that satisfy the binding and separation acceptance criteria below.
- **Scope and population**: The independent `bio-spec-005-research-core` Spec Kit project and its generic preset, workflow, command registry, Skill catalog conventions, and existing domain extensions.
- **Claim boundary**: This feature may claim that the repository separates generic control artifacts from domain-specific execution artifacts and records explicit bindings. It must not claim that any biological method, dataset, or MultiQC run is scientifically valid merely because the control artifacts are valid.
- **Known unknowns**: A future project may use any domain Skill or extension that satisfies the binding contract. This feature does not choose the Skill for a future research question and does not standardize personal phase labels such as `research-pre`, `research-process`, or `research-post`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a domain-independent research feature (Priority: P1)

As a repository maintainer, I want the standard Spec Kit feature artifacts to be generated from a generic research preset so that a new feature starts with a research question, constraints, and acceptance criteria rather than a hidden project or tool.

**Why this priority**: If the preset or workflow is already tied to a concrete project, every later feature inherits the wrong scope and the control plane cannot be reused.

**Independent Test**: Resolve the generic preset and inspect a generated feature's `spec.md`, `plan.md`, and `tasks.md`; the files contain the generic research sections and no hardcoded MultiQC, dataset, project path, or specific Skill binding.

**Acceptance Scenarios**:

1. **Given** a clean Spec Kit project with the generic preset enabled, **When** a maintainer creates a feature for an arbitrary research capability, **Then** the canonical artifacts are created as `spec.md`, `plan.md`, and `tasks.md` in one feature directory.
2. **Given** the generic control workflow is inspected, **When** its inputs and steps are listed, **Then** they contain only the Spec Kit control lifecycle and do not require a domain tool, dataset, output directory, or release verdict belonging to one project.
3. **Given** a concrete domain extension is installed, **When** the generic preset is resolved, **Then** the extension is not silently promoted to a required preset binding.

---

### User Story 2 - Select and freeze a capability binding (Priority: P1)

As a planner, I want to search the available research Skills by capability and record the selection in the plan, so that the task list can freeze exactly what will be invoked without making the generic preset a fixed list of Skills.

**Why this priority**: The separation between reusable control and concrete scientific method is the central correctness property of the architecture.

**Independent Test**: Use a synthetic capability request with at least one catalog candidate and inspect the resulting plan/task binding records for the required fields and failure behavior.

**Acceptance Scenarios**:

1. **Given** a plan has a named capability but no selected implementation, **When** planning is performed, **Then** the plan records the capability, candidate/selected Skill, selection reason, required inputs, outputs, verifier, and failure policy, or explicitly records that clarification is required.
2. **Given** a plan has selected a Skill, **When** tasks are generated, **Then** every executable task that depends on that capability freezes `skill_id`, `preset_id` (when applicable), `inputs`, `outputs`, `dependencies`, `verifier`, `acceptance`, and `failure_behavior`.
3. **Given** no catalog candidate satisfies a required capability or the candidate metadata is incomplete, **When** task generation is attempted, **Then** the workflow fails closed or marks the task as blocked; it does not substitute an unspecified generic Agent behavior.
4. **Given** several candidates are plausible, **When** the planner chooses one, **Then** the choice and its scientific/operational reason remain visible in `plan.md` and are traceable from the task.

---

### User Story 3 - Extend the system without contaminating the control plane (Priority: P2)

As a domain maintainer, I want Skills and Extensions to remain independently installable and auditable, so that adding a method-specific script or reference set does not change the generic Spec Kit lifecycle.

**Independent Test**: Inspect the source and installed manifests after the change; a domain extension can be resolved independently, while the generic preset/workflow remain free of its project-specific parameters.

**Acceptance Scenarios**:

1. **Given** a Skill consists primarily of Markdown instructions with references and supporting scripts, **When** it is cataloged, **Then** it remains a domain Skill and is not represented as a Spec Kit lifecycle stage.
2. **Given** an Extension supplies commands, configuration, or tool-execution scripts, **When** it is installed, **Then** it is discoverable as an optional domain integration with its own inputs, outputs, and failure behavior.
3. **Given** the existing MultiQC vertical slice, **When** the generic control artifacts are inspected, **Then** the slice is kept as a separately scoped example/extension and is not a required step of the generic workflow.

---

### User Story 4 - Navigate the selected command set without mislabeling it (Priority: P2)

As a reviewer or maintainer, I want one concise command map that distinguishes the official lifecycle from project-selected optional quality commands, so that the nine entries are easy to navigate without claiming that Spec Kit defines a universal fixed nine-stage taxonomy.

**Independent Test**: Read the registry and human map and verify that exactly six entries are marked core, three are marked optional quality control, and the canonical command names remain the official `speckit-*` names.

**Acceptance Scenarios**:

1. **Given** the command registry is loaded, **When** entries are grouped by role, **Then** the core group contains `constitution`, `specify`, `plan`, `tasks`, `implement`, and `converge`.
2. **Given** optional quality control is needed, **When** a maintainer consults the map, **Then** `clarify`, `checklist`, and `analyze` are shown as insertable optional commands rather than mandatory lifecycle stages.
3. **Given** a user sees the human-readable labels, **When** they invoke a command, **Then** the mapping points to the canonical `speckit-*` command/Skill and does not create a second competing artifact naming system.

### Edge Cases

- Missing or invalid capability metadata: keep the binding unresolved and report the missing field; never silently select a domain method.
- A domain Skill uses a non-`bio-*` namespace: preserve the existing identifier in this feature; namespace normalization is explicitly outside scope.
- A domain extension needs a concrete path or tool: keep those values in the extension/task invocation contract, not in the generic preset or generic workflow inputs.
- A reviewer wants compression, aggregate review, scoring, repair, or external experiment execution: those remain separate facilities and are not added to the project control plane by this feature.
- A historical work package already contains a concrete project slice: preserve it as historical/reference material unless a later, separately specified migration moves it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The generic preset MUST define only reusable artifact structure, terminology, research metadata, provenance, acceptance, and failure-policy conventions; it MUST NOT bind a specific dataset, project path, domain tool, MultiQC run, or Skill.
- **FR-002**: The feature MUST preserve the canonical Spec Kit artifact names `spec.md`, `plan.md`, and `tasks.md` within one feature directory.
- **FR-003**: The project command map MUST distinguish a project-selected set of six core commands (`constitution`, `specify`, `plan`, `tasks`, `implement`, `converge`) from three optional quality-control commands (`clarify`, `checklist`, `analyze`), and MUST state that this is not an official universal nine-stage taxonomy.
- **FR-004**: The plan artifact MUST provide a structured capability-binding record containing at least `capability_id`, candidate/selected Skill information, `preset_id` when applicable, selection reason, execution phase/label, inputs, outputs, verifier, and failure policy.
- **FR-005**: The task artifact MUST provide a structured execution-binding record containing at least `task_id`, `skill_id`, `preset_id` when applicable, inputs, outputs, dependencies, verifier, acceptance, and failure behavior.
- **FR-006**: Planning MUST be able to discover candidate Skills from the available catalog or project Skill inventory by capability and contract metadata; the generic preset MUST NOT contain a fixed list that combines all available domain Skills.
- **FR-007**: A selected Skill MUST remain a narrow Markdown-led capability with its references and supporting scripts; an Extension MUST remain the boundary for commands, configuration, tool adapters, or execution scripts. Neither may be silently treated as a lifecycle stage.
- **FR-008**: The generic workflow MUST run the official control lifecycle without requiring parameters that belong to one concrete project or method. Domain execution MUST be reached through explicit plan/task bindings or a separately invoked Extension.
- **FR-009**: Concrete MultiQC execution, project-specific fixtures, release-verdict recording for that slice, and other domain examples MUST remain outside the generic control workflow and generic preset.
- **FR-010**: Compression, aggregate review, scoring, repair, and future data-level experiments MUST remain outside this feature's project runtime; this feature MUST NOT add them as core commands, preset bindings, or workflow steps.
- **FR-011**: Personal phase labels such as `research-pre`, `research-process`, and `research-post` MUST NOT become required architecture layers or Spec Kit commands; a task MAY carry an opaque project-defined phase/label.
- **FR-012**: If a required capability cannot be mapped to a complete Skill/Extension contract, planning or task generation MUST fail closed or record an explicit unresolved/blocked state with a reason.
- **FR-013**: Binding records MUST preserve provenance sufficient to identify the selected Skill/Extension version or source, relevant parameters, and input/output artifacts when execution occurs.
- **FR-014**: This feature MUST NOT require a `bio-*` namespace migration; existing identifiers remain valid until a separate naming change is approved.

### Key Entities

- **Control Command**: A canonical Spec Kit command with an official machine identifier, a role (`core` or `optional_quality_control`), and a placement rule.
- **Generic Preset**: A reusable set of artifact templates and control policies with no concrete domain binding.
- **Capability Binding**: A plan-level record that maps a research capability to candidate/selected Skills or Extensions and explains the choice.
- **Task Binding**: A task-level record that freezes the exact implementation capability, contract, dependencies, verification, acceptance, and failure behavior.
- **Skill Contract**: The documented Markdown-led interface of a narrow domain capability, including references and supporting scripts.
- **Extension Contract**: The documented interface for a command, configuration, tool adapter, or execution script that is independently installed and scoped.

## Research acceptance criteria

| ID | Criterion | Evidence artifact or validation command | Failure action |
|---|---|---|---|
| QC-001 | Generic preset and workflow contain no concrete MultiQC/project binding | Source manifest scan and `specify preset resolve` / `specify workflow resolve` | Do not accept; remove the domain binding from the generic layer |
| QC-002 | Plan and task templates expose the complete binding fields | Template inspection plus generated-feature smoke check | Do not accept; restore the missing field or fail closed |
| QC-003 | Registry has six core and three optional QC entries without calling them universal official stages | Registry parse and map review | Do not accept; correct classification and wording |
| VAL-001 | Existing `speckit-*` control Skills and independently installed domain Extensions remain resolvable | `specify preset list`, `specify workflow list`, and extension status commands | Report the broken install and do not release |
| VAL-002 | Review/score/repair/test facilities are absent from the generic project runtime | Bounded path and manifest scan | Remove the accidental project-runtime addition in a follow-up task |
| REL-001 | Canonical feature artifacts, binding contracts, provenance rules, and scope exclusions are documented | `spec.md`, `plan.md`, `tasks.md`, `data-model.md`, and `quickstart.md` review | Do not mark the feature converged |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clean feature can be generated with canonical `spec.md`, `plan.md`, and `tasks.md` artifacts, and a static scan finds zero hardcoded concrete-domain inputs in the generic preset/workflow.
- **SC-002**: The plan template exposes all required capability-binding fields, and the task template exposes all required execution-binding fields; no required field is represented only by prose.
- **SC-003**: The command registry contains exactly six core entries and three optional quality-control entries, while retaining the nine canonical `speckit-*` command identifiers.
- **SC-004**: A capability with an eligible catalog candidate can be traced from plan selection to a task binding without consulting an undocumented fixed preset list.
- **SC-005**: An incomplete or ambiguous capability contract produces an explicit unresolved/blocked state rather than an implicit Skill or generic Agent fallback.
- **SC-006**: The existing MultiQC Extension remains independently discoverable, but the generic preset/workflow has zero required MultiQC parameters or execution steps.
- **SC-007**: No compression, aggregate review, score, repair, or future experiment facility is added under the project’s core preset, workflow, command registry, or `speckit-*` control Skills.

## Assumptions and non-goals

- The official Spec Kit command identifiers and canonical artifact names remain the source of truth for execution; the project registry is a navigation/classification layer.
- The six-plus-three grouping is a project decision for this repository, not a claim about a universal Spec Kit taxonomy.
- The current domain Skill inventory and Extensions are available for later plan-time discovery; this feature does not combine all available Skills into one fixed workflow.
- `research-pre`, `research-process`, and `research-post` remain optional user/project labels and are not standardized here.
- The inconsistent existing `bio-*` naming is intentionally left unchanged.
- Review, score, repair, compression, and data-level experiment workflows will be designed as separate facilities in later features and are not imported into this project runtime.
- The historical `archive/005-work-package` remains available as reference material; this feature does not rewrite its scientific work package.
- Real public datasets, Hugging Face execution, biological validity, performance benchmarking, and production release testing are non-goals for this architecture feature.
