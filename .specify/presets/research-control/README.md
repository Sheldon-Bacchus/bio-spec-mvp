# Research Control Spec Kit preset

This is a project-local generic Spec Kit preset. It keeps the official Spec
Kit artifact lifecycle and adds reusable research-control fields:

- scientific question, hypothesis, estimand, scope, and claim boundary;
- study/data design and explicit validation;
- reproducibility and explicit failure/provenance fields;
- plan-level capability discovery and Skill/Extension selection;
- task-level frozen binding, verification, and evidence paths;
- a generic Research Control ownership profile for composable Skills.

It does not replace the Spec Kit command engine, add a new state-machine
runtime, or choose a fixed list of domain Skills. It does not put Spec Kit
stages into a Skill and does not claim that generated control artifacts are
scientifically validated.

Concrete Skills and Extensions are selected by a feature's `plan.md` and frozen
in `tasks.md`; the preset itself contains no project path, dataset, tool, or
MultiQC binding. Candidate lookup is indexed separately in
`02-skills/skill-catalog.yml`.

Install it during local development with:

```powershell
specify preset add --dev .\03-package-sources\preset
specify preset resolve spec-template
```
