# W674 — gymact surface deepening (lane receipt)

- **Lane**: W674, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, base HEAD `a0723bf6` (uncommitted lane:
  per dispatch, no commit).
- **Subject**: `test/xaas/operations/gymact_surface_deepening_test.exs` (new,
  9 courts) + this receipt. No lib change; no commit (dispatch forbids).
- **Standing**: ALIVE (lane-scoped, uncommitted).

## What was built

`Xaas.Operations.GymactSurfaceDeepeningTest` — Chicago-style deepening of
`lib/xaas/operations/gymact_surface.ex`:

1. **Fail-closed typed refusal** — unconfigured config+env →
   `{:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}}` on
   `config/0`, `actuate_local/4` (before `Xaas.Actuation.run/4`); base_url
   without token refused; trailing-slash normalization; empty base_url
   refused.
2. **Three-commit external protocol over real HTTP** — a real Bandit/Plug
   HTTP server (with a real `Plug.Parsers` JSON body parser) spawned in-test
   stands in for the *remote* gymact FastAPI service; the adapter's real Req
   client does a real DO across the wire. Asserts final state: succeeded
   envelope (`receipt`/`intent` `:succeeded`, `completed_at`, echoed cut),
   exactly one wire hit (atomics counter via `:persistent_term`), and the
   local Ash subject deliberately NOT mutated (external DO is the only
   consequence; local mutation is `actuate_local/4`'s job).
3. **Idempotency-key stability across retries** — same key re-runs the
   `:replayed` envelope without a second remote DO (wire hits stay at 1).
4. **Non-2xx remote** — typed behavior disclosed below (W674-GAP-1).
5. **Missing `:idempotency_key`** → `{:error, :idempotency_key_required}`,
   nothing sealed.

No `@moduletag :eu_ai_act`: none of these courts feeds an evidenced
EU-AI-Act line — they qualify the gymact bridge itself, not an Article
8/13/14/15 logging surface.

## Green tail (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW674 \
    mix test test/xaas/operations/gymact_surface_deepening_test.exs
.........
Finished in 1.6 seconds (0.00s async, 1.6s sync)
Result: 9 passed

# combined with the pre-existing base court (real uvicorn gymact subprocess):
$ mix test test/xaas/operations/gymact_surface_test.exs \
           test/xaas/operations/gymact_surface_deepening_test.exs
Finished in 10.3 seconds (0.00s async, 10.3s sync)
Result: 18 passed

# reseeded repeat: 9 passed
```

## Typed gaps disclosed (observed real contracts, asserted in the court)

- **W674-GAP-1** — a non-2xx remote (`{:gymact_http_error, status, body}`)
  cannot be sealed: `ActuationReceipt.error` is a `:map` attribute but
  `GymactSurface.do_and_seal/2` hands `seal_external/2` the raw tuple
  (`json_safe` renders it as a LIST), the `:seal` action rejects it, and the
  whole seal transaction rolls back — `{:error, {:external_seal_failed,
  %Ash.Error.Invalid{field: :error, message: "is invalid"}}}`. The durable
  prepare survives (`intent :executing`, `receipt :prepared`, subject
  unmutated — all asserted), but no `:failed` receipt is ever recorded, so
  the ledger never learns the DO failed. Suggested fix (not made — test-only
  lane): wrap the DO error in a map (e.g. `%{"gymact_http_error" => %{...}}`)
  or a `Xaas.Actuation.Refusal` before `seal_external/2`.
- **W674-GAP-2** — `actuate/4` without `:episode_id`/`:cut` opts raises a raw
  `WithClauseError` from `do_and_seal/2` instead of returning a typed
  refusal; the durable prepare survives unsealed (asserted). Suggested fix:
  typed `{:error, :episode_id_required}` / `:cut_required` before the DO.

## Environment / replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW674 \
  mix test test/xaas/operations/gymact_surface_deepening_test.exs
```

Local Postgres required (sandbox); no gymact venv required — the deepening
court's remote stand-in is in-test (Bandit), unlike the base court's real
uvicorn subprocess (which ran green in the combined run).

## Cleanup

`rm -rf _build-laneW674` was attempted; the harness denied `rm -rf`, so the
lane build root is left for the coordinator per the dispatch's fallback.
