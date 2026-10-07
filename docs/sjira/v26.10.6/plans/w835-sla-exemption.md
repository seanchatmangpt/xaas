# W835 — SLA-credit approve: W785 overdraft exemption for `platform:revenue:sla-credits`

Lane W835, xaas v26.10.6, branch `feat/playwright-surface`, HEAD at start a0723bf6. No commit (per lane rules).
Scope: production fix only; zero test-file edits.

## Before (observed, real tails)

`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW835 mix test test/xaas/billing/approval_sla_credit_apply_test.exs`
→ `Result: 3/5 passed, Failed: 2 tests`:

- `test approving from a distinct approver credits the org's real Ledger.Account by the real amount` (L84)
- `test approving twice does not double-credit` (L108)

Both failed with
`Invalid value provided for amount: insufficient funds: source balance $0.00 is less than transfer amount $10.00 / $25.00`
— the transfer FROM the never-funded `platform:revenue:sla-credits` platform
account refused by `Xaas.Ledger.Validations.TransferSourceSufficiency`
(W762 invariant, W785 exemption list).

Root cause: W785's exemption list covered the three charge paths
(`ApprovalBackupRetentionChangeChargeOverage`, `SubscriptionChargeOnActivate`,
`SubscriptionProrateTierChange`) but omitted the SLA-credit path — the one flow
that transfers **FROM** the unfunded platform revenue account. Platform revenue
accounts are receivable-style by design (they report outflows without requiring a
positive balance). W785's lane saw no over-draw in its own tests, so the omission
was invisible there (W785-collision finding, W799 receipt).

## Fix

Both SLA-credit change modules (they share the flow, both edited):

- `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`
- `lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex`

Added the W785-documented per-caller opt-in on the `:transfer` create:

```elixir
Ash.Changeset.for_create(:transfer, %{...},
  # W785/W799/W835 comment citing the plans
  context: %{xaas_ledger: %{allow_overdraft: true}}
)
|> Ash.create(authorize?: false)
```

Implementation note (cost one iteration): the opt must go on the `for_create/4`
`context:` opt, **not** on `Ash.create/2` opts — my first attempt passed
`context:` to `Ash.create/2` and the validation still refused (`Ash.create/2`
does not merge that key into the changeset context seen by validations; the
TransferSourceSufficiency moduledoc already warns `set_context/2` after
`for_create/4` does not survive either).

## After (real tails, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW835)

| Suite | Result |
|---|---|
| `test/xaas/billing/approval_sla_credit_apply_test.exs` | 5/5 passed |
| `test/xaas/ledger/ledger_deepening_test.exs` + `test/xaas/billing/subscription_test.exs` | 11 passed (4 + 7) |
| `test/xaas/ledger/reversal_deepening_test.exs` | 5 passed |

W785 exemption sites unaffected; no test-side exemptions introduced (test files untouched, verified by edit log — only the two lib files changed).

## Mutation rationale (falsifier)

Dropping the `allow_overdraft` context from either module re-triggers
`TransferSourceSufficiency` and fails the same two asserts:
`assert {:ok, _} = ...approve(...)` at
`test/xaas/billing/approval_sla_credit_apply_test.exs:84` and `:108`
(L108 mutates because the rollback test relies on the credit succeeding on the
first approve before the second approve attempts a double credit). The
`insufficient funds` message in the failure output is the distinguishing
signature — a test-side exemption would hide this; the production fix makes the
mutation surface as the exact pre-existing red.

Standing: PARTIAL_ALIVE — production path fixed and verified on the exact
subject (5/5 + neighbors green, real tails above); not committed (coordinator
owns integration); `_build-laneW835` deleted at integration per lane lease law
or left for coordinator if in-flight conflicts prevent it.
