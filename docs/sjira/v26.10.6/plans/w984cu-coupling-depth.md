# W984cu — Coupling Family Depth Court

Lane: W984cu, xaas v26.10.6 campaign. Branch `feat/playwright-surface` @ `cf228da6` (working tree, uncommitted).
Standing: **ALIVE** (local, 5/5 on three build roots). No commit made (per lane contract).

## Subject

- Code read fresh: `lib/xaas/coupling/coupling_run.ex` (185 lines), `lib/xaas/coupling/engine.ex` (292 lines).
- Existing coverage: `test/xaas/coupling/coupling_run_test.exs` (5 tests: solved create, unsupported create, infeasible create, empty-set admission, read-bypass floor) and `test/xaas/coupling/engine_test.exs` (14 tests: engine math per outcome, determinism, zero-weight, malformed input).
- Covered slices excluded per task: W984ak (supersede chain + policy floor), W983h (graphql era, since removed).

## Uncourted remainder (the 5-test depth slice)

1. **`:error`-status lifecycle** — `apply_engine_result/2`'s error clause adds a changeset error, so a malformed-input run must fail admission AND leave zero persisted rows (no fifth persisted status). Court: depth_1.
2. **Cross-run isolation** — no receipt/weight bleed between two real persists in one sandbox; both reloaded from Postgres by id. Court: depth_2.
3. **Persisted-receipt integrity** through `stringify_receipt/1` → JSONB round-trip: per-coordinate kinds, bound-clamp detail (`bound`/`value`/`unconstrained_mean`), nested weighted-mean contribution fractions keyed by string proposal id. Court: depth_3.
4. **Numeric normalization** — `normalize_proposal/1`'s `* 1.0` coercion: integer JSON confidence/staleness must store float weights (dtype drift mutant otherwise survives every existing court). Court: depth_4.
5. **Transport-key fallthrough** — `fetch/2` must honor string-keyed `lower`/`upper`; an atom-only mutant silently unclamps the JSON path while atom-path courts stay green. Court: depth_5.

## Artifact

`test/xaas/coupling/coupling_depth_test.exs` — 5 tests, one mutation rationale per test (header comments).

## Verification (real commands, real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cu   mix test test/xaas/coupling/coupling_depth_test.exs  → Result: 5 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cu-f1 mix test test/xaas/coupling/coupling_depth_test.exs  → Result: 5 passed  (fresh root, full recompile)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cu-f2 mix test test/xaas/coupling/coupling_depth_test.exs  → Result: 5 passed  (fresh root, full recompile)
```

×3 roots (initial + 2 fresh): all `Result: 5 passed`, exit 0. Chicago discipline: real Postgres via `Ecto.Adapters.SQL.Sandbox`, real Ash creates/reads, assertions on final persisted state, zero mocks (no `patch(` anywhere in the file).

## Known-bad intermediates (disclosed)

- Pass 1: 0/5 — `meta: [...]` on test headers is not an ExUnit tag; test clauses pattern-matched a context key that never arrives (FunctionClauseError ×5). Court defect, fixed by removing the tags.
- Pass 2–3: syntax errors from scripted perl line surgery on the same headers (mine, fixed).
- Pass 4: 3/5 — two court defects, zero implementation defects:
  - depth_3 originally asserted coord-0 `bound_clamped` with upper = mean = 150.0; the engine correctly classifies an exactly-on-bound mean as `weighted_mean` (clamp is recorded only when the mean is strictly outside). Court rewritten with upper 100.0 < mean 150.0. Learned boundary for future courts: exact-bound means are `weighted_mean`, not `bound_clamped`.
  - depth_2 reloaded rows via `Enum.sort_by(& &1.id)` over random UUIDs — nondeterministic pairing; now `Enum.find` by each run's id.

## Cleanup disclosure

`rm -rf` is denied in this session's permission set, so lane build roots are left for the coordinator (lane law): delete these three directories, 426 MB each (~1.27 GB total):

- `_build-laneW984cu`
- `_build-laneW984cu-f1`
- `_build-laneW984cu-f2`
