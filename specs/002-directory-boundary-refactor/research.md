# Research Notes: Directory Boundary Refactor

## Question

Which repository paths are owned by the official Spec Kit runtime, which are
reusable control sources, which are domain capability sources, and which are
only examples or historical evidence? The migration must change those
boundaries without changing the generic workflow contract or losing tracked
content.

## Evidence inspected

- The repository root contains `.specify/`, `.agents/`, and `specs/`; the
  installed workflow registry points to the local generic workflow source and
  the official scripts resolve feature directories below `specs/`.
- `01-spec-work-package/` contains a completed historical specification,
  contracts, evaluation cases/runs, and review evidence. It is not an active
  package source and must be preserved as archive material.
- `02-skills/` contains five adapter sources, eight reference-only components,
  five runtime projections, a lookup catalog, manifests, and zip archives. The
  contents represent capability/reference ownership, not an execution
  workflow.
- `03-package-sources/` contains the generic preset, generic workflow,
  command registry, two independent Extension sources, and package-source
  documentation. Its name hides the different ownership boundaries.
- `tests/fixtures/multiqc/` and the root `requirements.txt` are concrete
  MultiQC example assets. They are not generic tests or generic workflow
  inputs.
- `suites/README.md` is a human command map and belongs with the generic
  control registry rather than as a peer runtime layer.
- `.specify/extensions/.cache/` is ignored generated state. It must remain
  ignored and must not be promoted into the tracked source tree.
- A concurrent remote commit added `orginal-sop-skills/` as a top-level source
  collection containing 11 `SKILL.md`-led components. A top-level Skill source
  would violate the ownership tree, so it is normalized to
  `skills/original-sop/` while keeping its content and Skill IDs.

## Options considered

### Keep the numeric directories

Rejected. The names `01`, `02`, and `03` encode an accidental sequence and make
historical work, Skills, package sources, and concrete Extensions look like
three stages of one runtime. That representation directly causes the boundary
confusion this feature is intended to remove.

### Put every source under one `packages/` directory

Rejected. It would still conflate the generic control plane with callable
domain capabilities and independently installable Extensions. A maintainer
would need to inspect file content to learn ownership.

### Use explicit ownership directories

Selected:

- `control/` owns reusable generic preset/workflow/registry/map sources.
- `skills/` owns Skill sources, reference stack, runtime projections, catalog,
  manifest, and source archives.
- `extensions/` owns independent installable Extension sources.
- `examples/` owns concrete fixtures and optional example dependencies.
- `archive/` owns historical work packages and their evidence.

The official runtime locations remain at the root because the local Spec Kit
scripts and Codex discovery expect `.specify/`, `.agents/`, and `specs/` there.

## Migration decisions

1. Use `git mv` for tracked directory/file moves so the change remains
   recoverable and Git can recognize continuity.
2. Perform deterministic reference updates after the moves. Update catalogs,
   READMEs, feature documentation, Extension example paths, and installed
   workflow source metadata; do not rewrite historical scientific content
   beyond path references required for navigation.
3. Reinstall the generic preset/workflow and both Extensions through the
   official CLI from their new source paths. The installed `.specify` copies
   remain runtime projections and are not relocated into source directories.
4. Delete no material. The old top-level source directories disappear only
   because all tracked contents move to their explicit owners.
5. Do not create directories for review, score, repair, compression services,
   or data experiments. Existing Skill zip files are retained under
   `skills/archives/` as source archives only.
6. Keep the concurrent SOP collection under `skills/original-sop/` as
   source-only material. Do not add it to the current 13-entry catalog or
   `.agents/skills/` until each component has a complete contract, verifier,
   dependency review, and an explicit feature selection.

## Risks and controls

| Risk | Control |
|---|---|
| A stale old path remains in an operational document | bounded `rg` scan over tracked text and explicit allowlist for historical text |
| Installed registry still points to the old workflow source | official CLI re-add followed by registry/source assertion |
| Generic control source acquires a concrete example path | scan `control/` and installed generic files for example/MultiQC/project bindings |
| A historical file is lost during the move | pre/post file inventory and content hash comparison |
| A generated cache is accidentally committed | preserve `.gitignore` rule and inspect `git status` |
| Runtime projection is mistaken for a second Skill source | document source vs projection ownership and compare catalog paths |

## Open choices intentionally left unresolved

- The upstream Spec Kit version is an environment/release-management choice,
  not a directory-layout decision.
- Whether a future project should use one of the Bio adapter Skills is decided
  by that feature's `plan.md` and `tasks.md`; this refactor does not select one.
