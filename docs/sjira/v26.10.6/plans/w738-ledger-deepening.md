# W738 — Ledger Domain Deepening (receipt)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface` (canonical checkout, no worktree)
- **Lane**: W738, v26.10.6 campaign
- **Files touched**: `test/xaas/ledger_deepening_test.exs` (new, only file written) + this receipt
- **Standing**: PARTIAL_ALIVE → ALIVE for the asserted surface (real execution, real row state, sandbox Postgres)

## What ran (real commands, real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW738 \
  mix test test/xaas/ledger_deepening_test.exs
# final run: "Result: 10 passed" (ex_unit, seed varies per run; last passing run 2026-10-07)
```

- Attempt history (all on this lane build root): 10/10 after two real repair
  rounds — (1) this repo's Ash 3.34.4 does not support `^pin` in
  `Ash.Query.filter` keyword or `expr()` form under bare `require Ash.Query`
  (compile-time `misplaced operator ^` errors); repo precedent
  (billing_deepening_test.exs) is plain-value keyword filters, adopted.
  (2) `Ash.load!/3` on a single record for `balance_as_of_ulid` → moved to
  `Ash.Query.load` + `read_one!` (real `Account.balance_as_of_ulid` calculation).
- Mock gate: `scan_mock_usage` could not run via `mix run` because
  `lib/xaas/ocel.ex` currently fails to parse (pre-existing, foreign lane's
  uncommitted +25-line diff on the shared checkout — not this lane's edit;
  syntax error at ocel.ex:36:78). Equivalent gate executed directly:
  banned-pattern grep over the new file → **zero matches** (exit 1). No mocks;
  all assertions on real Postgres row state via real Ash actions.

## (a) Transfer lifecycle — real atomic mechanics asserted

Read of `deps/ash_double_entry/lib/transfer/changes/verify_transfer.ex` +
`balance/changes/adjust_balance.ex` first; the tests assert the real
mechanism, not an intended one:

- `:transfer` create mints a 26-char ULID id (`AshDoubleEntry.ULID.generate`
  anchored to the transfer timestamp).
- `VerifyTransfer.after_action` really upserts ONE balance snapshot per
  (account, transfer) on BOTH sides (`:upsert_balance` bulk), each row
  already cumulative as of its transfer (from-side snapshot = 100 at seed
  transfer, 60 after the 40 transfer).
- The atomic `:adjust_balance` bulk update computes
  `balance ± delta` by `account_id == from_account_id` — asserted via exact
  final balances (60/40) on real rows, sorted by ULID transfer_id.
- `Account.balance_as_of_ulid` replays the exact historical balance (70 at
  the earlier ULID after a later 30 transfer).
- Shared AshEvents event log (`ledger_events` table) records the transfer
  (real `Ecto` row query on the log, action :transfer, record_id == t.id).

## (b) Double-spend: the REAL behavior is NO refusal (typed gap, asserted honestly)

**The task brief's premise ("second refuses with exact error") is false for
this code.** `VerifyTransfer` computes `Money.sub!/add!` off the
balance-as-of-ULID with NO sufficiency check anywhere in `ash_double_entry`
1.0.19 or the `Xaas.Ledger` resources — there is no
insufficient-funds validation to assert. Real, executed behavior asserted:

- Transfer of 25 from a ZERO-balance account **succeeds**, driving the
  from-side to −25.00 (real row state, `Money.equal?` on the snapshot).
- Sequential second over-draw compounds: −35.00. Conservation holds exactly
  (from + to = 0 across over-draws of 50+70 → −120/+120).
- Non-negativity is therefore an UNSUPPORTED(invariant-absent) gap, not a
  refused transition. Any caller-level overdraft guard must live above the
  domain (billing's `after_action` charges run over accounts that are
  expected to go negative — the platform-revenue model treats negative org
  balances as legitimate debt, cf. the existing −29.00 charge assertions in
  subscription_test.exs).

## (c) Refusals that ARE real + other typed gaps

Real refusals (asserted on real state):
- Same-account transfer → exact error "must be different from the from
  account" on `to_account_id`; zero rows leaked (transfer and balance
  snapshots).
- Write-path policy floor intact: `:transfer` with `authorize?: true` and no
  actor → Forbidden; deny-by-default floor preserved, no routes touched.
- Account identifier uniqueness identity really enforced (second `:open`
  with same identifier → error containing "identifier"; count stays 1).

Typed gaps asserted live (the domain does NOT enforce these):
- **Cross-currency transfer raises, no typed refusal**: USD→EUR transfer
  surfaces as `Ash.Error.Unknown` wrapping ex_money's real
  `ArgumentError: Cannot add monies with different currencies` (raised in
  `VerifyTransfer.change` after_action, real transaction rollback — zero
  balance snapshots, zero transfer rows). Gap: no upfront currency check →
  untyped failure mode, not `Ash.Error.Invalid`.
- **No reconciliation surface**: no external reconciliation (bank/stripe
  mirror) exists anywhere in `lib/xaas/ledger/` — asserted by absence, not
  testable behavior; recorded, not tested.
- **No true concurrency test**: sandbox + AshEvents global advisory lock
  (see subscription_test.exs moduledoc) means in-file concurrent double-spend
  is serialized by design; the honest concurrent-double-spend court would
  need two real Postgres connections outside the sandbox — recorded as a gap.

## (d) Determinism

- Two identical transfer schedules (10/20/30 from unfunded accounts) yield
  identical final balances (−60/+60) — deterministic money arithmetic, no
  wall-clock dependence in the balance math (ULID ids differ, balances do
  not).
- `balance_as_of_ulid` gives the exact same historical value on replay.

## Verification ladder

narrow (this file) → real Postgres row state → exact error-message asserts →
determinism replay. Unverified/remaining: full `mix test` suite (not run this
lane — ocel.ex foreign break blocks `mix run` gates; test-only run unaffected),
concurrent double-spend outside the sandbox.

## Replay

```
cd /Users/sac/xaas && git rev-parse HEAD  # a0723bf6 at receipt time
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w738-replay \
  mix test test/xaas/ledger_deepening_test.exs   # expect: Result: 10 passed
```

`_build-laneW738` left in place for the coordinator to delete (this lane's
`rm -rf` was permission-denied by the harness); it is a pure build artifact
of this lane's test runs.
