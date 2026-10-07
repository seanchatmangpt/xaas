# W984a — Corpus evidenced-line deepening wave 3 (2 lines, 3 courts)

Lane W984a · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Build root `_build-laneW984a` — cold compile, pinned asdf toolchain
1.20.2-otp-28, `MIX_ENV=test`.

## Gap-inventory provenance

Corpus `docs/eu_ai_act/corpus.json` drives per-line verdicts at compile time
(live inventory). Read before picking: `w981t-corpus-deepening.md`
(26.6 / 14.4.b / 15.5.s3), `w982z-corpus-deepening-2.md` (26.7, 27.1.c/d),
W704 (27.3), plus the other in-tree deepening courts to avoid overlap:
W619/W665 art50 deepening (50.1/50.2/50.5), W658c/W697 (15.3 declared
metrics incl. staleness/causality), W691 title-II deepening (Art 5
partition, Art 10 fail-closed), W669b/W538 art73 chain, counterfactual
deepening (13.x/86.1), eyerun wire (15.5/15.5.s2). The two lines below are
EVIDENCED (W502 evidence entry, `test/eu_ai_act/title_iii_test.exs`) and
had NO deepening court: their only executable coverage was single-gate
verdicts in `test/xaas/semantics/dataset_admission_test.exs`.

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 10.2.h | data-governance: examination incl. identification of gaps and how they are addressed | `Xaas.Semantics.DatasetAdmission` gate ORDER: a dataset that is simultaneously incomplete AND biased refuses `{:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness:, threshold:}}}` FIRST (documented gate order 1→2→3), the refusal carrying the gap numerically | `test/xaas/deepening/art_10_2h_10_3_dataset_gate_causality_test.exs` (3 courts) | reordering the gates (bias before completeness) passes every existing single-gate court but fails court 1; hardcoding completeness, dropping eta from the threshold comparison, or drifting the envelope value from `completeness/2` fails court 2 |
| 10.3 | representative/completeness examination in view of intended purpose | the executed representativeness measure itself: the ADMITTED envelope's `w1_proxy` equals an independent recomputation of the public executed `sliced_w1/3` over the same samples and seed | same file | any drift between the envelope's declared representativeness number and the real gate computation fails court 3 while verdict-level courts still pass |

The eta-threshold causality court pins the zero-config property: the SAME
boundary dataset (completeness exactly 0.9) flips ADMITTED ↔ typed
incomplete purely on the `eta` call argument (0.1 admits, 0.05 refuses),
with no application-env knob in the loop.

## Verification (real tails)

Cold-lane build; census command, run ×2 green (different ExUnit seeds):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984a \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run 1 (seed 482953): `Result: 24 passed` — exit 0
- Run 2 (seed 618371): `Result: 24 passed` — exit 0

(24 = prior 18 + this lane's 3 + sibling lane W984p's 3 — see disclosure.
Single-file runs witnessed the repair history: run 1 `0/3` — required_fields
not passed so the completeness gate was inert, and the Art 10(3) population
had W1 1.43 > epsilon; run 2 `2/3` — population still disjoint (W1 0.95);
final `3 passed`.)

Mock gate: grep of the new file → only prose "no mocks"; zero
`Mock`/`patch(`/`.expect(` usage. Chicago: real pure-module executions of
`DatasetAdmission.admit/2`, `completeness/2`, `sliced_w1/3` over real sample
data; assertions on returned final state only.

## Disclosed minimal sibling-lane fix (compile-freeze SLA)

`test/xaas/deepening/art_26_9_art13_information_use_test.exs` (lane W984p,
line 26.9) was failing 3/3 deterministically in the shared census:
`Float.mod/2` does not exist in Elixir 1.20 (compile-level crash), and
`balanced_dataset/0` correlated sensitive-group parity with feature value
(disjoint ranges → W1 > 0.5 → the "repaired" input still refused, so
efficiency-identity and counterfactual courts failed). Minimal fixes,
intent preserved, all assertions unchanged in kind:

1. `Float.mod(i * 1.0, 10.0)` → `:math.fmod(i * 1.0, 10.0)`.
2. `balanced_dataset/0` rebuilt as paired samples covering the SAME value
   range for both sensitive groups (W1 = 0.25 < 0.5 → real admit).
3. Both-gates-fail fixture: `Map.delete(s.features, :x)` (empty feature map
   → dim-0 `FunctionClauseError` in `random_unit_direction/2`) →
   `put_in(s, [:features, :y], nil)` with `required_fields: [:y]` — nil
   features stay observable per the module's non-number→0.0 vector
   contract, completeness still refuses, bias still refuses.

No mocks introduced; lib/ untouched; the fixes are confined to that file.

## Tagging convention

New file carries `@moduletag :eu_ai_act` (corpus-article census); runs used
`--include eu_ai_act --exclude eu_ai_act_open_gap`, the census command. No
`eu_ai_act_open_gap` tags — no line was flipped; this lane deepens
already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  3/3, census 24/24 ×2, real commands + real exits.
- `_build-laneW984a`: `rm -rf` permission-denied in this lane session
  (same fallback as W981t/W982z/W928b/W980i) — **LEFT FOR COORDINATOR**
  per the fanout cleanup law.
- Real contract facts witnessed (worth retaining): `DatasetAdmission`
  completeness defaults to `1.0` with empty `required_fields` (the gate is
  inert unless required fields are named); W1 refuses at STRICTLY greater
  than epsilon (`0.25 < 0.5` admits); `random_unit_direction/2` has no
  dim-0 clause — an all-empty feature population crashes the W1 helper
  rather than refusing typed (candidate lib gap, not fixed in this lane's
  contract).
- Not done (typed): no line flips, no lib edits, no corpus edits — test/
  + receipt only, per this lane's contract.
