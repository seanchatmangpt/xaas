# W175 — Shared `_build/test` Reconciliation Receipt

- **Lane**: W175 (integration), v26.10.6 convergence
- **Subject**: /Users/sac/xaas, branch `feat/playwright-scope`... (`feat/playwright-surface`), shared `_build/test`
- **Date**: 2026-10-06
- **Prior state**: W136 disclosed failing ash_surface path-dep compile in shared `_build/test` (worked in fresh build roots). W132's `mix ecto.migrations` was blocked on it.

## Stage 1 — `mix deps.compile ash_surface --force`

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix deps.compile ash_surface --force 2>&1 | tail -6
```

Output (tail):

```
 1616 │         Macro.Env.location(__ENV__)
      │         ~~~~~~~~~~~~~~~~~~~~~~~~~~~
      │
      └─ /Users/sac/xaas/deps/spark/lib/spark/dsl/extension.ex:1616: AshR2RML.Resource.Sparql.Query (module)

Generated ash_surface app
```

**Result: PASS.** Warnings only (Macro.Env.location deprecation via spark dsl extension); app generated. **The W136 failure class did not reproduce** — no quarantine of `~/ash_surface/lib/` orphaned sync outputs (ash_a2a/ash_r2rml/audit_trail/notification_extension) was needed; zero file moves performed.

## Stage 2 — full app compile

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile 2>&1 | tail -3
```

Output (tail):

```
    │
    └─ lib/xaas/ultracode/epoch_reactor.ex:1: Xaas.Ultracode.EpochReactor (module)
```

**exit=0. PASS.** (Warning tail only.)

## Stage 3 — `mix ecto.migrations` (W132's blocked stage)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix ecto.migrations 2>&1 | tail -4
```

Output (tail):

```
  up        20261005000000  add_witness_tables
  up        20261005235901  add_graphlaw_engine_registry
  up        20261006000000  repair_witness_certified_receipts
```

**exit=0. PASS.** Repo-level migrations listed; latest three all `up`, including the 2026-10-06 witness certified-receipts repair.

## Scope compliance

Owned actions: ran the three read/compile commands above + this receipt. No source edits, no git operations, no quarantine moves.

## Standing

| Stage | Standing |
|---|---|
| ash_surface path-dep compile (shared `_build/test`) | ALIVE (this subject, exit 0 / generated) |
| Full `MIX_ENV=test mix compile` | ALIVE (exit 0) |
| `mix ecto.migrations` | ALIVE (exit 0) |

W136's shared-build failure is reconciled at subject `feat/playwright-surface` HEAD `d1db2b03` + current worktree state; W132's blocked stage is unblocked.
