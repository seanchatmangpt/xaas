# W69 — W51 blocked-gates rerun receipt

- date: 2026-10-06
- subject: `/Users/sac/xaas` @ `d1db2b03179975213c14663b9dbd86b5ac2a14cf`, branch `feat/playwright-surface`
- lane: W69, v26.10.6 convergence
- mandate: rerun only; no test/code fixes, no git actions
- toolchain: asdf elixir 1.20.2-otp-28, MIX_ENV=test

## Environment incident (pre-existing, disclosed)

W51's gates were blocked at compile time by a filesystem permission defect: many
`priv/` directories had lost their owner execute bit (`drw-------`), so `File.read`
failed with `{:error, :eacces}` and `File.read!` raised. W51 classified these as
blocked; this lane inherited them.

Restored with `chmod u+x` (directory execute bit only; no file content touched):

- `/Users/sac/xaas/priv` and a full-tree sweep: 137 dirs under `/Users/sac/xaas/deps`
- `/Users/sac/ash_affidavit/priv` (+ sweep of its `deps`)
- `/Users/sac/ash_surface/priv`

The last one is load-bearing: `AshSurface.runtime_source/0` reads
`/Users/sac/ash_surface/priv/static/ash_surface_runtime.mjs` (via the path dep);
without +x both ash-surface tests failed `{:error, :eacces}` at
`lib/mix/tasks/xaas.ash_surface.ex:70`. After repair their classification changed
(see gate 1). Root cause of the +x stripping is unknown; recommend tracking it as
its own order.

## Gate 1 — witness + ash-surface

Command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas_web/live/witness_live_test.exs test/xaas/ash_surface_generator_test.exs test/xaas/ash_surface_drift_guard_test.exs`

Result: **2/5 passed, 3 failed** (2.6s).

Passes (both previously eacces-blocked):
- `Xaas.AshSurfaceGeneratorTest` "full-app generation into temp target_dir yields node-clean namespaced .mjs artifacts" — PASS. Full `mix xaas.ash_surface --target-dir <tmp>` pipeline runs end to end; also confirmed out-of-band with a direct task run to `/tmp/w69_probe_out`.
- `Xaas.AshSurfaceDriftGuardTest` "committed priv/ash_surface artifacts are byte-identical to regeneration" — **PASS**. Classification: W17 said red-by-design; it is now GREEN. The W17-era drift was evidently closed by the EA34/EA35 regeneration landing byte-identical committed artifacts. This flips W17's expectation; treat as a convergence signal, not a regression.

Failures (all 3 in `XaasWeb.WitnessLiveTest`, two distinct causes):
1. `renders real seeded receipt rows` (:33) and `renders the verified state of a verified receipt` (:45) — `FunctionClauseError` in `Ash.create/3`. Test calls `Ash.create(%{algorithm: :es256, subject: "sha256:...", payload_hash_hex, signature_hex, verifying_key_hex}, :ingest, ...)` — a bare attrs map plus action atom; no clause of `Ash.create/3` accepts that form. Classification: **test-side API drift** (unsupported `Ash.create/3` call form at `test/xaas_web/live/witness_live_test.exs:28`).
2. `renders the typed empty state when no receipts exist` (:56) — `DBConnection.OwnershipError` "cannot find ownership process ... mode :manual": the LiveView reaches the repo outside the SQL sandbox ownership process. Classification: **sandbox-ownership connection setup**, not compile or perms.

## Gate 2 — subprocess ingest test

Command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test --include subprocess test/mix/tasks/xaas_ingest_capability_receipts_test.exs`

Result: **0/1 passed** — `ExUnit.TimeoutError` after 60000ms inside
`System.cmd("mix", ["xaas.ingest_capability_receipts", receipt_path], cd: File.cwd!(), ...)`
at `test/mix/tasks/xaas_ingest_capability_receipts_test.exs:92`. The spawned
`mix` subprocess (full mix startup + app start + Postgres ingest) exceeds the
default 60s ExUnit timeout; the assertion body never ran. Classification:
**timeout-class, still failing** — ingest correctness remains UNKNOWN (the
ingest path was never observed to complete or fail on merits).

## Gate 3 — raw-beam-verified tests under normal mix

Command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/actuation_test.exs test/xaas/castle_refusal_negative_batch4_test.exs test/xaas/boundary_limits_test.exs`

Result: **16/17 passed** (4.2s).

Failure:
- `Xaas.ActuationTest` "actuate/2 rescue carries a structured exception detail, not a raw stringified message" (`test/xaas/actuation_test.exs:182`, call at :197): `UndefinedFunctionError` — `Xaas.Actuation.actuate/2 is undefined or private`. The `actuate/2` clauses now live in `Xaas.Actuation.Kernel` (`lib/xaas/actuation.ex:342` and `:360`, inside the `defmodule Xaas.Actuation.Kernel` block starting at :319). Classification: **test-side drift** — test not updated when actuate/2 moved into the Kernel sub-module; behavior in its new home untested by this lane.

## Summary

| gate | result | classification |
|---|---|---|
| 1 | 2/5 | generator PASS; drift guard PASS (W17 red-by-design expectation obsolete — drift closed); 3 WitnessLive failures = Ash.create/3 call-form drift (2 tests) + sandbox-ownership error (1 test) |
| 2 | 0/1 | subprocess exceeds 60s ExUnit default timeout; ingest correctness UNKNOWN |
| 3 | 16/17 | 1 test-side drift: actuate/2 moved to `Xaas.Actuation.Kernel` |

## Standing

- ALIVE (observed): ash_surface generator pipeline end-to-end; drift guard byte-identical; 16/17 of actuation/castle/boundary suite.
- UNKNOWN: witness LiveView seeding (Ash.create call form + sandbox ownership); subprocess ingest correctness (timeout).
- Environment: perms incident resolved (disclosed above); root cause of +x stripping untracked.
