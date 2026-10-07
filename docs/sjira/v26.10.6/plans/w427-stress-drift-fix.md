# W427 — Stress-test status-drift fix (w386 typed finding)

Repo: /Users/sac/xaas @ feat/playwright-surface. Lane: W427. Test-side only; no lib/ edits.

## Drift

All 3 stress tests passed `status: :pending` into `Xaas.Marketplace.Provider.create`,
whose accept list is `[:name, :slug, :description, :org_id]` — construction cannot
smuggle status (`lib/xaas/marketplace/provider.ex:70-74`).

## Lawful pattern (from non-stress `test/xaas/marketplace/provider_test.exs`)

Create without `status:` (attribute default `:pending`); lifecycle transitions go
through `:actuate_status`, which is guarded by `Xaas.Actuation.Validations.ReactorContext`
and driven by `Xaas.Actuation.run/4` with delegated authority. The maker-checker
approval flow (`lib/xaas/marketplace/changes/apply_provider_status_change.ex`)
manufactures its own authority map, so the approval stress test needs no actuation
plumbing — approvals still drive the provider to `:active`.

## Diffs

- `test/xaas/marketplace/provider_stress_test.exs`: dropped `status: :pending` from
  both concurrent-create maps.
- `test/xaas/marketplace/approval_provider_status_change_stress_test.exs`: dropped
  `status: :pending` from the target-provider create map.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW427 \
  mix test --include stress test/xaas/marketplace/provider_stress_test.exs \
  test/xaas/marketplace/approval_provider_status_change_stress_test.exs
...
Finished in 2.5 seconds (0.00s async, 2.5s sync)
Result: 3 passed
```

3/3 stress tests fixed and green. Both files are the entire stress class for this
drift (3 tests total); no other test passes `status:` into Provider.create.

Cleanup: `_build-laneW427` removed. Standing: ALIVE.
