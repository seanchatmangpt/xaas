# W984ec — Corpus evidenced-line deepening wave 8 (2 lines, 3 courts)

Lane W984ec · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Build root `_build-laneW984ec` — cold compile, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims`), `MIX_ENV=test`.

## Gap-inventory provenance

All seven prior wave receipts were consulted (w981t, w982z, w984a,
w984p, w984al, w984be, w984by). Taken lines excluded: 26.6, 14.4.b,
15.5.s3, 26.7, 26.1, 26.9/Art-13-information-use, 27.1.c+d, 10.2.h,
10.3, 9.4, 13.3.e, 26.5, 27.1.f, 10.2.f+g, 26.2, 27.3 (W704). The live
`deepening_map` (`test/eu_ai_act/title_iii_test.exs`) was re-read on
disk. Chosen lines are EVIDENCED (W502), court-free, and non-adjacent
to prior waves:

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 10.2.e | training/testing/validation data undergo "examination in view of its intended purposes" — availability, quantity, suitability (Art. 10(2)(e)) | BINDING LIVENESS of the completeness/intended-purpose leg: the verdict flips exactly at the REAL measured completeness against the eta threshold — the measured value is read out of the gate's own ADMITTED envelope, independently recomputed as the non-nil share over the raw fixtures, placed exactly ON the threshold (strict `<` boundary admits at equality) and one notch tighter flips to `REFUSED_INCOMPLETE_DATASET` with the envelope echoing the real measured completeness and threshold; the availability/quantity leg: a fully-missed required field measures 0.0 and refuses at a 0.95 floor, while the SAME population with no declared required field admits at completeness 1.0 — the deployer's declared field set, not the raw data alone, determines availability | `test/eu_ai_act/art10_2e_art26_4_dataset_purpose_deepening_test.exs` (court 1 + court 2) | a hardcoded completeness or a non-strict boundary fails court 1's boundary legs while generic admit/refuse shape tests still pass; a gate that ignored `:required_fields` fails court 2's availability flip while single-configuration courts still pass |
| 26.4 | deployer shall ensure input data "relevant and sufficiently representative in view of the intended purpose" — under the deployer's control (Art. 26(4)) | DEPLOYER-CONTROL binding: identical data flips ADMITTED ↔ typed refusal by the eta knob alone, by the required-field-set knob alone (same eta), and the declared gate ORDER is witnessed on a doubly-defective population (fully incomplete AND maximally biased): the typed refusal is INCOMPLETE, never BIAS — and with the completeness gate disabled (eta 1.0) the same population exposes the bias gate behind it, refusing `REFUSED_BIAS_THRESHOLD` with the real measured `w1_proxy` and the deployer's epsilon | same file, court 3 | a gate that let the bias gate run before completeness fails the order leg; a gate ignoring the eta/required-fields call arguments fails the control legs; a bias envelope echoing a fabricated w1 fails the measured-w1 assertion — all while `title_iii_test.exs`'s generic dataset_gate shape tests still pass |

Overlap discipline: 10.2.f/g (W984by) covered the BIAS refusal envelope,
seeded W1 liveness, and scale equivariance; 10.2.h/10.3 (W984a) covered
gate order (INCOMPLETE-before-BIAS) and eta causality — court 3's order
leg re-witnesses the declared order on a NEW doubly-defective fixture and
adds the deployer-control legs, which no prior court asserted; 10.2.e and
26.4 themselves were completely court-free.

## Verification (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ec \
  mix test test/eu_ai_act/art10_2e_art26_4_dataset_purpose_deepening_test.exs --include eu_ai_act
```

- Run 1: `2 passed, 1 failed` (court 1's `w1 == 0.0` fixture assumption
  false — see repair below)
- Run 2 (post-repair): `Result: 3 passed` — exit 0

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ec \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Census run 1 (default seed): `Result: 1355 passed, 1 excluded` — exit 0
- Census run 2 (seed 469313): `Result: 1355 passed, 1 excluded` — exit 0

(1355 ≥ the dispatch's 1352 floor; +3 over the pre-lane state = this
lane's three courts, witnessed standalone.)

## Disclosed repair history (real contract fact learned)

The sliced-W1 projection vector includes the purpose-relevant feature
values, so a population whose single nil-carrier sits in only one
sensitive group is NOT bias-free — `w1_proxy` is strictly positive even
with all other features identical across groups. The original fixture
assumption (`w1 == 0.0`) was false and the court was repaired to assert
the real contract (`is_float(w1) and w1 >= 0.0`), moving the isolation
of the completeness leg onto the epsilon-100 call argument instead.
lib/ untouched.

## Mock gate

`grep -nE "Mock|patch\(|\.expect\("` over the new file → zero hits
(exit 1). Chicago: real `Xaas.Semantics.DatasetAdmission` executions
over real in-test populations; assertions on final returned state only;
zero mocks, zero application-env knobs.

## Tagging convention

`@moduletag :eu_ai_act` only; no `eu_ai_act_open_gap` tags — no line
flipped; this lane deepens already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  3/3 standalone + census 1355/1355 ×2 (two seeds), real commands + real
  exits. The census is a shared moving surface; counts are as-of these
  runs (receipt-cited counts re-read at use time).
- Remaining-range estimate: the deepening corpus still has court-free
  evidenced lines, including 9.1/9.2.a–d/9.5/9.5.s3/9.8 (ferroplan
  reachability — cross-repo surface), 11.1/12.1/12.2.a–c (audit-chain
  dedicated deepening), 13.1/13.3.b.ii/13.3.b.iv/13.3.f
  (counterfactual/Shapley dedicated deepening), 14.1/14.2/14.3.a–b
  (quiescent/oversight dedicated deepening), 15.1/15.4 (margin-gate
  dedicated deepening), 15.5/15.5.s2 (wasi-gate), 26.12 (audit-chain),
  10.2.f/g partially (purpose leg), plus Title VI–XIII lines. Rough
  order: 20–30 evidenced lines remain court-free.
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
