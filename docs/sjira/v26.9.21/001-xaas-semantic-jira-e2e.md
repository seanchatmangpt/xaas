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

The JSON front matter above is the graph-admitted work-order snapshot: its digest
(`sha256:4e0458934ec42dcc4953107d1fde191cc2ab2cb27f33fcf0804a30bfa6b91dda`) is the
subject of the proof, so it is left byte-identical, including its `standing` input.
Observed standing is recorded here and in the receipt, never by editing the snapshot.

- **Observed standing**: PARTIAL_ALIVE (exact subject ALIVE; one producer path unbound, see Status)
- **Front-matter standing (admitted input, unchanged)**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE. Receipt: `receipts/SJ-001.md`; evidence: `receipts/sj-001/`.

- ALIVE, observed: admit -> materialize -> receipt -> replay for this work order, and both
  falsifiers refused, with the `compile` court a real `mix compile`.
- Not closed: the real `mix semantic_jira.descriptor` producer emits a graph-wide
  `graph_digest` and no `admitted_work_order`, so for that shape XaaS cannot recompute a
  per-work-order digest (`--binding auto` cannot bind it; only the bridge's own snapshot digest
  is cross-checked). Closing it needs the graph emitter to send the admitted snapshot.

## Repository
seanchatmangpt/xaas @ `8e72cfc` (order `base_sha`).

## Description
xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.

## Evidence
- `grep -rn semantic_jira lib/` hits lib/xaas/ultracode/semantic_crown.ex:18, lib/mix/tasks/xaas.semantic.{materialize,receipt}.ex
- autofde-lab/docs/2026-09-21-zero-human-factory-standing.md rated this UNSUPPORTED; that grep only matched `sJira` spellings, not `semantic_jira.`
- `receipts/SJ-001.md` and `receipts/sj-001/evidence/*.json`: real admission digest, materialize output, sealed receipt, replay, and two negative controls

## Definition of done
- [x] one SJ-00x work order from this dir is admitted by GgenIgniter.SemanticJira.admit_work_order/1 (`evidence/admit.json`, digest `sha256:4e04589...1dda`)
- [x] `mix xaas.semantic.materialize` accepts it and `mix xaas.semantic.receipt` seals a receipt (`evidence/materialize.json`, `evidence/receipt.json`, outcome `alive`, `head_verified` true)
- [x] replay of the receipt reproduces the same digest (`evidence/replay.json`; SA2A replay `verified: true`, `sj-001/sa2a-replay.txt`)

Runnable check:

```sh
cd ~/xaas && mix test test/xaas/ultracode && mix xaas.semantic.materialize --help
```

Narrow proof (what this order's guard exercises):

```sh
MIX_TEST_PARTITION=sj001g mix test test/xaas/ultracode/semantic_work_test.exs \
  test/xaas/ultracode/semantic_jira_e2e_test.exs test/xaas/ultracode/semantic_tasks_help_test.exs
```

## Falsifiers
- materialize accepts a WorkOrder whose digest was altered after admission: refused at
  `SemanticWork.admit/2` (`Xaas.Ultracode.SemanticWork.AdmissionBinding`) for probes A
  (`graph_digest` altered, envelope kept), B (envelope omitted), C (`graph_digest` and envelope
  altered together), D (every anchor stripped, `--binding snapshot`) and E (admitted snapshot
  edited); each with a typed reason, asserted in `semantic_work_test.exs` and against the real
  producer's descriptor in `semantic_jira_e2e_test.exs`. Residual: a descriptor with no anchor
  at all admitted under the default `--binding auto` (see Status).
- receipt seals without the required courts passing: refused for a candidate that fails the
  `tests` court (`evidence/control.json`, `build_broken`) and for a candidate that does not
  compile (`evidence/compile_broken.json`, `build_broken`, failed by the real `mix compile`).
