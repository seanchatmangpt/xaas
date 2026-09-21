---
{
  "identity": "SJ-001",
  "title": "xaas consumes a real Semantic Jira WorkOrder end to end",
  "description": "xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.",
  "subject": "xaas-semantic-jira-e2e",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "PARTIAL_ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-001",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "one SJ-00x work order from this dir is admitted by GgenIgniter.SemanticJira.admit_work_order/1",
    "`mix xaas.semantic.materialize` accepts it and `mix xaas.semantic.receipt` seals a receipt",
    "replay of the receipt reproduces the same digest"
  ],
  "falsifiers": [
    "materialize accepts a WorkOrder whose digest was altered after admission",
    "receipt seals without the required courts passing"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "lib/xaas/ultracode/**",
    "lib/mix/tasks/xaas.semantic.*",
    "test/xaas/ultracode/**",
    "docs/sjira/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-001: xaas consumes a real Semantic Jira WorkOrder end to end

- **Standing**: PARTIAL_ALIVE
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.

## Evidence
- `grep -rn semantic_jira lib/` hits lib/xaas/ultracode/semantic_crown.ex:18, lib/mix/tasks/xaas.semantic.{materialize,receipt}.ex
- autofde-lab/docs/2026-09-21-zero-human-factory-standing.md rated this UNSUPPORTED; that grep only matched `sJira` spellings, not `semantic_jira.`

## Definition of done
- [ ] one SJ-00x work order from this dir is admitted by GgenIgniter.SemanticJira.admit_work_order/1
- [ ] `mix xaas.semantic.materialize` accepts it and `mix xaas.semantic.receipt` seals a receipt
- [ ] replay of the receipt reproduces the same digest

Runnable check:

```sh
cd ~/xaas && mix test test/xaas/ultracode && mix xaas.semantic.materialize --help
```

## Falsifiers
- materialize accepts a WorkOrder whose digest was altered after admission
- receipt seals without the required courts passing
