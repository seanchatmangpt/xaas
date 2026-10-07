# W984ai W1 dim-0 court leg — receipt (2026-10-07)

Lane: W984ai, xaas v26.10.6, branch `feat/playwright-surface` (5f7f70d9 base).
Typed residue from W984a (`w984a-corpus-deepening-3.md`).

## Defect

`Xaas.Semantics.DatasetAdmission.sliced_w1/3`: an all-empty-features
population (every sample `%{features: %{}}`, both sensitive groups non-empty)
yields dim-0 vectors; `random_unit_direction/2`'s `dim > 0` guard raises
`FunctionClauseError` — a raw raise escaping the admission gate instead of a
typed refusal.

## Fix shape (lawful minimal)

Dim-0 is the same **zero-information class** as the existing
unobservable-population branch (`a0 == [] or a1 == [] -> :inf`), which
fail-closes to the typed `REFUSED_BIAS_THRESHOLD` refusal via the `:inf`
convention (`:inf > epsilon` is true). Added a `dim == 0` branch in
`sliced_w1/3` returning `:inf` with a W984ai comment; no new atom, no change
to the closed refusal set, no `admit/2` change needed.

File: `lib/xaas/semantics/dataset_admission.ex` (sole lib file touched).

## Court leg

`test/xaas/semantics/dataset_admission_test.exs` —
"all-empty-features population (dim 0) refuses typed, not FunctionClauseError":

- `sliced_w1/3` direct surface: asserts `:inf`, not a raise.
- `admit/2` gate surface: asserts
  `{:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: :inf, ...}}}` — typed
  refusal through the existing closed atom set.

## Verification (real, fresh `_build-laneW984ai` root)

| command | result |
|---|---|
| `mix test test/xaas/semantics/dataset_admission_test.exs` | **10 passed, exit 0** |
| census 1: `mix test test/xaas/deepening/` (default tags) | exit 0 — **0 tests, 36 excluded** (all 12 files `@moduletag :eu_ai_act`; a 0-test census is vacuous, disclosed, so tagged runs below are the real census) |
| census 2 (tagged `--include eu_ai_act`) | **35/36, exit 2** — 1 failure in `Art265OperationMonitoringEgressTest` (tamper-evident egress MatchError); file passes **3/3 in isolation** → concurrency flake in an unrelated file (no state shared with DatasetAdmission), not reproducible in isolation |
| census 3 (tagged, rerun) | **36/36 passed, exit 0** |

All runs: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW984ai`. Census log tails in
`/tmp/w984ai_census{2,3,4}.log` (session-scoped, ephemeral).

## Standing

- dim-0 typed refusal: **ALIVE** (fix + court leg witnessed passing on the
  lane root, run twice green on the gate file, tagged census 36/36 on rerun).
- `Art265OperationMonitoringEgressTest` under full-dir concurrent census:
  **PARTIAL_ALIVE / flaky** (1-in-2 concurrent failure; green isolated and on
  census rerun) — pre-existing, disclosed, not session-introduced.

## Lane hygiene

No commits made. Files written: `lib/xaas/semantics/dataset_admission.ex`,
`test/xaas/semantics/dataset_admission_test.exs`, this receipt.
`_build-laneW984ai` deletion attempted twice (`rm -rf`) and denied by the
permission system — left on disk for the coordinator to delete (per lane
contract fallback).
