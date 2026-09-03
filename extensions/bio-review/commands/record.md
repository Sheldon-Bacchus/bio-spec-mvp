---
description: "Record a human review decision"
---

# Review record

Persist the decision, reviewer, timestamp, evidence paths, and reason. A
rejection or waiver must explain what happens next. The record is part of the
run evidence and should be committed or archived with the report.

## Extension contract

- **Inputs**: an explicit `approve`, `reject`, or `waive` decision; reviewer
  identity; timestamp; evidence paths; and a reason or next action.
- **Outputs**: one append-only review record that preserves the decision and
  evidence references.
- **Failure behavior**: stop when the decision, reviewer, evidence, or reason is
  missing; never turn an absent decision into approval.
- **Ownership**: this Extension records a human decision. It does not choose a
  scientific method, calculate a score, repair a result, or become a generic
  Spec Kit lifecycle step.

User request:

$ARGUMENTS
