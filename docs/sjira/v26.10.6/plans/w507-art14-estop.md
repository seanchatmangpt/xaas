# W507 — Art. 14(4)(e) Emergency-Stop Attractor (Theorem 5.2)

Lane: W507, EU-AI-Act wave, repo `/Users/sac/xaas` @ `feat/playwright-surface`,
build root `_build-laneW507`.

## Theorem mapping

Theorem 5.2: `u_stop` drives the system to a quiescent safe equilibrium with a
typed receipt.

- **u_stop** = `Xaas.Actuation.QuiescentStop.execute/2`
  (`lib/xaas/actuation/quiescent_stop.ex`).
- **Quiescent safe equilibrium** = subject lifecycle status `:suspended`
  (`Xaas.Marketplace.Provider` constrains status to `[:pending, :active,
  :suspended]`; `:suspended` is the terminal safe state in that lattice).
- **Attractor = monotone stopped-state invariant**: once the subject is at
  `:suspended`, the stop surface admits no further DO — same key replays
  idempotently (`{:ok, %{already_stopped: true}}`), a fresh key refuses typed
  (`{:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}`), and no new receipt is
  minted. V(s) does not increase: from the stopped state every stop-surface
  transition either is a no-op or refuses.
- **Typed receipt**: `{:ok, %{stopped_at: %DateTime{}, target: :quiescent,
  authority: ctx}}` from the sealed `Xaas.Operations.ActuationReceipt` (its
  `completed_at`), bound through the lawful pipeline (admission → intent →
  Reactor DO → sealed receipt → replay ledger).

## Lawful path (no side channel)

`execute/2` delegates to `Xaas.Actuation.run(Provider, :actuate_status,
%{status: :suspended}, ...)` — the same Ash.Reactor actuation kernel as every
consequential DO: `Registry.admit` projection, `ActuationIntent`/
`ActuationReceipt` ledger, `Xaas.Actuation.Validations.ReactorContext` guard on
the action, idempotency-key replay. Fail-closed authority gate before any
admission: authority must carry non-empty `kind` + `source` strings, else
`{:error, :REFUSED_STOP_AUTHORITY}` with the subject untouched.

## Receipt contract

| call | result |
|---|---|
| first stop, authority present | `{:ok, %{stopped_at, target: :quiescent, authority}}` |
| same key again | `{:ok, %{already_stopped: true}}` |
| fresh key, subject already `:suspended` | `{:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}` |
| missing/empty authority | `{:error, :REFUSED_STOP_AUTHORITY}` (no DO) |
| missing idempotency key | `{:error, :idempotency_key_required}` |

## Files (lane contract)

- `lib/xaas/actuation/quiescent_stop.ex` (new, written)
- `test/xaas/actuation/quiescent_stop_test.exs` (new, written)
- `docs/sjira/v26.10.6/plans/w507-art14-estop.md` (this file)

## Verification (test tail)

Command: `MIX_BUILD_ROOT=_build-laneW507 MIX_ENV=test PATH=$HOME/.asdf/shims:$PATH
mix test test/xaas/actuation/quiescent_stop_test.exs`

Result: **5 passed, 0 failed** (observed 2026-10-06, seed 693503).

```
Running ExUnit with seed: 693503, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api,
  :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
.....
Finished in 0.5 seconds
Result: 5 passed
```

Compile: `mix compile --force` exit 0, zero warnings from lane files (grep
"quiescent" over strict-gate output: 0). Whole-app `--warnings-as-errors`
currently fails on ANOTHER lane's untracked in-flight files
(`lib/xaas/semantics/dataset_admission.ex` unused-var warning;
`lib/xaas/semantics/counterfactual.ex` transient undefined-function errors) —
pre-existing/concurrent, not lane W507's.

## Standing

ALIVE — observed execution on the exact lane subject: real sandboxed Postgres,
real Ash.Reactor kernel, 5/5 courts green, receipt surface exercised end to end
(stop → typed receipt → idempotent replay → monotone refusal).
