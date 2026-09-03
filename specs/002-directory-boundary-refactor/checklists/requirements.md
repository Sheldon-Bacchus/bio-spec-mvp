# Directory Refactor Requirements Checklist

## Boundary

- [x] CHK-001 Root `.specify/`, `.agents/`, and `specs/` remain in their official locations.
- [x] CHK-002 Generic preset/workflow/registry/map sources are under `control/`.
- [x] CHK-003 Skill sources, references, projections, catalog, manifest, and archives are under `skills/`.
- [x] CHK-004 Independent Extension sources are under root `extensions/`.
- [x] CHK-005 Concrete MultiQC fixture and optional dependency are under `examples/bio-multiqc/`.
- [x] CHK-006 Historical work package and evidence are under `archive/005-work-package/`.
- [x] CHK-007 No review, score, repair, or experiment runtime directory was created.

## References and runtime

- [x] CHK-008 No operational document requires `01-spec-work-package`, `02-skills`, or `03-package-sources`.
- [x] CHK-009 Skill catalog source paths resolve under `skills/`.
- [x] CHK-010 Source package installation commands use `control/` and `extensions/`.
- [x] CHK-011 Installed workflow registry does not retain the old workflow source path.
- [x] CHK-012 `specify check` passes.
- [x] CHK-013 `specify integration status` passes.
- [x] CHK-014 Generic preset/workflow resolve and list checks pass.
- [x] CHK-015 Both independent Extensions remain listable and registered.

## Preservation and quality

- [x] CHK-016 Historical files and concrete fixture contents are present after the move.
- [x] CHK-017 `git diff --check` has no new whitespace errors.
- [x] CHK-018 YAML/JSON registries and the boundary contract parse successfully.
- [x] CHK-019 Generated Extension cache remains ignored and untracked.
- [x] CHK-020 The root README and ownership READMEs show the same target tree.
- [x] CHK-021 The concurrent SOP source collection is under `skills/original-sop/` and remains source-only.
- [x] CHK-022 No `orginal-sop-skills/` top-level directory or implicit SOP workflow registration remains.
