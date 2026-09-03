# Feature Specification: Repository Directory Boundary Refactor

**Feature Branch**: `002-directory-boundary-refactor`

**Created**: 2026-09-03

**Status**: Implemented

**Input**: Reorganize the complete repository layout so the official Spec Kit
runtime, generic control packages, domain Skills, independent Extensions,
concrete examples, and historical work are separate and discoverable.

## Research framing

<!-- Keep this section about what is being investigated, not which tool will be used. -->

- **Scientific question**: Not applicable to this repository-architecture
  change; the feature changes file ownership and discovery boundaries rather
  than producing a scientific result.
- **Hypothesis**: A directory layout that mirrors runtime ownership will reduce
  accidental coupling between generic Spec Kit control files, domain execution,
  examples, and historical review material.
- **Primary estimand**: The observable migration outcome is the set of tracked
  paths and registered source paths after the move, together with successful
  Spec Kit resolution from a clean repository checkout.
- **Scope and population**: All tracked files in this independent
  `bio-spec-005-research-core` repository; the root-level Spec Kit runtime and
  existing feature artifacts remain in scope for reference updates.
- **Claim boundary**: This feature may claim that repository boundaries and
  references are internally consistent and that the official local runtime
  resolves its generic packages. It must not claim that any Bio method,
  MultiQC result, review, or scientific conclusion is valid.
- **Known unknowns**: The exact upstream Spec Kit release remains an external
  environment choice. The existing historical work package is preserved as
  evidence and is not rewritten into an active workflow.

## Target directory contract

The repository MUST expose the following top-level ownership boundaries:

```text
bio-spec-005-research-core/
├── .specify/                         # installed official runtime and registries
├── .agents/skills/                   # Codex discovery/runtime projections
├── specs/                            # official feature artifacts
├── control/                          # generic, reusable Spec Kit control sources
│   ├── preset/
│   ├── workflow/
│   ├── command-registry.yml
│   ├── command-map.md
│   └── README.md
├── skills/                           # Bio Skill source, references, catalog, archives
│   ├── adapters/
│   ├── reference-stack/
│   ├── original-sop/                 # separately retained SOP source collection
│   ├── runtime-projection/
│   ├── archives/
│   ├── skill-catalog.yml
│   ├── MANIFEST.md
│   └── README.md
├── extensions/                       # independently installable Extension sources
│   ├── bio-multiqc/
│   └── bio-review/
├── examples/                         # concrete domain fixtures and optional deps
│   └── bio-multiqc/
│       ├── fixtures/
│       └── requirements.txt
├── archive/                          # historical/reference material only
│   └── 005-work-package/
└── README.md
```

The root-level `.specify/`, `.agents/`, and `specs/` directories are official
runtime or feature-entry locations and MUST NOT be replaced by the new source
layer names. Review, score, repair, compression services, and future data
experiments are not new runtime directories in this feature. Existing Skill
zip archives are source archives and belong under `skills/archives/`; they are
not an execution or review subsystem.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Navigate the independent project by ownership (Priority: P1)

As a user opening the independently downloaded project, I can tell which files
are official runtime files, reusable control sources, domain Skills,
Extensions, examples, and historical material without reading every README.

**Why this priority**: The current numeric directories put unrelated lifecycle
and execution concerns side by side, which is the primary source of the
repeated “why is this concrete project in the generic kit?” confusion.

**Independent Test**: From the repository root, inspect the tracked top-level
directories and verify each target ownership boundary exists, each old mixed
source directory is absent, and no review/score/repair runtime directory has
been introduced.

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** a user opens `README.md`, **Then** the
   displayed tree and links point to `control/`, `skills/`, `extensions/`,
   `examples/`, and `archive/005-work-package/`.
2. **Given** the source tree, **When** a user looks for a generic preset or
   workflow, **Then** it is under `control/` and contains no concrete project
   fixture or fixed domain execution step.
3. **Given** a historical review or work-package artifact, **When** a user
   follows its link, **Then** it remains available under `archive/005-work-package/`
   and is not presented as an active runtime entry point.

### User Story 2 - Install and resolve the control sources (Priority: P1)

As a maintainer, I can reinstall the generic preset/workflow and either
independent Extension from the new source paths using the official CLI, and
the installed registries remain consistent with those source files.

**Independent Test**: Run the official preset, workflow, and Extension add/list/
resolve checks from the repository root after the move.

**Acceptance Scenarios**:

1. **Given** `control/preset` and `control/workflow` exist, **When** the
   official CLI installs them in development mode, **Then** `research-control`
   resolves and its registry source paths refer to `control/`.
2. **Given** `extensions/bio-multiqc` and `extensions/bio-review` exist, **When**
   the official CLI reinstalls them, **Then** both commands remain registered
   without becoming steps in the generic workflow.
3. **Given** the new tree, **When** `specify check` and
   `specify integration status` run, **Then** they pass without requiring a
   root-level concrete project directory.

### User Story 3 - Preserve history while isolating concrete examples (Priority: P2)

As a reviewer, I can distinguish historical evidence and concrete domain
fixtures from reusable package sources, while all internal links and catalogs
continue to identify their new paths.

**Independent Test**: Run a bounded stale-path scan over tracked text files,
parse all YAML/JSON registries, and verify the Skill catalog resolves every
source path under `skills/`.

**Acceptance Scenarios**:

1. **Given** the old `01-spec-work-package` content, **When** it is moved,
   **Then** it is preserved under `archive/005-work-package/` with its files
   and evidence intact.
2. **Given** the MultiQC fixture and optional dependency file, **When** they are
   moved, **Then** they are under `examples/bio-multiqc/` and are referenced
   only by the concrete Extension/example documentation.
3. **Given** the Skill catalog, **When** a planner looks up an adapter or
   reference component, **Then** its `source_path` resolves under `skills/`
   and the catalog remains lookup metadata rather than an automatic workflow.

### Edge Cases

- A destination directory already exists: stop before moving anything and
  report the exact collision; do not merge unrelated contents implicitly.
- A tracked document still contains an old path: fail the migration check and
  repair the reference before committing.
- The CLI registry retains an old source path: reinstall or update the
  registry through the official command, then re-run resolution checks.
- A generated local cache appears under `.specify/extensions/.cache/`: keep it
  ignored and out of version control; it is not part of the repository layout.
- An example is mistaken for a generic workflow input: preserve the example
  under `examples/` and verify that the generic workflow has no example path,
  MultiQC input, or concrete Skill binding.
- A concurrent source collection is added at the repository root: move it under
  `skills/` and record it as source-only until its contracts and verifiers are
  reviewed; do not register or execute it implicitly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST retain root-level `.specify/`, `.agents/`, and
  `specs/` as the official runtime and feature-entry locations.
- **FR-002**: Generic preset, workflow, command registry, command map, and
  package-source documentation MUST be owned by `control/`.
- **FR-003**: Skill source, reference-only components, runtime projections,
  catalog, manifest, source archives, and the separately retained
  `original-sop/` source collection MUST be owned by `skills/`.
- **FR-004**: Independently installable Extension source trees MUST be owned by
  `extensions/` and MUST remain separate from the generic workflow source.
- **FR-005**: Concrete domain fixtures and their optional dependencies MUST be
  owned by `examples/<domain>/` and MUST NOT be generic preset/workflow inputs.
- **FR-006**: Historical work packages and review/evaluation evidence MUST be
  owned by `archive/` and MUST NOT be treated as active runtime sources.
- **FR-007**: All tracked documentation, catalogs, manifests, registry source
  paths, and command examples MUST be updated so no obsolete source path is
  required for normal use.
- **FR-008**: The migration MUST preserve file contents and Git-tracked
  evidence, except for deterministic path/reference updates required by the
  new locations.
- **FR-009**: The official CLI MUST be able to check the project and resolve the
  generic preset/workflow and installed Extensions after the migration.
- **FR-010**: The generic control workflow MUST remain lifecycle-only
  (`specify → plan → tasks → implement → converge`); this feature MUST NOT add
  MultiQC, project-specific data processing, review, score, repair, compression,
  or experiment steps.

### Key Entities *(repository entities)*

- **Official runtime**: Root-level `.specify/`, `.agents/`, and `specs/` entries
  consumed by Spec Kit/Codex.
- **Control source**: A reusable generic preset, workflow, registry, or map
  under `control/`.
- **Skill source**: A domain capability, reference-only component, projection,
  catalog, or source archive under `skills/`.
- **Extension source**: An independently installable command package under
  `extensions/`.
- **Example**: A concrete domain fixture or optional dependency under
  `examples/`.
- **Historical artifact**: Preserved prior work and review evidence under
  `archive/`.

## Research acceptance criteria

| ID | Criterion | Evidence artifact or validation command | Failure action |
|---|---|---|---|
| DIR-001 | The target top-level ownership tree exists and old mixed source directories are absent | `git ls-files` plus bounded path assertions | Stop before commit and repair the move |
| REF-001 | No tracked operational document requires an obsolete source path | `rg` stale-path scan | Repair references before commit |
| CLI-001 | Official runtime and package resolution pass after source relocation | `specify check`, `specify integration status`, list/resolve commands | Reinstall affected package through official CLI |
| BND-001 | Generic control source contains no concrete example or domain execution input | bounded scan of `control/` and installed generic files | Remove the leakage and re-run checks |
| HIS-001 | Historical work package and evaluation evidence remain present and out of active source paths | file-count/hash/path inventory | Restore missing content from Git move before commit |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh repository listing separates official runtime, control,
  Skills, Extensions, examples, and archive without relying on numeric folder
  names.
- **SC-002**: Every tracked reference to the migrated source directories is
  either updated to the new path or explicitly retained as historical text;
  zero operational stale-path hits remain.
- **SC-003**: The official CLI passes project checks and resolves the generic
  `research-control` preset/workflow from the reorganized source tree.
- **SC-004**: The generic workflow remains free of concrete MultiQC/example
  inputs and fixed domain Skill bindings.
- **SC-005**: The historical work package, Skill sources, and concrete fixture
  contents remain available after the move.

## Assumptions and non-goals

- The repository is the independent project at
  `E:/all-agent-workspace/codex-projects/bio-skills/bio-spec-005-research-core`;
  the outer `bio-spec-kit` workspace is not modified by this feature.
- The user-approved generic names are `control`, `skills`, `extensions`,
  `examples`, and `archive`; existing `bio-*` namespaces are unchanged.
- Official runtime directories remain where Spec Kit expects them; this is a
  source/evidence layout refactor, not a replacement of the Spec Kit CLI.
- This feature does not redesign the nine command-map entries, rewrite the
  scientific work package, create a new project workflow, run a public dataset,
  or implement compression, total review, scoring, repair, or experiment
  facilities.
