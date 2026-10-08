# W984dq3 — DurableAdapter depth court (lane receipt)

Lane: W984dq3, xaas v26.10.6 campaign, branch `feat/playwright-surface`, canonical checkout
`/Users/sac/xaas` (no commit — coordinator owns transitions).

## Subject

`Xaas.Bridges.PPlan.DurableAdapter` (+ its two step modules `Steps.AuthorizePayment`,
`Steps.RenewSubscription`) in `lib/xaas/bridges/pplan.ex` (411 lines). W984do census:
next-ranked uncovered module, 0 direct tests of the adapter surface; the bridge-level
park/resume behavior is covered by `test/xaas/chicago/bridges/pplan_test.exs` — this lane
is the ADAPTER's own surface, per task.

## Module surface analysis (read fresh at HEAD 25292a7c)

- `DurableAdapter` (`AshPPlan.Reactor.Adapter` behaviour): `id/0` → `:xaas_pplan`,
  `available?/0` → `true`, `ops/0` → `[:process_authorize, :process_renew]`, `step/2` —
  a **hand-rolled table lookup**, not upstream `Adapter.resolve/4`: its unknown-op refusal
  shape is `{:error, {:unsupported_op, op}}`, which DIFFERS from the behaviour's documented
  `{:error, %{reason: :unsupported, adapter: id, detail: {:unknown_op, op}}}` (deps
  adapter.ex `resolve/4`) and also skips upstream's `available?` gating inside `step/2`
  (upstream pops an `:available?` opt; xaas's `step/2` ignores options entirely).
  Real finding, now pinned by court.
- `Steps.AuthorizePayment` — pure: `number/1` string parsing (strict integer parse, partial
  parses → nil → `{:error, :invalid_claim}`); boundary is strict `>` (`amount == limit` is
  `:authorized`, no human gate); nil/partial claims refuse typed.
- `Steps.RenewSubscription` — the human-release gate: context `:human_release` wins; else
  consume-once signal take against the real store (park → re-check closes delivery race,
  mirroring upstream `Steps.Await`); over-limit with no durable context cannot park —
  **typed FunctionClauseError crash** (`park_and_halt/2` has no nil clause), not a silent
  guessed park. Pinned as the durable-context contract.
- Persistence format/recovery: runs live in a real `AshPPlan.Reactor.Durable.Store.Ets`
  process (private ETS, die with process). Invariants witnessed: record keyed by exact
  subject URN (`record.id == subject`), `status :waiting` → adopt-on-restart determinism
  (re-`run_purchase` adopts the same run id, no sibling run), consume-once signal (after
  release, `pending_signal == nil` and waiter cleared — no double-spend), sealed terminal
  run is idempotent under re-delivery (`resume` returns sealed `:completed`, no re-exec).

## Court

`test/xaas/bridges/w984dq3_durable_adapter_test.exs` — 5 Chicago tests, real ETS store,
real facade/engine execution, real step modules, no mocks:

1. adapter metadata + step-table roundtrip, ×2 call determinism.
2. typed unknown-op refusal `{:error, {:unsupported_op, op}}` + ops/step bijection
   (foreign-adapter ops `:file_write`/`:await`/`:command`/`:domain_action` refuse).
3. AuthorizePayment boundary: invalid claims typed-refuse, strict `>` limit boundary,
   string-amount parsing, pure determinism.
4. RenewSubscription: context release completes, no-gate completes `released_by: nil`,
   park-without-durable-context is a typed FunctionClauseError (contract, not silent park).
5. Real-store recovery: persist → `Facade.fetch` roundtrip (id/status `:waiting`),
   adopt-on-restart determinism (same record id), consume-once signal drain
   (`pending_signal`/`get_waiter` nil after release), sealed-terminal re-resume idempotent,
   final `status == :completed`.

Each test carries a mutation rationale (deterministic lookup, refusal shape, `>` vs `>=`,
release-gate honoring, adopt vs sibling-mint, double-spend) in comments.

## Verification (real output)

- Run 1 (fresh root `_build-laneW984dq3`, full recompile of 209 deps + app): 3/5 — 2 lane
  test bugs (release_purchase takes the `%Record{}` from `parked.provenance.continuation`,
  not the envelope; over-precise pattern on authorization map). Fixed in-lane, no lib edits.
- Run 2 (warm): 4/5 — 1 pattern over-precision; fixed.
- Run 3 (warm): **5 passed, EXIT=0** — `mix test test/xaas/bridges/w984dq3_durable_adapter_test.exs`,
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dq3`.
- Fresh-root witness ×2: full `rm -rf _build-laneW984dq3` recompile + rerun —
  PENDING (patch on completion).
- Only files written: the test file + this receipt. No lib/ or config/ edits.

## Standing

- Tests: ALIVE on subject 25292a7c + lane test file (5/5, two real execution runs, second
  full-fresh-root witness pending patch-in).
- Module standing: PARTIAL_ALIVE — durable adapter surface now directly witnessed
  (mapping, typed refusals, boundary, consume-once recovery semantics); durability is
  process-lifetime ETS (not cross-restart), which remains upstream `Store.Ets`'s contract.
- No typed refusals encountered. Lane build root `_build-laneW984dq3` left for coordinator
  per fanout law unless the fresh-root run deletes it (it will be recreated by that run and
  left).
