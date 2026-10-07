# W697 — DeclaredMetrics fail-closed staleness courts

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface (canonical checkout)
- **Wave**: v26.10.6, lane W697
- **Diff (μ)**: 1 new test file, 1 new receipt. No lib/ changes. Not committed (lane instruction).

## What was built

`test/xaas/semantics/declared_metrics_staleness_test.exs` — 10 Chicago-style courts over
`Xaas.Semantics.DeclaredMetrics.declare/0`'s fail-closed contract (W658c court finding):
real temp-dir fixture roots via `Application.put_env(:xaas, :declared_metrics_root, ...)`,
real `File` operations, zero mocks. @moduletag :eu_ai_act with an in-file comment naming the
evidenced line (EU AI Act Art. 15(3), declared_metrics.ex moduledoc).

Coverage:
- (a) missing receipt file → `{:error, :REFUSED_METRICS_SOURCE_MISSING}` (exact atom);
      plus empty-root variant (a2)
- (b) malformed JSON ledger → typed refusal; (b2) wrong JSON shape → typed refusal
- (c) count drift 3233→3232 — **typed finding, not invented behavior**: declare/0 has no
      hardcoded-value admission; drift flows through as `{:ok, %{accuracy: %{passed: 3232}}}`.
      The drift gate lives in the production court
      (declared_metrics_test.exs pins `population == 3247` against real disk), not in declare/0.
      Plus regex-miss (c2) and missing-mutation-receipt (c3) → typed refusal.
- (d) **typed finding**: module exposes no staleness variant — exports exactly
      `declare/0` (+ module_info), no declare/1, no :stale/:staleness/:freshness.
      Nothing invented; the export surface is asserted directly.
- (e) happy path with byte-shaped fixture bytes matches production values
      (3233/3247, CONFORMANT 26/26, ledger 9/10/"62/62"); (e2) cross-check: real on-disk
      receipt bytes through the fixture root produce the identical declaration.

## Verification (real commands, real output tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW697 \
    mix test test/xaas/semantics/declared_metrics_staleness_test.exs --include eu_ai_act
Running ExUnit with seed: 422149, max_cases: 32
Including tags: [:eu_ai_act]
..........
Finished in 1.2 seconds (0.00s async, 1.2s sync)
Result: 10 passed
```

Earlier iterations (disclosed): 2 compile errors (@moduletag-before-use, harness line-swap
during editing) and a write_receipts/2 key bug — all fixed forward; final run green.

## Standing

- **ALIVE** (lane-scoped): 10/10 courts green on the exact subject a0723bf6 + this file.
- `_build-laneW697/` left on disk (rm -rf was permission-denied in this lane session);
  coordinator to delete per lane-lease law. No other tree writes.
- Mock gate: not run this lane (test-only file, zero mocks by construction — real File ops
  and real Jason decode only).

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW697 \
  mix test test/xaas/semantics/declared_metrics_staleness_test.exs --include eu_ai_act
```
