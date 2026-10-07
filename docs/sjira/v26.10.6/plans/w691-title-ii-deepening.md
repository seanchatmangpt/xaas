# W691 — Title II Deepening (Art. 8 / 9 / 10 provider obligations)

Lane W691, xaas v26.10.6, canonical checkout /Users/sac/xaas, branch
feat/playwright-surface, HEAD a0723bf6. No commit made (per lane contract);
coordinator owns integration.

## Subject

- New file: `test/eu_ai_act/title_ii_deepening_test.exs` (19 tests, one
  `@moduletag :eu_ai_act`, `async: false` — the DeclaredMetrics tests flip
  `Application.put_env(:xaas, :declared_metrics_root)` and must not run
  concurrently with other env-mutating tests).
- No lib/ code touched. W676 is hardening `robust_margin.ex` /
  `dataset_admission.ex`; per coordination instruction this lane writes to the
  CONTRACT only.

## What is deepened

Backlog finding: Title II has 40 dispositioned lines in
`test/eu_ai_act/title_ii_test.exs` but mostly via file-presence +
corpus-classification tests. This file adds real-module Chicago tests:

- **Art. 9 (data governance) — `Xaas.Semantics.DatasetAdmission`**:
  full gate order (empty -> incomplete -> bias -> ADMITTED) with exact typed
  atoms asserted, including the fail-closed one-sided-population
  `w1_proxy: :inf` forced bias refusal, seeded determinism (same seed ->
  byte-identical `w1_proxy`; different seed -> independent derivation), and
  the public `completeness/2`.
- **Art. 8 (risk management) — lifecycle composition
  DatasetAdmission -> RobustMargin**: an ADMITTED dataset feeds
  `RobustMargin.estimate_lipschitz/2` over real calibration pairs and the
  Theorem-5.3 gate (`:ADMITTED` at margin 6.0 / epsilon 2.5 / L_h 1.0 /
  L_E 2.0 = penalty 5.0; `{:error, :REFUSED_ROBUST_MARGIN}` at margin 4.0),
  plus lifecycle-blocking tests: empty dataset upstream ->
  `REFUSED_NO_CALIBRATION_DATA` propagated by the gate; bias refusal as the
  only egress; `REFUSED_ARITHMETIC_OVERFLOW` (W630 contract);
  `REFUSED_MALFORMED_MARGIN_INPUT` catch-all; coincident-input slope 0.0.
- **Art. 10 (technical record-keeping) — `Xaas.Witness.AuditChain` +
  `Xaas.Semantics.DeclaredMetrics`**: three-receipt chain with exact
  link-hash topology asserts (`prev_hash` of receipt 1/2 equals the prior
  recomputed head, root at genesis, 64-lowercase-hex SHA-256/JCS hashes),
  tamper attribution (`{:tampered, 0|1|2}`, `{:tampered, :head}` via the
  head pin on a LAST-receipt tamper, `{:truncated, 3}`,
  `:invalid_receipt_attrs` on malformed append), martingale `[1,1,1]` ->
  `[1,0,0]`, sig-callback `:invalid_signature` vs accepting; DeclaredMetrics
  `declare/0` success shape asserted against the REAL on-disk receipt corpus
  (source paths verified with `File.exists?/1`), plus two fail-closed disk
  tests (missing declared root and garbage ledger body), both via a real
  tmpdir declared root through the module's own
  `Application.get_env(:xaas, :declared_metrics_root)` seam — real disk,
  no mocks.

## Command + real output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW691 \
  mix test test/eu_ai_act/title_ii_deepening_test.exs --include eu_ai_act
```

Final run (2026-10-07):

```
Finished in 0.5 seconds (0.00s async, 0.5s sync)
Result: 19 passed
[exited with code 0]
```

## Iteration history (honest)

- Run 1: SyntaxError — `[%r0]` parses as a sigil; renamed to `receipt0`/`receipt1`/`receipt2`.
- Run 2: CompileError — stale `r0/r1/r2` assert lines left behind by the first
  fix; removed.
- Run 3: 15/19 — four lane-side expectation-arithmetic errors, none a lib
  defect: completeness is 7/8 = 0.875 (not 0.75); empirical Lipschitz sup of
  `{1,2},{3,5},{10,22}` is 2.0 (not 2.2) and `{1,1},{0,4}` is 1.0 (not 2.0);
  the `{:tampered, :head}` pin applies to a LAST-receipt tamper (a mid-chain
  tamper is caught earlier with exact index attribution). All four fixed in
  the TEST, lib/ untouched.

## Coordination / standing

- **Blocked-on-W676: NONE observed.** All 19 tests pass against the current
  robust_margin/dataset_admission on HEAD a0723bf6 — no refusal-atom contract
  changed out from under this lane during the run. No test was written to a
  not-yet-landed contract; no disclosure required.
- One residual compiler type warning in the DeclaredMetrics success-branch
  case ("conditional expression will always succeed" on the nested map
  pattern) — benign, pattern is the contract; left as-is and disclosed here.
- Ambient (pre-existing, not lane-introduced): AshA2A legacy-compat
  receipt-store warnings, Grafana/PromEx upload nxdomains, autofde-not-on-PATH
  bridge warning.

## Standing: PARTIAL_ALIVE

ALIVE for the 19 new tests on the exact subject (command + output above).
PARTIAL because: no commit (lane contract), the Title III/IV-VII titles and
the Art 8-10 recital lines are unchanged from W522/W531, and the residual
type warning is disclosed. Replay: the command above on any checkout
containing a0723bf6 + the new test file, pinned toolchain elixir
1.20.2-otp-28 via asdf.
