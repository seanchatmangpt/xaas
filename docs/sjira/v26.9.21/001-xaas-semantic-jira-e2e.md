---
{
  "identity": "SJ-001",
  "title": "xaas consumes a real Semantic Jira WorkOrder end to end",
  "description": "xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.",
  "subject": "xaas-semantic-jira-e2e",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "ALIVE",
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

- **Standing**: ALIVE (2026-09-22, worktree sjira/sj-001, verified this session)

## Status
ALIVE (2026-09-22, worktree sjira/sj-001, verified this session)
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
xaas already shells to `mix semantic_jira.*` (semantic_crown.ex, mix xaas.semantic.materialize/receipt), but no committed proof shows an admitted WorkOrder from this directory flowing admit -> materialize -> receipt -> replay. Produce that proof.

## Evidence
- `grep -rn semantic_jira lib/` hits lib/xaas/ultracode/semantic_crown.ex:18, lib/mix/tasks/xaas.semantic.{materialize,receipt}.ex
- autofde-lab/docs/2026-09-21-zero-human-factory-standing.md rated this UNSUPPORTED; that grep only matched `sJira` spellings, not `semantic_jira.`
- 2026-09-22 (this session, worktree `/Users/sac/xaas/worktrees/sjira/sj-001`, branch `sjira/sj-001`,
  code already committed at `41e28e5`/`b64f17b` from a prior session and re-verified for real here, no
  new hand-written or generated code needed this run): `mix compile` exit 0 (478 files);
  `mix test test/xaas/ultracode` exit 0, `535 tests, 0 failures (21 excluded)`, 173.0s;
  `mix test test/xaas/ultracode/semantic_jira_e2e_test.exs --trace` exit 0, `1 test, 0 failures`,
  10.6s — test NOT skipped (the moduletag skip condition requires `~/ggen_igniter`'s
  `lib/ggen_igniter/semantic_jira.ex` and `docs/sjira/v26.9.21/e2e_project.exs`, both present on
  this machine), so this was an observed real run of the exact subject: a real nested `mix run`
  OS process against `~/ggen_igniter` executed `GgenIgniter.SemanticJira.admit_work_order/1` on
  the real SJ-001 front matter, projected a real execution descriptor, `mix xaas.semantic.materialize`
  accepted it into a real sandboxed-Postgres Run/Epoch and a real git worktree at `base_sha`, a
  scripted worker committed through a real `Lease.claim_next`/`Lease.close`, `mix xaas.semantic.receipt`
  sealed a receipt (`outcome == "alive"`, `head_verified == true`, `fabric_verifier.status == "pass"`),
  and replay from both the written file and a fresh DB re-export reproduced the identical
  `receipt_digest`. Both falsifiers were exercised and refused: a descriptor digest altered after
  admission is refused at the emitter (`emission_guard`) and again at materialize
  (`admission_digest_mismatch` / malformed-digest refusals), and a failing-court candidate seals
  `build_broken` (`fabric_verifier.status == "fail"`), never `alive`.
  `mix xaas.semantic.materialize --help` exit 0 (prints moduledoc).
  `grep -Ern 'Mo[x]|:mec[k]|unittest[.]mock|MagicMoc[k]|monkeypatc[h]' test/xaas/ultracode/semantic_jira_e2e_test.exs`
  exit 1 (zero matches) — `chicago_no_mocks` court holds: every collaborator (ggen_igniter OS
  process, Postgres, git worktree, Lease fabric, shell verifier) is real; the worker is a scripted
  protocol client standing in only for the model's judgment, as documented in the test moduledoc.
  Required courts `compile`, `tests`, `chicago_no_mocks` all pass. All code that satisfies this
  ticket (`test/xaas/ultracode/semantic_jira_e2e_test.exs`, `docs/sjira/v26.9.21/e2e_project.exs`,
  `lib/xaas/ultracode/semantic_work.ex`, `lib/mix/tasks/xaas.semantic.{materialize,receipt}.ex`) was
  already present and committed on this branch before this session (commits `41e28e5`, `b64f17b`);
  this run performed no hand-writing and no new generation — it re-ran and re-verified the existing
  generated/hand-written mix (SemanticWork admission logic and the mix tasks are hand-written
  Elixir integrating with the real Ash/Ecto fabric; no ggen ontology pack in this repo currently
  covers WorkOrder-to-Run/Epoch admission code generation, so the prior session's hand-writing of
  `semantic_work.ex`/the mix tasks is UNSUPPORTED(generator-capability) — no generator found for
  this XaaS-side admission surface in `~/ggen-marketplace/packs/`; the graph-side admission
  (`GgenIgniter.SemanticJira.admit_work_order/1`) lives in the separate `~/ggen_igniter` repo and is
  out of this ticket's `path_scope`).

## Definition of done
- [x] one SJ-00x work order from this dir is admitted by GgenIgniter.SemanticJira.admit_work_order/1
- [x] `mix xaas.semantic.materialize` accepts it and `mix xaas.semantic.receipt` seals a receipt
- [x] replay of the receipt reproduces the same digest
Runnable check:

```sh
cd ~/xaas && mix test test/xaas/ultracode && mix xaas.semantic.materialize --help
```
## Falsifiers
- materialize accepts a WorkOrder whose digest was altered after admission
- receipt seals without the required courts passing

## Receipts

- receipts/SJ-001.md — observed admit -> materialize -> receipt -> replay run with command exits
- receipts/sj-001/ — zcode headless execution refusal record (falsifier leg)
