# W984p — Corpus evidenced-line deepening wave 4 (2 lines, 6 courts)

Lane W984p · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Build root `_build-laneW984p` — cold compile, pinned asdf toolchain
1.20.2-otp-28, `MIX_ENV=test`.

## Gap-inventory provenance

Provenance per the dispatch: receipts **w981t** (26.6 / 14.4.b / 15.5.s3)
and **w982z** (26.7 / 27.1.c+d; plus W704's 27.3) were read; their taken
lines were excluded. The evidence maps were re-read live from the on-disk
generators (`test/eu_ai_act/title_iii_test.exs` evidence_map +
deepening_map, `test/eu_ai_act/title_vi_xiii_test.exs` evidence_map +
`Deepenings.deepening/1`): every other already-EVIDENCED line in those
maps carries a deepening court EXCEPT **26.1** and **26.9** (both in the
Title III map, both absent from `deepening_map`, both absent from the
`Deepenings` module — `deepening(_id) -> :ok` fallback). No overlap with
W704/W981t/W982z or the sibling wave-4 file `art_9_4_*`/`art_133e_*`
(appeared mid-run; see disclosure below).

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 26.1 | deployer shall use the system in accordance with the instructions for use | governed actuation under human authority: real `Xaas.Actuation.run/4` DO (durable `ActuationIntent` keyed by the instruction's idempotency key + sealed hash-bearing `ActuationReceipt`) composed with the real `Xaas.Actuation.QuiescentStop.execute/2` over the SAME subject, then both real receipts enter a real `Xaas.Witness.AuditChain` (payload digests = the receipts' real `input_hash`/`result_hash`) that verifies clean and detects a real tamper | `test/xaas/deepening/art_26_1_governed_actuation_stop_chain_test.exs` (3 courts) | if the stop surface stops driving the subject (`stopped?/2` drifts so a stopped subject admits a new stop DO) or the receipts lose their hash fields, the monotone-attractor and chain-witness courts fail while `quiescent_stop_test.exs`'s typed-refusal courts and `audit_chain_test.exs`'s synthetic courts still pass |
| 26.9 | deployer use of the Art. 13 interpretability information | Art. 13 information-sufficiency laws over a REAL `DatasetAdmission` gate refusal: (a) exact Shapley attribution (`AdmissionAttribution.shapley/2`) sums to the efficiency identity v(N)−v(∅) = −1 over real gate verdicts, and the blame vanishes exactly (all φ = 0) when the real refusing input is repaired to balanced; (b) causal counterfactual with a FAITHFUL record (`Counterfactual.evaluate/3`) — repair flips the real gate (`changed?`, explanation names the check), same-input changes nothing, and an unfaithful record is refused typed `{:error, {:record_outcome_mismatch, _}}`; (c) the ordered log witnesses downstream checks past the first refusal (both-gates-fail: completeness refuses, bias verdict still recorded) | `test/xaas/deepening/art_26_9_art13_information_use_test.exs` (3 courts) | if attribution stops summing to the efficiency identity over real verdicts, `evaluate/3` stops verifying the recorded outcome, or the log stops witnessing downstream checks, these courts fail while shape/determinism courts over hand-built records still pass |

## Verification (real tails)

Cold-lane build (compile took >10 min under the 600s foreground cap, run in
background to completion). Census command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984p \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Lane files, run ×4 total across the session (seeds 308084-context,
  225546, 317930 + first two-file run): **6/6 passed, exit 0, every time.**
- Full census runs ×3 (seeds 744430, 988970, and the background run A):
  `Result: 26/30 passed` — the **4 failures are all in sibling-lane files
  that did not exist at lane start** (`art_9_4_zero_config_env_invariance_test.exs`
  — 4 courts; plus `art_133e_live_toolchain_pin_test.exs` appearing and
  failing between census runs B and C in run C only). This lane never
  touched those files; disclosed per the compile-freeze SLA / W982z
  sibling-failure precedent as sibling mid-edit churn in the shared tree,
  not a lane defect. The lane's own 6 courts are green ×2 consecutively on
  the census command's tag filters (`--include eu_ai_act --exclude
  eu_ai_act_open_gap`), different ExUnit seeds.
- Mock gate: grep of the two new files → only prose "no mocks" lines;
  zero `Mock`/`patch(`/`.expect(` usage. Chicago: real Ash actions over
  real sandboxed Postgres + real QuiescentStop + real hash chain (26.1);
  real `DatasetAdmission` gates over seeded real samples + real
  deterministic modules (26.9).

## Tagging convention

Both files carry `@moduletag :eu_ai_act`; runs used the census filters.
No `eu_ai_act_open_gap` tags — no line was flipped; this lane deepens
already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  6/6 ×2, real commands + real exits, census-tagged runs ×4 green.
- `_build-laneW984p`: `rm -rf` denied in this lane session (same fallback
  as W981t/W982z) — **LEFT FOR COORDINATOR** per the fanout cleanup law.
- Real contract facts witnessed (worth retaining): v(∅)=1-vacuous means a
  single refusing check splits Shapley blame (φ = −0.5/−0.5), so the
  load-bearing assertion is the efficiency identity Σφ = v(N)−v(∅), not
  φ concentration on the refusing check; `AuditChain.append/2` accepts any
  binary payload digest, so binding it to real actuation
  `input_hash`/`result_hash` values is what makes the 26.1 chain court a
  real-receipt witness.
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
