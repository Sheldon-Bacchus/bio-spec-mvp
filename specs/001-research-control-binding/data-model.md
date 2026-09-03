# Data Model: Generic Research Control and Binding

## ControlCommand

Represents one canonical Spec Kit command in the project navigation registry.

| Field | Required | Meaning |
|---|---:|---|
| `id` | yes | Stable project navigation ID, such as `spec-constitution`. |
| `official_stage` | yes | Official stage name, such as `plan`. |
| `official_command` | yes | CLI command identifier, such as `speckit.plan`. |
| `codex_skill` | yes | Compatible Skill name, such as `speckit-plan`. |
| `role` | yes | `core` or `optional_quality_control`. |
| `placement` | yes | Initialization, feature lifecycle, or insertable QC placement. |

Invariants:

- `official_command` and `codex_skill` remain the source of execution truth.
- The registry contains six `core` and three `optional_quality_control` entries.
- A registry entry does not create a second executable Skill.

## GenericPreset

Represents reusable artifact and policy templates.

| Field | Required | Meaning |
|---|---:|---|
| `id` | yes | `research-control`. |
| `templates` | yes | Spec, plan, and tasks template replacements. |
| `policies` | yes | Research metadata, provenance, acceptance, and fail-closed rules. |
| `bindings` | no | Must be absent in this generic preset. |

Invariant: no field under the preset resolves to a concrete domain Skill,
dataset, project path, tool invocation, or project-specific output directory.

## CapabilityBinding

Plan-level selection record. It describes a capability need before an execution
task is frozen.

| Field | Required | Meaning |
|---|---:|---|
| `capability_id` | yes | Stable capability identifier from the feature plan. |
| `candidate_skill_ids` | yes | Zero or more candidates found in the catalog. |
| `skill_id` | conditional | Selected Skill/Extension identifier; empty while unresolved. |
| `preset_id` | conditional | Preset needed by the selected capability, if any. |
| `selection_reason` | yes | Scientific and operational reason for the selection. |
| `phase` | yes | Opaque feature-defined execution label; not a fixed pre/process/post taxonomy. |
| `inputs` | yes | Required input artifacts and metadata. |
| `outputs` | yes | Expected output artifacts and metadata. |
| `verifier` | yes | Deterministic or human verification reference. |
| `failure_policy` | yes | Stop, block, or explicit unresolved behavior. |
| `provenance` | yes | Source/version and selection evidence. |
| `status` | yes | `unresolved`, `candidate`, `selected`, or `blocked`. |

Invariants:

- `selected` requires a complete Skill/Extension contract.
- `blocked` or `unresolved` requires a non-empty reason.
- Candidate discovery never implies execution.

## TaskBinding

Task-level handoff consumed by implementation.

| Field | Required | Meaning |
|---|---:|---|
| `task_id` | yes | The checklist task ID, for example `T012`. |
| `skill_id` | yes | Exact selected Skill or Extension identifier, or explicit `blocked`. |
| `preset_id` | conditional | Preset used by this task, if applicable. |
| `inputs` | yes | Paths, identifiers, versions, and parameters. |
| `outputs` | yes | Expected artifacts and content checks. |
| `dependencies` | yes | Predecessor task IDs and artifact dependencies. |
| `verifier` | yes | Command, contract, or evidence path that verifies the task. |
| `acceptance` | yes | Observable completion condition. |
| `failure_behavior` | yes | Stop/block/preserve verdict behavior. |
| `provenance` | yes | Source/version and run identity fields. |

Invariants:

- An executable task cannot omit `skill_id`, `verifier`, or `failure_behavior`.
- A task binding must be traceable back to one `CapabilityBinding`.
- Failure must remain visible; it cannot be converted to success by editing a
  result or silently changing the method.

## Relationships

```text
ControlCommand 1 ── classifies ──> 1 registry entry
GenericPreset  1 ── shapes ─────> many feature artifacts
CapabilityBinding 1 ── freezes into ──> 0..many TaskBinding records
TaskBinding 1 ── invokes ───────> 1 Skill or Extension contract
```
