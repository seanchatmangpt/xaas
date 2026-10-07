# W536 — Art. 15(3) Declared-Metrics Surface

Campaign: v26.10.6 EU-AI-Act wave, lane W536 @ /Users/sac/xaas `feat/playwright-surface`
(private build root `_build-laneW536`).

## Art 15(3) duty → metric → source mapping

| Art 15(3) duty | Metric | Source (read at call time, fail-closed) |
|---|---|---|
| metrics used to measure accuracy | `accuracy`: `pass_rate` — passed/population read from w316b full-suite receipt (`Result: 3233/3247 passed`) | `docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md` |
| metrics used to measure robustness | `robustness`: `mutant_kill_rate` — kills/runs from the refusal ledger counts (`mutant_kill_verified` 9 / `mutation_runs` 10), corroborated by the three mutation receipts | `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` + `docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md`, `w382-anti-vacuity-r2.md`, `w414-empty-bearer-kill.md` |
| refusal surface integrity (Art 15(3) in the declared-metrics frame of the coverage map) | `refusal_coverage`: ledger `counts.coverage` = `62/62` | `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` |
| benchmark/test methodology conformance | `conformance`: `CONFORMANT 26/26` from the w385 conformance-court receipt → `"26/26 in-repo court"` | `docs/sjira/v26.10.6/plans/w385-conformance-court.md` |

## Design

`Xaas.Semantics.DeclaredMetrics.declare/0`:

- Sources are declared as module attributes (paths + regex extraction contracts);
  VALUES are read from disk at call time — nothing metric-valued is hardcoded.
- Fail-closed: missing file, JSON decode failure, or regex mismatch on any cited
  source → `{:error, :REFUSED_METRICS_SOURCE_MISSING}` (typed refusal, no
  partial declaration, no default values).
- Deterministic: pure function of the receipt files; no timestamps, no RNG.
- Root override: `Application.get_env(:xaas, :declared_metrics_root, File.cwd!())`
  exists only so the fail-closed path is testable with a real empty directory
  (Chicago discipline — real File reads, no mocks).

## Tests

`test/xaas/semantics/declared_metrics_test.exs`:

1. Structure: all four metric groups present, sane types, w316/w414 sources cited.
2. Ground truth: accuracy values equal the numbers extracted independently from
   the w316 receipt by the test itself (population = 3247 witnessed).
3. Robustness/coverage values equal the refusal ledger's `counts` (9/10, 62/62).
4. Fail-closed: empty metrics root → `{:error, :REFUSED_METRICS_SOURCE_MISSING}`.
5. Determinism: two calls identical.

## Verification

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW536 \
      mix test test/xaas/semantics/declared_metrics_test.exs

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW536 \
      mix compile --force --warnings-as-errors

## Standing

ALIVE. Executed on this lane's tree:

- `mix test test/xaas/semantics/declared_metrics_test.exs` (MIX_BUILD_ROOT=_build-laneW536):
  **Result: 5 passed** (exit 0).
- `mix compile --force --warnings-as-errors` (MIX_ENV=test, _build-laneW536):
  "Generated xaas app", exit 0, zero warnings/errors.
- Mock gate not re-run: no mocks/stubs in either lane file (real File reads only).
- Concurrent-lane caveat: W538's untracked `incident_report.ex` briefly blocked the
  shared-tree compile mid-lane (resolved by its owner before final verification);
  both gates above were witnessed on the resolved tree.
- Lane build root `_build-laneW536` remains on disk (rm denied by permission gate,
  same as w316b) — ~1 GB lease to collect at integration.
