# W984gj — unclaimed-family probe: `lib/xaas/telemetry/` residue

Lane: W984gj · branch `feat/playwright-surface` · no commit (per dispatch)
Disjointness: W984ev owns `OcelNdjson` (`lib/xaas/telemetry/ocel_ndjson.ex`,
`test/xaas/telemetry/ocel_ndjson_test.exs`) — untouched by this lane; its
receipt is `docs/sjira/v26.10.6/plans/w984ev-probe.md`.

## Per-module dispositions

| module | status | evidence |
|---|---|---|
| `ocel_ndjson.ex` | COVERED (W984ev's subject, not courted here) | lane disjointness |
| `ocel_envelope.ex` | COVERED | pure generated envelope builder; exercised by `test/xaas/telemetry/ocel_envelope_test.exs` and every real-POST court (`ocel_forwarder_deepening_test.exs`, `test/xaas_web/ocel_live_server_chain_test.exs`, this lane's courts assert its output on the wire) |
| `ocel_ash_emitter.ex` | PARTIALLY COVERED → courted | per-action emit, reshape conformance, rotation, non-resource actors, unencodable-metadata rescue all courted by `ocel_ash_emitter_test.exs` / `ocel_ash_emitter_rotation_test.exs`; **`attach!/0` real handler registration was unexercised by any test** (grep: zero test references) → courted |
| `ocel_forwarder.ex` | PARTIALLY COVERED → courted | happy-path envelope, unreachable-endpoint, 500, validate-refusal, run_id determinism courted by `ocel_forwarder_test.exs` + `ocel_forwarder_deepening_test.exs`; nil-URL `forward_cancellation/1` no-op courted by `test/xaas/actuation_ocel_undo_test.exs:168`; **unexercised state-bearing branches found**: (1) `forward_cancellation/1` real-resource egress branch, (2) `forward_cancellation/1` non-resource short_name fallback branch, (3) `do_forward/2` `rescue` branch (wire-encode raise → `:ok`, zero egress) → all three courted |
| `zcode_ocel_validator.ex` | PARTIALLY COVERED | accept/refuse decisions, registry falsifier, `build_event/3` default-omap + unknown-type refusal courted by `zcode_ocel_validator_test.exs`; remaining branches (`build_event/3` explicit `:omap`/`:eid`/`:timestamp` overrides; `primary_object/0` `:error` fallback) are pure `Keyword.get_lazy` option plumbing with no new state — COVERED-ADJACENT, not courted (typed, not filler: the state-bearing decision surface is the registry lookup, already courted) |
| `zcode_ocel_validator.ex` unused-dead branch note | n/a | `validate_event_type!/1` raise path: grep shows it defined but no test/production caller found; left uncourted (dead-in-practice, disclosure only) |

## Courts landed (one file, real I/O, real processes, zero mocks)

`test/xaas/telemetry/family_court_w984gj_test.exs`:

1. **`forward_cancellation/1` real-resource branch** — real Bandit receiver
   (lane-local `:w984gj_receiver`, real TCP) receives the cancellation
   envelope; asserts `Book.create.cancelled` activity, the cancelled-outcome
   vmap (`outcome` key), idempotency key, `Book` omap, ISO timestamp, and that the wire
   envelope passes the real `Ex4pm.OCEL.validate_envelope/1`. Mutation
   rationale: reverting the `.cancelled` suffix / outcome mapping, or
   breaking `OcelEnvelope.build/3`, fails this test.
2. **`forward_cancellation/1` non-resource fallback branch** — atom subject
   takes the `Ash.Resource.Info.resource?/1 == false` fallback; receiver
   sees `NotAResourceModule.act.cancelled` and `inspect/1`-ed resource in
   the vmap. Mutation rationale: removing the fallback clause breaks
   activity-name construction (arity/shape) and fails the receiver-body
   assertion.
3. **`do_forward/2` rescue branch** — an anonymous fun in the vmap makes
   Jason encoding raise inside `Req.post`; asserts `:ok` returned and the
   receiver captured **zero** requests (encode raises before any egress).
   Mutation rationale: deleting the rescue fails (raise escapes);
   forwarding anyway fails the zero-egress assertion.
4. **`OcelAshEmitter.attach!/0` registration** — over real domain
   `Xaas.Library`, asserts the returned handler-id list contains the
   real `{mod, domain, :create, :stop}` id, `:telemetry.which_handlers/1`
   confirms the handler is live, and the returned id detaches it for real.
   Mutation rationale: an attach! that registered zero handlers or wrong
   event names fails the `which_handlers` assertions.

## Gates (real commands, real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gj mix compile`
  — exit 0 ("Generated xaas app", pre-existing warnings only).
- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gj mix test
  test/xaas/telemetry/family_court_w984gj_test.exs` — `Result: 4 passed` (exit 0).
- Mock gate `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
  — output `[]` (exit 0).

Correction recorded during court iteration: the real cancellation activity
name is lowercase short_name (`book.create.cancelled`, omap `["book"]`),
not `"Book.create.cancelled"` — first run failed on the hand-guessed
capitalization and the court now pins the real observed behavior.

## Standing

PARTIAL_ALIVE — probe closed the forwarder/emitter-registration residue;
zcode option-plumbing branches disclosed, not courted (no state).
