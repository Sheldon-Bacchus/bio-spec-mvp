# Quickstart: Verify the Reorganized Project

Run these commands from the repository root after implementation.

## 1. Inspect the ownership tree

```powershell
Get-ChildItem -Force
rg --files control skills extensions examples archive specs .specify .agents
```

The source layer must contain `control/`, `skills/` (including
`skills/original-sop/`), `extensions/`, `examples/`, and `archive/`; the
official runtime remains at `.specify/`, `.agents/`, and `specs/`.

## 2. Check official runtime and package resolution

```powershell
specify check
specify integration status
specify preset list
specify preset resolve spec-template
specify workflow list
specify workflow resolve research-control
specify extension list
```

If a source package was reinstalled during implementation, the registry should
still contain `research-control`, `bio-multiqc`, and `bio-review` with the same
identifiers and updated manifest hashes where applicable.

## 3. Verify the generic boundary

```powershell
rg -n -i "multiqc_input|multiqc_output|multiqc_config|fastqc|huggingface|bio-research-mvp|tests/fixtures|review-score|research-score|aggregate-review|repair_service|repair_step|run_repair" control .specify/presets/research-control .specify/workflows/research-control
```

The generic control source and installed generic projections must not contain
concrete example inputs, project-specific bindings, or review/score/repair
execution steps. Generic failure-policy prose may mention recording a repair or
waiver; the scan targets executable facility names. Any other intentional
documentation mention should be evaluated against the feature boundary and not
ignored silently.

## 4. Verify stale paths and content preservation

```powershell
rg -n --hidden --glob '!\.git/**' --glob '!\.specify/extensions/.cache/**' "01-spec-work-package|02-skills|03-package-sources|orginal-sop-skills|tests/fixtures/multiqc|suites/README|^requirements\.txt$" .
git status --short
git diff --check
```

The old paths may appear only in the new feature's migration evidence when a
historical comparison is necessary. Operational links, catalogs, registries,
and command examples must use the new paths.

## 5. Confirm the concrete example remains isolated

```powershell
Test-Path .\examples\bio-multiqc\fixtures\sample_fastqc\fastqc_data.txt
Test-Path .\examples\bio-multiqc\requirements.txt
Test-Path .\extensions\bio-multiqc\extension.yml
Test-Path .\control\workflow\workflow.yml
```

The first two paths are concrete example assets; they are not inputs to the
generic `research-control` workflow. The `skills/original-sop/` collection is
also source-only until its individual contracts and verifiers are reviewed.
