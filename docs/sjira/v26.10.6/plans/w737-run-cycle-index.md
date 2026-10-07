# W737 — org-less (run_id, cycle) identity gap closed (receipt)

- **Lane**: W737, xaas v26.10.6 campaign
- **Subject**: canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (+ W737 uncommitted diff)
- **Standing**: ALIVE (observed execution on the exact subject; real sandbox-Postgres refusal + real mutation falsifier)
- **Diff** (3 files, no commit — coordinator owns integration):
  1. `priv/repo/migrations/20261007010000_add_orgless_run_cycle_partial_unique_index.exs` (new) — `CREATE UNIQUE INDEX ultracode_epochs_orgless_run_cycle_index ON ultracode_epochs (run_id, cycle) WHERE org_id IS NULL`.
  2. `lib/xaas/ultracode/epoch.ex` — `postgres.custom_indexes` declaration of the same partial index so ash_postgres adds the matching Ecto `unique_constraint` to every changeset. Without it the DB refusal surfaced as an unhandled `Ecto.ConstraintError` wrapped in `Ash.Error.Unknown` (observed in this lane's first run); with it the refusal is a typed invalid-attribute error, message "already exists", fields `[:run_id, :cycle]`, message "has already been taken".
  3. `test/xaas/ultracode/run_receipt_deepening_test.exs` — W717's org-less gap test (which asserted the duplicate was ACCEPTED) converted to the closed-behavior refusal test; org-scoped twin untouched and still green.

## Before / after

- **Before (W717 finding)**: `identity(:unique_run_cycle, [:run_id, :cycle])` backed by `UNIQUE (org_id, run_id, cycle)`; Postgres NULL-distinct ⇒ duplicate org-less `(run_id, cycle)` epochs ACCEPTED. Test observed `{:ok, _dup}`.
- **After (observed)**: duplicate org-less epoch refuses:

```
detail: "Key (run_id, cycle)=(4ae1c636-..., 0) already exists."
class: :invalid  (typed invalid-attribute refusal, "has already been taken")
```

## Verification (real commands, real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW737 \
    mix test test/xaas/ultracode/run_receipt_deepening_test.exs --trace
Finished in 1.1 seconds (1.1s async, 0.00s sync)
Result: 10 passed
```

(First run of the lane paid the fresh `_build-laneW737` full compile, ~437 MB.)

Adjacent suite warm run (resource change regression sweep):

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW737 \
    mix test test/xaas/ultracode/run_org_id_test.exs run_start_test.exs \
      next_epoch_test.exs epoch_reactor_test.exs lease_test.exs
Result: 45 passed
```

### Mutation evidence (real falsifier, run in the sandbox, nothing persisted)

```
$ mix run /tmp/w737_mutation_check.exs   # sandbox checkout, DROP INDEX, duplicate insert
MUTATION RESULT (index dropped): {:ok, %Xaas.Ultracode.Epoch{... exact_subject: "duplicate-cycle" ...}}
```

With the index dropped the duplicate org-less epoch is ACCEPTED again — the W717
gap returns — so the regression test's `assert {:error, error}` (test line 129,
`duplicate (run_id, cycle) epoch for an ORG-LESS run is REFUSED`) FAILS if the
migration is dropped or never applied. That assert is the mutation kill site.

## Sandbox provenance

- `mix test` alias = `ecto.create --quiet, ecto.migrate --quiet, test`; the test DB is `xaas_test` (`config/test.exs`), separate from `xaas_dev` — the migration reached the sandbox through the normal alias path, dev data untouched.
- Applying to dev later: plain `MIX_ENV=dev mix ecto.migrate` from the canonical checkout (the migration is `create_if_not_exists`, idempotent, no data rewrite). Not run in this lane.

## Notes / gaps

- Mid-lane, `epoch.ex` was overwritten on disk by another writer once; the `custom_indexes` block was re-applied and the final green run is on the re-applied state. Coordinator should make sure the integrated `epoch.ex` retains the `postgres.custom_indexes` block — without it the refusal is an unhandled Ecto.ConstraintError raise, not a typed error.
- Migration-generator drift: a future `mix ash_postgres.generate_migrations` run will now see the custom index as declared state; if it proposes a redundant create, skip/absorb — the hand migration is the creation authority.
- No `@moduletag :eu_ai_act`; no Art-line tie (operational control-plane identity, no personal-data processing).
- Lane build root `_build-laneW737` deleted after the final green run.
