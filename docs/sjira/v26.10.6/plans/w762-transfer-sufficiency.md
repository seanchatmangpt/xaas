# W762 — Transfer Sufficiency Invariant

Lane W762, repo `/Users/sac/xaas`, branch `feat/playwright-surface`, base HEAD `a0723bf6`. No commit (coordinator owns commits).

## Order

From W738's receipt (`docs/sjira/v26.10.6/plans/w738-ledger-deepening.md`), finding
`UNSUPPORTED(invariant-absent)`: transfers had no sufficiency check — over-balance
transfers succeeded and drove the source balance negative.

## What landed

1. **`lib/xaas/ledger/validations/transfer_source_sufficiency.ex`** (new) —
   `Ash.Resource.Validation` on the `:transfer` create action, house idiom
   (same shape as `Xaas.Governance/Marketplace` validation modules). Before
   commit, performs a real read of the from-account `balance_as_of` (the same
   snapshot-derived balance `VerifyTransfer` itself debits) and refuses with a
   typed error when `balance < amount`:
   `Invalid value provided for amount: insufficient funds: source balance $X is less than transfer amount $Y`
   Two exemptions, both typed in-module:
   - `changeset.context[:ash_double_entry][:skip_balance_updates]` —
     ash_double_entry's documented manual-entry/minting path (VerifyTransfer
     itself short-circuits on it).
   - self-transfer (`from_id == to_id`) left to the built-in check.
2. **`lib/xaas/ledger/transfer.ex`** — `validate(Xaas.Ledger.Validations.TransferSourceSufficiency)`
   added to `create :transfer`. One line. No dep changes, no policy changes,
   no routes. Ash policy floor and API auth untouched.
3. **`test/xaas/ledger_deepening_test.new`** — extend-only edits: the two
   negative-balance pins converted to the corrected contract, one new
   exactly-sufficient court, cross-currency + policy-floor + determinism tests
   adjusted to the new contract; new `fund_account!/2` seeding helper uses the
   real `skip_balance_updates` minting path + real `:upsert_balance` snapshot
   (no mocks, Chicago-style real actions throughout).

## Courts (with mutation rationale)

- **over-balance refusal court**: unfunded source, transfer 25 USD → typed
  `insufficient funds` error, `balances_for/1` empty on BOTH sides, zero
  transfer rows. **Mutation rationale**: drop the `validate(...)` line and this
  test fails immediately — the transfer succeeds and the
  `assert message =~ "insufficient funds"` (and the `{:error, _}` match) breaks.
  This is the assert that kills a dropped-validation mutation.
- **partial-fund over-draw court**: 100 funded, 40 transferred, 61 attempted →
  refused, both balances byte-identical to before.
- **exactly-sufficient court**: 100 funded, 100 transferred → succeeds, from 0 / to 100.
- **conservation across refused over-draws**: 50 funded, 50 moved, 70 attempted
  → refused; 0/50, sum conserved.
- Existing 10 tests: all green under the corrected contract (negative-balance
  pins converted; determinism now seeds 60 and asserts 0/60; policy-floor test
  funds the source so the denial that surfaces is the policy Forbidden, not a
  validation refusal; cross-currency test seeds both sides so the currency
  ArithmeticError itself refuses, no partial state).

## Verification (real output, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW762)

- `mix test test/xaas/ledger_deepening_test.exs` → **11 passed, 0 failed**.
- Gate: deepening + `test/xaas/billing/subscription_test.exs` +
  `test/xaas/dev_seeds_test.exs` → **19/25 passed, 6 failed**, every failure
  `insufficient funds: source balance $0.00 is less than transfer amount ...`.
- Baselines WITHOUT the validation (transfer.ex reverted to HEAD for the run):
  `subscription_test` **11/11 passed**, `dev_seeds_test` **3/3 passed**.
  So all 6 gate failures are session-introduced by the invariant itself.

## Standing: PARTIAL_ALIVE with disclosed cross-lane fallout

The invariant is ALIVE on the ledger surface (11/11 deepening green, mutation
covered). Disclosed consequence: **billing charges and dev seeds transfer from
unfunded org accounts by design** (negative org balance = receivable, e.g.
`lib/xaas/billing/changes/subscription_charge_on_activate.ex`), so the absolute
refusal breaks 5 `subscription_test` + 1 `dev_seeds_test` tests that are green
at HEAD. Those files are outside this lane's file ownership. The collision is
real, not incidental: the ledger's corrected sufficiency contract and billing's
receivable contract cannot both hold without one of:
(a) billing/tests fund org accounts before charging, or
(b) billing charges route through a typed minting action (skip_balance_updates
    context, same exemption the validation already honors), or
(c) the sufficiency check is scoped (e.g. only when a balance history exists).
Decision belongs to the coordinator/billing lane. Until then, landing this lane
as-is turns those 6 tests red; full `mix test` was NOT run (and `lib/xaas/ocel.ex`
carries W758's in-flight edit, as the dispatch noted).
