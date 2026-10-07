# W41 — Xaas.Bridges.PPlan facade adaptation (receipt)

Lane: W41 (wave 2). Subject: /Users/sac/xaas @ feat/playwright-surface + /Users/sac/ash_pplan pin 5f10c979.
Written by the coordinator from the lane's completion report (2026-10-06); the lane's own output predates this file.

## What landed
- `lib/xaas/bridges/pplan.ex` — full rewrite onto `AshPPlan.A2A.Facade` (old `capture_continuation/3` removed at pin 5f10c97). Purchase run starts via `Facade.start_or_adopt/5` keyed on exact subject (adopt idempotent), two-task Workflow.Model (`:authorize` → `:renew`), Realization bindings through new `DurableAdapter` (`:xaas_pplan`).
- Park semantics preserved exactly: `RenewSubscription` conditional halt — under-limit completes; over-limit parks a durable `human_release` signal waiter and halts; release = `Facade.resume/4` delivering one consume-once signal. Parked envelope carries `continuation` = `AshPPlan.Reactor.Durable.Record` (id = subject, `continuation_schema` = record version); same envelope shape, `reactor_state: :halted`.
- Evidence remap (honest): `evidence_ref`/`receipt_ref` now `ash_pplan.durable_run:<subject>` (facade emits no `ExecutionReceipt.outcome_digest`; durable run id is the receipt identity).
- Files: `lib/xaas/bridges/pplan.ex`, `test/xaas/chicago/bridges/pplan_test.exs`, `config/config.exs` (`:extra_adapters` + `:pplan_durable_store`), `lib/xaas/application.ex` (one child: `{AshPPlan.Reactor.Durable.Store.Ets, name: Xaas.Bridges.PPlan.Store}`).

## Gates (real, verbatim)
- `mix test test/xaas/chicago/bridges/pplan_test.exs` → **5 passed, 0 failed**.
- Byte-mutation falsifier kept (one-char subject change = different durable run).

## Disclosures
- Court subjects per-test unique (durable runs persist across tests; shared fixed subject would adopt a prior terminal run).
- `:reactor` app must start for its ConcurrencyTracker ETS (setup `Application.ensure_all_started(:reactor)`; no-op under full app).
