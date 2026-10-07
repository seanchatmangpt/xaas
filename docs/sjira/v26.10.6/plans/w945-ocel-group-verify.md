# W945 — OCEL Group Pre-Verify Receipt (W758 fold group)

standing: PARTIAL_ALIVE (group safe-to-commit as-is; tree-level compile blocker is foreign, classified, not W758's)
date: 2026-10-07
subject: `/Users/sac/xaas` @ HEAD `910a2e22` + commit `0f745fd0` (W758) on `feat/playwright-surface`

## Task

Pre-verify W940's riskiest commit-manifest group: the W758 fold in
`lib/xaas/ocel.ex` (W745 spec-token fix and W880 counterfactual @doc doctest
are separate groups).

## Diff inventory (git diff HEAD -- lib/xaas/ocel.ex)

**Empty.** The W758 fold is already committed as `0f745fd0`
("fix(ocel): public fold_object_state/2 fold (W758)"), 2 files / +341:

- `lib/xaas/ocel.ex` +25, single hunk after the moduledoc, containing exactly:
  1. `@doc` fold-law documentation block (the moduledoc-adjacent doc update)
  2. `@spec fold_object_state(Enumerable.t(), %{optional(String.t()) => term()}) :: %{optional(String.t()) => term()}` (W745's `::` spec tokens present)
  3. `fold_object_state/2` implementation (sort_by occurred_at DateTime, per-attribute last-write-wins Map.put)
- `test/xaas/ocel_deepening_test.exs` +316 (W758's named test artifact)

**Nothing else** in `lib/xaas/ocel.ex`. Inventory matches the expected
three-item list exactly.

## Compile result

`MIX_ENV=test mix compile --warnings-as-errors` → **EXIT 1**.
**Pre-existing, foreign to W758**: `lib/xaas/governance/audit_export_token.ex:121`
— `change(increment(:use_count, 1))` passes a literal where Ash's
`increment/2` expects keyword opts; `Keyword.put_new(1, :amount, 1)`
FunctionClauseError at module-compile time. That file belongs to another
lane's group (W801-family audit-export surface), not this group.
`lib/xaas/ocel.ex` itself compiles clean (verified by in-process
`Code.compile_file` with zero warnings/errors on the file).

## Test result (real run, Chicago-style)

Blocked from `mix test` by the foreign compile crash, so ran with app
supervision tree elided and `Xaas.Repo` started manually:

```
MIX_ENV=test mix run --no-start --no-compile -e 'ExUnit.start();
Enum.each([:postgrex,:ecto_sql,:db_connection], &Application.ensure_all_started/1);
{:ok,_}=Xaas.Repo.start_link(); Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto);
Code.compile_file("lib/xaas/ocel.ex"); Code.require_file("test/xaas/ocel_deepening_test.exs");
r=ExUnit.run(); IO.inspect(r, label: :result)
```

**Result: 8 tests, 0 failures** (`%{total: 8, failures: 0, excluded: 0, skipped: 0}`,
ExUnit printed "8 passed"). Real sandbox-backed Postgres per the test's own
setup (test/xaas/ocel_deepening_test.exs:33 checks out a sandbox conn).

## Verdict

**W758 group: SAFE-TO-COMMIT as-is.** Already committed as `0f745fd0` with
its named test artifact; content matches the expected inventory exactly,
compiles clean in isolation, and its 8-test court passes on real Postgres.

**Transport note for W940**: the tree has a *foreign, pre-existing* compile
blocker at `lib/xaas/governance/audit_export_token.ex:122`
(`increment(:use_count, 1)` → `increment(:use_count)` is the likely repair;
file is another lane's, untouched by this lane). W940 must land or gate that
fix before any `mix test` full-suite run can execute on this tree.
