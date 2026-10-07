# W545 — OCEL fitness integration witness (Art. 72 / w511 over the real xaas OCEL stream)

Lane: W545 · Repo: /Users/sac/xaas @ feat/playwright-surface · Build root: `_build-laneW545`
Contract: write only `test/xaas/telemetry/ocel_fitness_integration_test.exs` (new) + this file. No lib edits.

## Define

Witness that the real xaas OCEL emitter (`Xaas.Telemetry.OcelAshEmitter`) emits a
real event stream that fits a hand-derived process model exactly, scored with
w511's fitness machinery (`BeamPM.Art72Conformance`: Definition 7.2 token-replay
fitness C(L,P) = 1/2(1 − m/c) + 1/2(1 − r/p), underfed-fire replay convention,
`log_fitness/2` + `drift_decision/2`).

## Measure / Explore

* Real emitter: `/Users/sac/xaas/lib/xaas/telemetry/ocel_ash_emitter.ex` —
  attaches to real Ash `:telemetry` `:stop` events, emits OCEL 2.0 event records
  (`id`/`type`/`time`/`attributes`/`relationships`), appends one complete
  per-line document to the real `priv/ocel/ash-actions.ndjson`.
* `BeamPM.Art72Conformance` is NOT a mix dep of xaas (checked `mix.exs`/`mix.lock`
  2026-10-06); beam4pm is the sibling repo `/Users/sac/beam4pm`
  (`lib/beam4pm_art72_conformance.ex`). Per contract step 3, the formula is
  replicated INLINE in the test (`Art72` sub-module) — identical struct,
  identical underfed-fire replay convention, cited to w511. Disclosed in the
  test moduledoc.
* Model (hand-derived, refined against the REAL stream — one non-replay
  actuation emits exactly `actuation_receipt.prepare` →
  `provider.actuate_status` → `actuation_receipt.seal`): silent
  `[start]` (source transition) → `prepare` → `actuate` →
  `sealed_receipt` → silent `[end]`; initial marking {} (empty —
  seeding `p0` in the initial marking AND letting `[start]` produce it
  double-issues the token and penalizes a perfect trace with an excess
  remaining token; found via a real failing run, fitness 0.9167 for a
  fit model), final {p_end:1}.
* Real-event capture: offset-delta read of the real shared ndjson, filtered by
  the emitter's real `"<short_name>.<action>"` type law, same
  concurrent-append attribution discipline as `ocel_ash_emitter_test.exs`.

## Develop

`test/xaas/telemetry/ocel_fitness_integration_test.exs`:

1. Drive one real `Xaas.Actuation.run(Provider, :actuate_status,
   %{status: :active}, ...)` through the real sandbox (mirrors `actuation_test.exs`
   setup; `authorize?: false` on the admitted control-plane path only).
2. Assert the real filtered event sequence is exactly
   `["actuation_receipt.prepare", "provider.actuate_status", "actuation_receipt.seal"]`
   (emitter determinism).
3. Map real events → w511 log shape: one trace
   `[start, prepare, actuate, sealed_receipt, end]`. `log_fitness/2` == 1.0
   exactly, `drift_decision(1.0, 0.05) == :NO_DRIFT`.
4. Perturbed log (drop the sealed-receipt event): fitness == 11/15
   (0.7333) < 1.0, stats `%{consumed: 3, produced: 5, missing: 1,
   remaining: 1}`, `drift_decision(0.7333, 0.05) == :DRIFT`.

## Implement / receipt

* Command: `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW545 mix test test/xaas/telemetry/ocel_fitness_integration_test.exs`
* Mapping table (real OCEL field → witness use):

| real OCEL field | witness use |
|---|---|
| `event["type"]` = `<short_name>.<action>` | trace activity name (mapped to model transition) |
| `event["attributes"]["outcome"]` | (`"ok"` on both emitted events; the fitness math is order/identity, not attribute, driven) |
| `event["time"]` | emission order = trace order (ndjson append order) |
| `event["id"]` | per-event identity (unused by fitness, read real) |

* Verdict: **ALIVE (witnessed).** Gate: `mix test
  test/xaas/telemetry/ocel_fitness_integration_test.exs` → `2 passed,
  0 failed` (real output, 2026-10-06, build root `_build-laneW545`).
  Strict compile: `MIX_ENV=test mix compile --warnings-as-errors` →
  exit 0. Fitness values: unperturbed real stream = **1.0**
  (`:NO_DRIFT` at ε=0.05); perturbed (sealed-receipt dropped) =
  **11/15 ≈ 0.7333** (`:DRIFT`). Model corrections found via real
  failing runs and fixed, not hand-waved: (a) the real sequence is
  prepare→actuate→seal, not create-based as first assumed; (b) empty
  initial marking (the `[start]` source transition + a seeded p0
  double-issued the token, scoring 0.9167 for an exactly-fitting trace).
  Lane build root `_build-laneW545` remains on disk per fan-out law
  (coordinator deletes at integration).
