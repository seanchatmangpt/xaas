# W983j — `:reverse` sufficiency fix (W982i attack-1 owner lane)

- **Lane**: W983j, xaas v26.10.6 campaign, branch `feat/playwright-surface` (working tree, NOT committed)
- **Task**: fix the W982i adverse-court finding that `Xaas.Ledger.Transfer :reverse`'s
  declared `TransferSourceSufficiency` validation is dead code (attack 1,
  `BUILD_BROKEN(invariant-absent)`), preserve attack-3/4 guarantees, resolve the
  authority/exposure finding, add the follow-up court leg.
- **Fix shape**: fix the invariant, not the probe —
  `lib/xaas/ledger/changes/reverse_transfer.ex`: after `force_change_attributes`
  installs the swapped compensating-transfer attributes
  (`amount`, `from_account_id` = original recipient, `to_account_id`, ...),
  the change now invokes
  `Xaas.Ledger.Validations.TransferSourceSufficiency.validate/3` **explicitly**
  (`run_sufficiency/2`), so the check runs against the real swapped ids with the
  same typed `insufficient funds` error the ordinary `:transfer` action produces.
  Chosen over re-plumbing `accept/params` because `:reverse` is `accept([])` by
  design (all writes come from the trusted original row, never user input), so
  the minimal correct path is an explicit in-change invocation. The W785
  exemptions (`skip_balance_updates` context, `xaas_ledger.allow_overdraft`
  context) apply unchanged — no separate overdraft story for `:reverse`.
- **Exposure finding (attack 2 follow-up)**: `Xaas.Ledger.Transfer` declares no
  `AshJsonApi.Resource` extension and no JSON:API routes; `XaasWeb.ApiRouter`
  mounts the `Xaas.Ledger` domain, but routing is resource-declared
  (`lib/xaas_web/api_router.ex:1-22` moduledoc) and Ledger resources "declare no
  routes". No `transfer`/`reverse` route exists anywhere in `lib/xaas_web/` —
  **no BLOCKED(exposure)**; `:reverse` is not publicly routable. Per task, no org
  policy invented (Account has no tenant attribute — product decision, unchanged).
  W982i's REFUSED(policy-absent) standing on the deny floor stands, report-only.
- **Court**: appended the W983j follow-up leg to W982i's file
  (`test/xaas/ledger/transfer_reverse_adverse_court_test.exs`): underfunded
  compensating source refuses with the sufficiency error (Leg A), sufficient
  funds still admits and lands the recipient at 0.00 (Leg B — W968c happy path
  unbroken). W982i's two attack-1 GAP legs (which asserted the negative-drain
  bug) were converted to assert the fixed behavior: refusal + consequence-free
  balances, and the W785 `allow_overdraft` context now being a **real** exemption
  (underfunded reversal admits with the context). No other lane's files touched;
  `reversal_deepening_test.exs` untouched.

## Executed (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983j mix compile   # fresh root, full recompile, exit 0
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983j mix test test/xaas/ledger/transfer_reverse_adverse_court_test.exs
  # run 1 (pre-fix-of-my-own-leg): 6/7 — my follow-up leg had a wrong platform-balance expectation (10.00 vs 30.00, two credits from one platform), test bug, fixed
  # run 2: 7 passed
  # run 3: 7 passed (×2, deterministic)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983j mix test test/xaas/ledger/reversal_deepening_test.exs  # 9 passed, ×2
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983j mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'  # []
```

## Per-attack re-verdicts (post-fix)

| Attack | W982i verdict | Post-fix verdict | Standing |
|---|---|---|---|
| 1 sufficiency vs. compensating mint | GAP, negative drain admitted | underfunded reversal **refused** with `insufficient funds`; org keeps 5.00, platform 10.00 (consequence-free refusal); W785 context now a real exemption | **ALIVE** (invariant now enforced) |
| 2 authority / exposure | REFUSED(policy-absent) | unchanged, report-only; + exposure check: no JSON:API route for transfer/reverse, no BLOCKED(exposure) | REFUSED(policy-absent), report-only |
| 3 concurrent replay | HOLDS | HOLDS (7/7 runs include it) | **ALIVE** |
| 4 DB partial unique index | HOLDS | HOLDS (23505 naming `ledger_transfers_reverses_transfer_id_index`) | **ALIVE** |
| W968c regression | 9/9 | 9/9 ×2, untouched | ALIVE |

## Standing

- `Xaas.Ledger.Transfer :reverse` sufficiency invariant: **ALIVE** (fix in
  `lib/xaas/ledger/changes/reverse_transfer.ex`, court 7/7 ×2 on fresh lane root)
- Court file (W982i's + W983j follow-up leg): **ALIVE**
- Authority policy on Transfer: **REFUSED(policy-absent)** — unchanged owner-lane
  work order, not addressable without a tenant attribute (product decision)
- Build root `_build-laneW983j`: LEFT IN PLACE — `rm -rf` was permission-denied
  in this lane's session; coordinator should delete it at integration
  (lane-lease cleanup law).
- `test/xaas/ledger/reversal_deepening_test.exs` shows as working-tree-modified,
  but the diff is NOT this lane's (pre-existing from another lane; 9/9 ×2 green
  as-modified).
