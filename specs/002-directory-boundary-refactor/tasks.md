# Tasks: Repository Directory Boundary Refactor

**Input**: Design documents from
`specs/002-directory-boundary-refactor/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`,
`contracts/directory-boundary.schema.yml`, and `quickstart.md`.

**Format**: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel without touching the same files.
- **[Story]**: User story label; `[FOUNDATION]` is shared work.
- Every executable task names exact paths, a verifier, and failure behavior in
  the binding table below.

## Task Binding Contract

This is a repository-maintenance feature. No domain Skill is selected; the
binding records that explicitly so a path move cannot be mistaken for a Bio
execution step.

| task_id | phase | skill_id | preset_id | inputs | outputs | dependencies | verifier | acceptance | failure_behavior | provenance |
|---|---|---|---|---|---|---|---|---|---|---|
| T001 | setup | blocked: no domain Skill required | research-control | repository root, Git status | verified target repository/revision | none | `git status --short --branch` | target repo is clean enough to scope the change | stop and report unrelated/overlapping changes | feature 002, current revision |
| T002 | setup | blocked: no domain Skill required | research-control | current tracked tree, migration map | pre-move path inventory | T001 | `rg --files` and exact path assertions | every current source is classified once | stop before creating destinations | feature 002 `research.md` |
| T003 | setup | blocked: no domain Skill required | research-control | target paths, boundary contract | collision check | T002 | `Test-Path` assertions | no destination collides with existing content | stop; never merge implicitly | contract `directory-boundary.schema.yml` |
| T004 | setup | blocked: no domain Skill required | research-control | spec, plan, research, contract, quickstart | implementation gate | T001-T003 | bounded placeholder/contract review | design documents are complete and consistent | block implementation until repaired | feature 002 design set |
| T005 | layout | blocked: no domain Skill required | research-control | `archive`, `control`, `skills`, `extensions`, `examples` destinations | empty destination parents | T003-T004 | exact `Test-Path` and directory listing | only approved destination parents are created | stop and preserve pre-move tree | migration map |
| T006 | layout | blocked: no domain Skill required | research-control | `01-spec-work-package/` | `archive/005-work-package/` | T005 | `git diff --find-renames`, file inventory | all historical files remain reachable under archive | stop and restore via Git move | migration map |
| T007 | layout | blocked: no domain Skill required | research-control | `02-skills/` | `skills/` | T005 | `git diff --find-renames`, catalog path check | adapters, reference stack, projection, archives, docs all move intact | stop before reference edits | migration map |
| T008 | layout | blocked: no domain Skill required | research-control | generic parts of `03-package-sources/`, `suites/README.md` | `control/` sources and command map | T005 | target file assertions and YAML parse | generic control sources are grouped under control | stop; do not leave duplicate source copies | migration map |
| T009 | layout | blocked: no domain Skill required | research-control | `03-package-sources/extensions/` | root `extensions/` | T005 | Extension manifest/command path assertions | both independent Extensions are root-level sources | stop; do not fold them into control | migration map |
| T010 | layout | blocked: no domain Skill required | research-control | root fixture and dependency file | `examples/bio-multiqc/fixtures/`, `examples/bio-multiqc/requirements.txt` | T005 | exact example path assertions | concrete example assets are isolated from generic sources | stop and preserve example files | migration map |
| T011 | US1 | blocked: no domain Skill required | research-control | moved READMEs and root README | ownership documentation and tree | T006-T010 | link/path scan | a new user can identify each owner from root and local docs | block until docs match actual tree | spec US1 |
| T012 | US1 | blocked: no domain Skill required | research-control | tracked Markdown/YAML/JSON references | updated repository-relative paths | T006-T011 | bounded stale-path scan | no operational link requires an old source path | preserve failing scan and repair references | spec FR-007 |
| T013 | US1 | blocked: no domain Skill required | research-control | `archive/`, `examples/` boundaries | boundary README files | T006, T010 | file existence and content review | archive/example purpose is explicit and non-runtime | block commit if ownership is ambiguous | spec US1/US3 |
| T014 | US2 | blocked: no domain Skill required | research-control | `.specify/workflows/workflow-registry.json` | registry source path for `research-control` | T008, T012 | JSON parse and source assertion | registry no longer points to `03-package-sources` | stop and repair registry | spec FR-009 |
| T015 | US2 | blocked: no domain Skill required | research-control | `control/preset`, `control/workflow`, `extensions/*` | re-registered `.specify` projections | T012, T014 | official `specify` add/list/resolve commands | all identifiers remain available from new source paths | keep failure output; do not claim completion | spec US2 |
| T016 | US2 | blocked: no domain Skill required | research-control | installed runtime projections | updated `.agents/skills` and `.specify` command docs | T015 | Extension command/list checks | independent commands remain registered and runnable at their boundary | stop on missing projection or stale command | spec FR-004/FR-009 |
| T017 | US2 | blocked: no domain Skill required | research-control | generic source and installed projections | boundary scan result | T015-T016 | `rg` control-boundary scan | no MultiQC/example/project/review execution leaks into generic layer | remove leakage and rerun | spec FR-010 |
| T018 | US3 | blocked: no domain Skill required | research-control | `skills/skill-catalog.yml`, moved Skills | corrected catalog source paths | T007, T012 | YAML parse plus path existence assertions | all 13 catalog entries resolve under `skills/` | preserve missing-path failure | spec US3 |
| T019 | US3 | blocked: no domain Skill required | research-control | pre/post tracked path sets and moved files | preservation verification | T006-T010 | `git diff --find-renames`, counts, hashes where unchanged | no historical, Skill, Extension, or fixture content is lost | stop and repair the move | spec FR-008 |
| T020 | US3 | blocked: no domain Skill required | research-control | all YAML/JSON registries/contracts | parse/shape validation result | T012, T014, T018 | PyYAML/JSON parse script | all checked metadata parses and required IDs remain | block completion on malformed metadata | contract and quickstart |
| T021 | US3 | blocked: no domain Skill required | research-control | root and local README links | documentation consistency result | T011-T013 | `rg` path scan and link review | displayed tree matches tracked tree and install commands | repair docs before release | spec SC-001/SC-002 |
| T022 | US3 | blocked: no domain Skill required | research-control | `.gitignore`, generated cache | repository hygiene result | T015 | `git status --short`, ignored-path check | cache remains ignored/untracked; no generated noise is added | stop and remove only generated untracked noise if safe | spec edge cases |
| T023 | US3 | blocked: no domain Skill required | research-control | all implementation changes | final command evidence | T017-T022 | `specify check`, integration, list/resolve, `git diff --check` | all required checks pass | preserve failure and do not commit as complete | quickstart.md |
| T024 | US3 | blocked: no domain Skill required | research-control | checklist and completed implementation | checked acceptance checklist | T023 | checklist review against evidence | all CHK-001..CHK-022 are satisfied | leave unchecked item visible and block convergence | feature checklist |
| T025 | convergence | blocked: no domain Skill required | research-control | spec, plan, tasks, implementation, validation | convergence assessment | T024 | official `speckit-converge` review | no actionable boundary gap remains, or a traceable convergence phase is recorded | preserve actionable gap; do not silently waive | official converge stage |
| T026 | post-merge-layout | blocked: no domain Skill required | research-control | concurrent `orginal-sop-skills/` source collection | `skills/original-sop/` source collection and boundary docs | T025 | exact path assertions and source-only scan | no unowned top-level Skill source remains and 11 components are preserved | stop and keep the concurrent source visible | post-merge remote commit |
| T027 | post-merge-convergence | blocked: no domain Skill required | research-control | updated spec, plan, tasks, tree, and registries | final convergence assessment | T026 | official `speckit-converge` review plus CLI/boundary checks | no actionable directory-boundary gap remains after merge | preserve the gap and do not claim completion | post-merge feature 002 |

## Phase 1: Setup

- [x] T001 Verify the target repository, current revision, and worktree scope; preserve the status output for the implementation record.
- [x] T002 Build the pre-move tracked path inventory against the exact migration map in `plan.md`.
- [x] T003 Check every destination for collisions before creating or moving anything.
- [x] T004 Review the feature design set and confirm that no domain Skill or concrete project workflow is selected.

## Phase 2: Layout migration

**Goal**: Make the ownership boundaries visible in the filesystem while
preserving all tracked content.

**Independent Test**: The target directories exist, old mixed source
directories do not, and `git diff --find-renames` shows the expected moves.

- [x] T005 Create only the approved destination parent directories after the collision gate passes.
- [x] T006 Move `01-spec-work-package/` to `archive/005-work-package/` with Git tracking preserved.
- [x] T007 Move `02-skills/` to `skills/` with its adapters, reference stack, runtime projections, archives, catalog, and docs intact.
- [x] T008 Move the generic preset, workflow, command registry, package README, and suite map into `control/` with the registry/map names made explicit.
- [x] T009 Move `03-package-sources/extensions/` to root `extensions/` without changing Extension IDs.
- [x] T010 Move the concrete MultiQC fixture and optional dependency file into `examples/bio-multiqc/`.

## Phase 3: User Story 1 - Navigate by ownership (Priority: P1) 🎯 First independently testable slice

**Goal**: A clean checkout communicates the boundary between official runtime,
generic control, Skills, Extensions, examples, and archive.

**Independent Test**: Read `README.md`, `control/README.md`, `skills/README.md`,
and the new archive/example docs; all displayed paths exist.

- [x] T011 [US1] Update the root and moved ownership documentation to show the target tree and the official root runtime locations.
- [x] T012 [US1] Update all operational repository-relative references from old source paths to their new owners; retain only justified historical comparison text.
- [x] T013 [US1] Add concise `archive/README.md` and `examples/README.md` boundary notes that explicitly exclude them from generic runtime execution.

## Phase 4: User Story 2 - Reinstall and resolve packages (Priority: P1)

**Goal**: Official CLI registration continues to work from the reorganized
source paths, with Extensions remaining optional and independent.

**Independent Test**: Run the official list/resolve/check commands in
`quickstart.md` and confirm the generic workflow has no example input.

- [x] T014 [US2] Update `.specify/workflows/workflow-registry.json` and any installed source metadata to the new `control/` path.
- [x] T015 [US2] Re-register the generic preset/workflow and both independent Extensions from `control/` and `extensions/` using the official CLI.
- [x] T016 [US2] Verify the installed `.specify` projections and `.agents/skills` command entries remain available without introducing a fixed domain sequence.
- [x] T017 [US2] Run the bounded generic-control scan and remove any concrete project, MultiQC, example, review, score, repair, or experiment leakage found there.

## Phase 5: User Story 3 - Preserve history and catalog integrity (Priority: P2)

**Goal**: Historical evidence, Skill source material, and concrete examples are
still reachable, while catalogs and metadata point to the new tree.

**Independent Test**: Parse metadata, resolve catalog paths, compare the moved
file inventory, and run the stale-path scan.

- [x] T018 [US3] Update `skills/skill-catalog.yml` and related Skill/Extension documentation so every source path resolves under the new owner.
- [x] T019 [US3] Verify preservation of historical, Skill, Extension, and fixture content with rename-aware Git diff and bounded inventory/hash checks.
- [x] T020 [US3] Parse the directory contract and all affected YAML/JSON registries, catalogs, manifests, and metadata.
- [x] T021 [US3] Verify root/local README links, install commands, and displayed tree agree with the actual tracked paths.
- [x] T022 [US3] Verify `.specify/extensions/.cache/` remains ignored and no generated cache or unrelated artifact is staged.
- [x] T023 [US3] Run the complete validation set from `quickstart.md`, including `specify check`, integration status, list/resolve checks, boundary scans, and `git diff --check`.
- [x] T024 [US3] Mark the requirements checklist only from the validation evidence and confirm CHK-001 through CHK-022.

## Phase 6: Initial Convergence

- [x] T025 Run the official convergence assessment after implementation; if no actionable gap exists, leave the task list unchanged by convergence and report the result.

## Phase 7: Post-merge source normalization

**Goal**: Keep a concurrently added Skill source collection inside the explicit
`skills/` ownership boundary without registering or executing it implicitly.

**Independent Test**: `skills/original-sop/` contains the 11 source components,
the misspelled remote top-level directory is absent, and the current catalog/
generic workflow remain unchanged.

- [x] T026 Move the concurrent `orginal-sop-skills/` tree to `skills/original-sop/`, clean its README boundary statement, and update the root/Skill/feature documentation.
- [x] T027 Run the post-merge official convergence assessment and confirm the current catalog remains 13 entries while the 11 SOP sources stay source-only.

## Dependencies and execution order

- T001-T004 are the setup gate; no destination is created before T003 passes.
- T005 enables T006-T010; the layout moves complete before reference rewrites.
- T006-T013 establish the independently testable navigation slice.
- T014-T017 depend on the new control/Extension paths and restore runtime
  registration before final validation.
- T018-T024 verify catalog, preservation, metadata, docs, hygiene, and runtime.
- T025 runs after the original implementation tasks and their verifiers pass.
- The concurrent remote addition triggered T026; T027 is the final convergence
  gate after that post-merge normalization.

## Parallel execution examples

After T005, T006, T007, T009, and T010 touch disjoint source directories and
could be performed independently in a scripted migration, but this run keeps
the Git moves sequential so the rename diff and failure point stay easy to
audit. Documentation and registry changes are also intentionally sequenced
after moves to avoid referencing paths that do not yet exist.

## Implementation strategy

1. Complete the collision and classification gate.
2. Perform only the exact migration map with recoverable Git moves.
3. Repair repository-relative references and ownership documentation.
4. Re-register source packages through the official CLI and verify runtime
   projections.
5. Run preservation, stale-path, boundary, parse, and CLI checks.
6. Run initial convergence; if a concurrent source changes the tree, normalize
   it under the same ownership contract and run post-merge convergence again.
