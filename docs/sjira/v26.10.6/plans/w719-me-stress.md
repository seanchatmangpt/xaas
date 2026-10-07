# W719 — Master Equation Composition Stress Window — Receipt

Lane W719, xaas v26.10.6 campaign. Canonical checkout /Users/sac/xaas, branch
`feat/playwright-surface`, HEAD a0723bf6. No commit (lane contract).

## Subject

New file: `test/xaas/semantics/master_equation_composition_stress_test.exs`
(handwritten, no lib edits, no mocks).

Backlog: W628 master-equation soak (300/300, seed 62828) covered the 9 core
W541 composition-court tests; the admitted-composition property lacked a
stress window. This lane adds it:

- (a) 1,000-cycle seeded composition run over the REAL admission surfaces —
  `EuAiActAdmission.admit/1` via the reused W541 court pipeline
  (`MasterEquationTest.f_actuate/2`) + `AdmissionAttribution.shapley/2`
  (efficiency axiom witnessed per cycle by clean return; admitted class
  asserts all-zero attribution).
- (b) conservation asserted at EVERY cycle: admitted + refused + blocked ==
  total, plus at the final checkpoint of all 3 seeds.
- (c) typed-decision distribution stability across 3 seeds
  (719001/719002/719003), pairwise deltas within declared tolerance
  @tolerance 0.05. NOTE: no prior distribution-tolerance convention exists
  in W541/W628 (they assert exact determinism, which a cross-seed comparison
  cannot), so this lane fixes the 5% explicitly as a module attribute.
- (d) bounded memory across the window: forced-GC-bracketed process memory
  (before=2,776 words, after=5,904 words; allowance 4 MiB) and total ETS
  memory (before=4,641,712 B, after=4,645,464 B; allowance 1 MiB).

Design: 4 candidate classes (lawful / art5_violating / margin_violating /
malformed) drawn seeded-uniform per cycle; 10% seeded gate-(c) tamper
injection on lawful draws reclassifies DO -> BLOCKED_GATE_C (W541
to_gate_c_refusal shape), giving nontrivial blocked counts. Machinery share
= (admitted+refused)/total, tracked at every 100-cycle checkpoint and
asserted >= 1 - tamper cap (0.90).

## Gate + actual output

Exact command (final green run, 2026-10-07):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW719 \
  mix test --include stress test/xaas/semantics/master_equation_composition_stress_test.exs
```

Real tail:

```
.........W719 stress window (seed 719001):
  admitted=240 refused=735 blocked=25
  machinery_share=0.975
  checkpoints=[{100, 20, 78, 2, 0.98}, {200, 45, 145, 10, 0.95},
 {300, 68, 222, 10, 0.9666666666666667}, {400, 94, 294, 12, 0.97},
 {500, 117, 366, 17, 0.966}, {600, 141, 441, 18, 0.97},
 {700, 161, 518, 21, 0.97}, {800, 190, 587, 23, 0.97125},
 {900, 217, 660, 23, 0.9744444444444444}, {1000, 240, 735, 25, 0.975}]
  mem_before=2776 mem_after=5904 ets_before=4641712 ets_after=4645464

.W719 distribution seed=719001: %{blocked: 0.025, do: 0.24,  refused: 0.735} counts={240, 735, 25}
W719 distribution seed=719002: %{blocked: 0.026, do: 0.214, refused: 0.76}  counts={214, 760, 26}
W719 distribution seed=719003: %{blocked: 0.042, do: 0.23,  refused: 0.728} counts={230, 728, 42}

Finished in 0.7 seconds (0.00s async, 0.7s sync)
Result: 11 passed
```

11 = my 2 stress tests + the 9 W541 court tests
(`MasterEquationTest` is `Code.compile_file`'d standalone so the composition
pipeline is available; its 9 tests also ran and passed).

Max pairwise cross-seed distribution delta observed: 0.028 (blocked,
719001 vs 719003) <= 0.05 tolerance.

## Standing

ALIVE — witnessed execution on the exact subject (HEAD a0723bf6, lane build
root `_build-laneW719`, pinned toolchain elixir 1.20.2-otp-28 / OTP 28.5.0.2
via asdf). Falsifier would be: per-cycle conservation mismatch, cross-seed
pairwise delta > 5%, or unbounded memory growth; none fired.

## Notes / disclosures

- No @moduletag :eu_ai_act: the file exercises the composition/admission
  surfaces (`EuAiActAdmission.admit/1`, `RobustMargin.admit/4`,
  `AdmissionAttribution.shapley/2`, `AuditChain`) but is NOT tied to the
  eu_ai_act corpus tag; it runs under `--include stress` (two `@tag :stress`
  tests) and otherwise sits with the v26.10.6 semantics suite.
- Tag exclusions observed in the run header: Excluding
  [:kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external,
  :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act];
  Including [:stress].
- @tolerance 0.05 is declared in-module (no prior tolerance convention to
  inherit).
- Generated vs handwritten: 100% handwritten; zero lib edits.
- Running the file standalone surfaces a PRE-EXISTING type warning in
  `master_equation_test.exs` (line 381, `receipt0` struct-type warning) —
  not introduced by this lane.
- Coordinator action: delete `_build-laneW719` (~437 MB) at integration
  (deletion was permission-denied in this lane session).
