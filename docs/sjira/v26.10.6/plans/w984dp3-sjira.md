# W984dp3 — AtlassianCursor depth court (sjira lane)

- **Wave**: v26.10.6, lane W984dp3 (depth-court census lane, from W984di census note)
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, head at test-time `52764939` (uncommitted tree; only files touched by this lane: the new test below + this receipt)
- **Artifacts**:
  - `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs` (5 tests, new)
- **No lib/ changes.** No commit made, per lane contract.

## Module surface analysis

`Xaas.Sjira.AtlassianCursor` (`lib/xaas/sjira/atlassian_cursor.ex`, 43 lines):

- `initial/1` — 2 modes (`:offset`, `:token`), otherwise crash on unknown mode (no typed refusal — noted, not patched; out of lane scope).
- `params/2` — 3 clauses: offset → `%{startAt, maxResults}`; token-nil → `%{maxResults}`; token-set → `+nextPageToken`. No guard on non-map input (FunctionClauseError, not typed).
- `advance/2` — 3 clauses: exhausted → typed `{:error, :cursor_exhausted}`; offset mode with 3-branch termination cond (**total → isLast → short-page**, in that precedence order); token mode (`isLast` or absent `nextPageToken` → done). Accumulates `seen`, nils `next` on done, returns `{:ok, state, vals}`.

Prior coverage was alias-only in `test/xaas/sjira/atlassian_test.exs:68-96` (one happy-path test; never exercised the exhausted refusal, the cond precedence, the short-page fallback, seen accumulation, or the token-nil params clause). Not a 2-trivial-function disposition — the termination cond and typed refusal carry real branching weight.

## The 5 tests (mutation rationale inline in file)

1. Exhausted cursor refuses further `advance/2` with `{:error, :cursor_exhausted}` — kills deletion of the first advance clause / error-atom mutation.
2. Offset termination precedence: `total` beats both `isLast` and the short-page heuristic (both directions asserted) — kills branch-reorder and dropped `is_integer(total)` guard mutants.
3. Short-page fallback terminates when neither `total` nor `isLast` present — kills the fallback-branch deletion mutant.
4. `seen` accumulates across advances; `params/2` roundtrips accumulated offset to `startAt` — kills dropped-accumulation and dropped nil-out mutants.
5. Token mode: initial params omit token; present token roundtrips into `nextPageToken`; absent token exhausts and a follow-up advance refuses — kills clause-swap mutants in `params/2` and the token-done predicate.

Non-duplication: no overlap with `atlassian_test.exs` (that test covers happy-path advance×2 + token params once) nor W984di's `delivery_batch_depth_court_test.exs` (DeliveryBatch surface, different module).

## Commands / exits

```
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dp3
mix compile                                                          # EXIT 0 (fresh root, run 1)
mix test test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs     # 5 passed, 0 failures (run 1)
```

Run 2 (second fresh root: `rm -rf _build-laneW984dp3` then compile+test): **PENDING — see standing**.

## Standing

- Run 1: ALIVE (compile EXIT=0 fresh root, 5/5 pass).
- Run 2: UNKNOWN at receipt-writing time; receipt to be read as-of-run-2 completion. No mock usage; real module, real assertions on returned state.

## Falsifier / notes

- Court falsifier: any mutant of `atlassian_cursor.ex` that flips the cond order, drops the refusal clause, or drops `seen` accumulation must fail this file (rationale per test above; mutants not actually executed — that would be a generate-and-kill follow-up, out of lane scope).
- Untyped gaps observed, not fixed (would change lib/): `initial/1` unknown mode and `params/2` non-map input crash rather than return typed errors.
