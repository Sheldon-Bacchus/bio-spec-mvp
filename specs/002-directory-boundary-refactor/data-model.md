# Data Model: Directory Boundary Refactor

## PathRecord

One tracked file or directory in the migration inventory.

| Field | Meaning | Invariant |
|---|---|---|
| `old_path` | path before migration | exists in the pre-move inventory |
| `new_path` | path after migration | exists in the post-move inventory |
| `owner` | runtime, control, skill, extension, example, or archive | exactly one owner |
| `kind` | source, projection, fixture, dependency, documentation, or evidence | compatible with owner |
| `content_hash` | content identity used for comparison | unchanged except path-reference edits |
| `status` | pending, moved, reference-updated, verified, or blocked | blocked records preserve failure reason |

## OwnershipBoundary

| Owner | Allowed content | Not allowed |
|---|---|---|
| `official-runtime` | root `.specify/`, `.agents/`, `specs/` | concrete source fixtures outside their expected runtime role |
| `control` | generic preset/workflow/registry/map sources | fixed project name, dataset path, MultiQC input, domain execution step |
| `skill` | adapter Skills, reference stack, runtime projections, catalog, archives | automatic workflow sequencing or project outputs |
| `extension` | independently installable command packages and scripts | implicit membership in generic workflow |
| `example` | concrete fixture and optional dependency for a named domain example | generic package contract |
| `archive` | prior work, evaluation, review, and historical evidence | active installation source |

## RegistryRecord

An installed or source registry entry that can be checked after the move.

- `id`: stable package/extension/workflow identifier;
- `source_path`: repository-relative source path where the registry exposes one;
- `installed_projection`: path under `.specify/` when applicable;
- `enabled`: runtime availability flag;
- `manifest_hash`: package content identity when supplied by the CLI.

## MigrationState

```text
planned
  → inventoried
  → collision-free
  → moved
  → references-updated
  → runtime-reregistered
  → verified
```

Any failed assertion transitions the affected record or migration to `blocked`;
the failure is retained until repaired and rechecked. No state transition
deletes source evidence.
