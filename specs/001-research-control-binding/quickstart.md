# Quickstart: Validate Generic Research Control and Binding

Run these commands from the repository root after implementation. They validate
the control plane and metadata only; they do not run a biological dataset or a
MultiQC analysis.

## 1. Verify the active feature artifacts

```powershell
$feature = (Resolve-Path .\specs\001-research-control-binding).Path
Test-Path "$feature\spec.md"
Test-Path "$feature\plan.md"
Test-Path "$feature\tasks.md"
```

Expected: all three commands return `True`.

## 2. Verify the generic source package

```powershell
rg -n "multiqc|fastqc|tests/fixtures|\.bio/runs|component_contract_bindings|skill_path" `
  .\control\preset\preset.yml `
  .\control\preset\contracts `
  .\control\preset\templates `
  .\control\workflow\workflow.yml
```

Expected: no output. Concrete domain references may remain under the separate
extension source and historical `archive/005-work-package`, not the generic files
listed above.

## 3. Verify the binding fields

```powershell
rg -n "capability_id|candidate_skill_ids|skill_id|preset_id|selection_reason|inputs|outputs|verifier|failure_policy|failure_behavior|provenance" `
  .\control\preset\templates\plan-template.md `
  .\control\preset\templates\tasks-template.md `
  .\specs\001-research-control-binding\contracts
```

Expected: every required capability/task binding field is present in the
template or its contract.

## 4. Verify the six-plus-three command map

```powershell
rg -n "core|optional_quality_control|constitution|specify|plan|tasks|implement|converge|clarify|checklist|analyze" `
  .\control\command-registry.yml .\control\command-map.md
```

Expected: six entries are `core`, three entries are
`optional_quality_control`, and the documentation says this is not a universal
official nine-stage taxonomy.

## 5. Verify installed resolution

```powershell
specify preset list
specify preset resolve spec-template
specify workflow list
specify workflow resolve research-control
specify extension list
```

Expected: `research-control` resolves as the generic preset/workflow; the
MultiQC and review Extensions, if installed, are listed independently and are
not required workflow inputs.

## 6. Verify no project-runtime pollution

```powershell
$generic = @(
  '.\control\preset\preset.yml',
  '.\control\preset\contracts',
  '.\control\preset\templates',
  '.\control\workflow\workflow.yml',
  '.\.specify\presets\research-control\preset.yml',
  '.\.specify\presets\research-control\contracts',
  '.\.specify\presets\research-control\templates',
  '.\.specify\workflows\research-control\workflow.yml',
  '.\control\command-registry.yml'
)
$generic += @(
  '.\.agents\skills\speckit-constitution',
  '.\.agents\skills\speckit-specify',
  '.\.agents\skills\speckit-clarify',
  '.\.agents\skills\speckit-plan',
  '.\.agents\skills\speckit-tasks',
  '.\.agents\skills\speckit-implement',
  '.\.agents\skills\speckit-converge',
  '.\.agents\skills\speckit-checklist',
  '.\.agents\skills\speckit-analyze'
)
rg -n --hidden --glob '!\.git/**' `
  "review-score|research-score|aggregate-review|huggingface|multiqc_input|multiqc_output|multiqc_config|fastqc" `
  $generic
```

Expected: no hits in the generic preset, workflow, registry, or
`speckit-*` control Skills. Generic failure-policy prose may mention that a
future repair is external; this scan is checking for concrete runtime
facilities and domain parameters. Historical and separately scoped Extension
files are intentionally outside `$generic`.
