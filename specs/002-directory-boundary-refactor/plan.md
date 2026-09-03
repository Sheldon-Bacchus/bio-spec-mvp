# Implementation Plan: Repository Directory Boundary Refactor

**Branch**: `002-directory-boundary-refactor` | **Date**: 2026-09-03 | **Spec**:
[`spec.md`](spec.md)

## Summary

Replace the ambiguous numeric source layout with explicit ownership directories
while preserving the official Spec Kit entry points. The implementation uses
tracked Git moves, deterministic reference updates, official CLI reinstallation
from the new source paths, and bounded structural/registry/content checks.
The generic `research-control` preset and workflow remain lifecycle-only; the
directory change does not select or execute a domain Skill.

## Technical Context

**Language/Version**: Markdown, YAML, JSON, PowerShell; existing Python/R
fixtures are preserved without method changes.

**Primary Dependencies**: The repository's bundled Spec Kit PowerShell scripts,
the installed `specify-cli`, existing Codex integration, and existing local
YAML/JSON parsing tools.

**Storage**: Git-tracked filesystem paths; `.specify` registries and installed
projections; no database or object store.

**Testing**: `specify check`, `specify integration status`, preset/workflow/
Extension list and resolve commands, YAML/JSON parsing, file inventory/hash
comparison, `git diff --check`, and bounded `rg` stale-path/boundary scans.

**Target Platform**: Windows PowerShell from the repository root; the layout
must remain usable after an independent GitHub checkout.

**Project Type**: Spec Kit project containing documentation, package sources,
Codex Skills, Extensions, fixtures, and historical research-engineering
artifacts.

**Constraints**: Keep `.specify/`, `.agents/`, and `specs/` at the root; preserve
tracked content; do not change existing `bio-*` namespaces; do not put concrete
MultiQC/project inputs in generic control sources; do not create review/score/
repair/experiment runtime layers; keep generated caches ignored.

**Scale/Scope**: All tracked files under the current numeric source directories,
the root fixture/dependency file, the suite map, affected docs, and the
installed registry/source-path projections. No scientific algorithm or result
is changed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Evidence before automation: **PASS** — the migration has an inventory,
  pre/post file evidence, and bounded stale-path checks; it makes no scientific
  claim.
- Domain contracts first: **PASS** — preset, workflow, Skill, and Extension
  contracts remain in their owners; the move does not invent a domain binding.
- Deterministic execution and provenance: **PASS** — exact source/destination
  paths, Git moves, registry checks, and repository revision are recorded.
- Human quality/release gates: **PASS** — a stale-path, collision, hash, or CLI
  failure blocks completion and remains visible.
- Small, testable, composable skills: **PASS** — callable Skills and Extensions
  remain separate, and the catalog stays lookup metadata.

## Research design and analysis contract

- **Question and estimand**: Which paths own runtime, control, capability,
  extension, example, and historical artifacts? Estimand: the post-migration
  path/registry state and successful resolution from a clean checkout.
- **Study/sample unit**: One Git-tracked repository revision; each moved file is
  an inventory unit, with directories treated as ownership boundaries.
- **Inputs and reference identity**: Current `main` revision `d8721bf`, current
  tracked path inventory, `.specify` registries, and the feature specification.
- **Variables, controls, and covariates**: Old path, new path, ownership class,
  tracked-content hash, registry source path, and whether a file is runtime,
  source, example, or archive.
- **QC thresholds and failure actions**: Zero unapproved operational stale-path
  hits; zero missing/extra tracked content; zero destination collisions; all
  official CLI checks pass. Any failure stops completion.
- **Statistical or decision procedure**: Deterministic set equality and content
  hash comparison, registry parse/resolve assertions, and bounded text scans;
  no statistical inference is made.
- **Validation and claim boundary**: Validate repository structure and package
  resolution only. Do not infer scientific validity from a successful move.

## Capability and Skill Selection

This feature is repository maintenance. No domain capability is selected. The
existing catalog remains unchanged and is only checked for updated source paths.

| capability_id | candidate_skill_ids | skill_id | preset_id | selection_reason | phase/label | inputs | outputs | verifier | failure_policy | provenance | status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| repository-structure-migration | empty | empty | research-control | no domain execution is required | migration | tracked paths and registries | reorganized tracked paths and registries | path inventory, hash, CLI, and stale-path checks | stop on collision or failed check | feature `002-directory-boundary-refactor` | not-selected |

## Pipeline and execution design

```text
specify → plan → tasks → implement
                         ├─ inventory and collision gate
                         ├─ tracked moves and reference repair
                         ├─ official CLI source re-registration
                         └─ structural, boundary, and runtime validation
                  → converge
```

Spec Kit remains the coordination layer. The migration itself is a bounded
filesystem and registry operation; it does not invoke MultiQC, a Bio analysis,
or a fixed sequence of the 13 domain components.

## Project Structure

### Documentation (this feature)

```text
specs/002-directory-boundary-refactor/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── directory-boundary.schema.yml
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source and evidence (repository root)

```text
.specify/                         # official installed runtime; fixed root entry
.agents/skills/                   # Codex discovery/runtime projections
specs/                            # official feature directories
control/                          # generic control sources
├── preset/
├── workflow/
├── command-registry.yml
├── command-map.md
└── README.md
skills/                           # Skill sources and source archives
├── adapters/
├── reference-stack/
├── original-sop/                 # concurrent source-only SOP collection
├── runtime-projection/
├── archives/
├── skill-catalog.yml
├── MANIFEST.md
└── README.md
extensions/                       # independent Extension sources
examples/bio-multiqc/             # concrete fixture and optional dependency
archive/005-work-package/         # historical work package and evidence
```

**Structure Decision**: Use semantic ownership directories instead of numeric
stage directories. `control/` is deliberately narrower than `skills/` and
`extensions/`: generic sources can be installed by the control layer, while a
domain Skill or Extension is selected only by a feature plan/task. Concrete
fixtures are visible under `examples/`, and historical evaluation/review files
are visible under `archive/`. The official `.specify/`, `.agents/`, and
`specs/` locations remain unchanged.

### Exact migration map

| Current path | New path | Ownership reason |
|---|---|---|
| `01-spec-work-package/` | `archive/005-work-package/` | historical work package and evidence |
| `02-skills/` | `skills/` | Skill sources, references, projections, catalog, archives |
| `orginal-sop-skills/` | `skills/original-sop/` | concurrent SOP source collection, not auto-registered |
| `03-package-sources/preset/` | `control/preset/` | generic preset source |
| `03-package-sources/workflow/` | `control/workflow/` | generic lifecycle workflow source |
| `03-package-sources/suite-registry.yml` | `control/command-registry.yml` | generic command map registry |
| `03-package-sources/README.md` | `control/README.md` | control-source documentation |
| `03-package-sources/extensions/` | `extensions/` | independently installable Extension sources |
| `suites/README.md` | `control/command-map.md` | human map for the control registry |
| `tests/fixtures/multiqc/` | `examples/bio-multiqc/fixtures/` | concrete domain fixture |
| `requirements.txt` | `examples/bio-multiqc/requirements.txt` | optional concrete example dependency |

## Provenance and review gates

- **Inputs**: repository root, current Git revision, exact source/destination
  map, tracked file list, and `.specify` registry files.
- **Outputs**: new tracked paths, updated references, updated registry source
  metadata, and feature validation evidence.
- **Runtime**: Windows PowerShell, `specify-cli` version already installed,
  repository revision, command output, and `git diff`/status.
- **Review gates**: destination collision gate; content inventory/hash gate;
  generic-boundary gate; official CLI registry gate; final convergence gate.
- **Failure policy**: stop on the first failed gate, preserve the failure output,
  repair the smallest bounded set of files, and rerun all dependent checks.

## Validation strategy

- **Fixture dataset or dry run**: no scientific dataset; use the existing
  MultiQC fixture only to assert it is isolated under `examples/`.
- **Unit/contract checks**: parse `directory-boundary.schema.yml`, registries,
  and catalog; assert every catalog source path exists under `skills/`.
- **End-to-end workflow command**: `specify check`, `specify integration status`,
  `specify preset resolve spec-template`, `specify workflow resolve
  research-control`, and Extension list/command checks.
- **Expected machine-readable evidence**: path inventory, old-to-new mapping
  assertions, registry JSON/YAML parse success, and zero stale operational hits.
- **Human-observable report**: root README tree plus concise `control/`,
  `skills/`, `extensions/`, `examples/`, and `archive/` READMEs/links.

## Complexity Tracking

No constitution violation. The number of moves is large because the requested
change is a repository-wide boundary correction, but each move is mechanical,
recoverable, and independently validated.
