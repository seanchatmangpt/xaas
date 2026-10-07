# W799 — Ledger Reversal Deepening (Lane Receipt)

- **Subject**: /Users/sac/xaas @ `feat/playwright-surface` @ a0723bf6 (canonical checkout; working tree also carries W785/W464 concurrent edits; W799 added exactly 1 new file + this receipt)
- **Standing**: **PARTIAL_ALIVE** (court is green on the compensating-transfer reversal surface; SLA-credit path itself is RED upstream in the W785 lane, see typed gap 2)
- **Test file**: `test/xaas/ledger/reversal_deepening_test.exs` (new, W799-authored, 5 tests)
- **Command**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW799 mix test test/xaas/ledger/reversal_deepening_test.exs`
- **Command exit**: 0

## Real tails

Final green run (`/tmp/w799_final.log`):

```
.....
Finished in 1.1 seconds (0.00s async, 1.1s sync)

Result: 5 passed
```

Baseline (pre-existing, NOT W799-introduced): `mix test test/xaas/billing/approval_sla_credit_apply_test.exs` → exit 2, `Result: 3/5 passed, Failed: 2 tests`, real failure text:

```
* Invalid value provided for amount: insufficient funds: source balance $0.00 is less than transfer amount $25.00.
```

## What the court establishes

1. **(a) Credit→reversal round trip (real mechanism)**: There is NO `:reverse`/`:refund`/`:undo` action on `Xaas.Ledger.Transfer`/`Account`/`Balance` (`grep -rn ":refund\|:reverse\|action :undo" lib/xaas/ledger/` → 0 hits, run in receipt). The real undo mechanism is a compensating `:transfer` with from/to swapped. Court proves: fund platform +100 → approve SLA credit 25 → org $25.00 / platform $75.00 → compensating transfer 25 org→platform → org $0.00 / platform $100.00.
2. **(b) Idempotency, real behavior not invented**: double `:approve` → `{:error, %Ash.Error.Invalid{}}` (W746 DB-level `filter(expr(is_nil(approved_by)))` guard) and exactly one credit landed. Double-reverse → refused typed `Ash.Error.Invalid` with `insufficient funds` — but **by sufficiency accident** (org at $0), not a reversal-aware guard; if the org later received other funds the same double-reverse would be ADMITTED and over-reverse. Court asserts the refusal is the sufficiency message, and no second movement of money.
3. **(c) Conservation**: platform+org total invariant across credit and across compensating reverse.
4. **(d) Determinism**: two fresh orgs, identical credit+reverse cycles → identical final balances (org $0.00, platform $200.00 both times).

## Typed gaps (honest, with evidence)

- **UNSUPPORTED(reversal-action-absent)**: no dedicated reversal/refund action exists anywhere in `lib/xaas/ledger/`; grep evidence run for this receipt: `grep -rn ":refund\|:reverse\|action :undo" lib/xaas/ledger/ | wc -l` → `0`. The "refund idempotency" property is enforced nowhere at the reversal surface; the only guard is accidental (sufficiency-at-zero).
- **UNSUPPORTED(credit-path-unfundable)**: `credit_sla/1` sets no sufficiency-exemption context, so an unfunded `platform:revenue:sla-credits` account makes the live SLA-credit flow fail `insufficient funds`. Pre-existing RED in `test/xaas/billing/approval_sla_credit_apply_test.exs` (3/5, identical before and after W799) — W785's lane.
  - W799's court seeds funding via the W785-documented `xaas_ledger.allow_overdraft` context opt-in (a real transfer create, not a mock) and does NOT touch `lib/xaas/ledger/validations/`.
- **DISCLOSED**: mid-run, another lane's edit to `lib/xaas/operations/validations/incident_resolved_is_terminal.ex` (`Ash.Changeset.OriginalDataNotLoaded` struct not defined in ash 3.34.4) broke tree-wide compilation for ~13 min; W799 waited and re-ran after the owning lane fixed it. Pre-existing/concurrent, not W799.
- **DISCLOSED**: `Ash.create!` vs `Ash.create` semantics (`raise` vs `{:error, _}`) observed for real; the court uses non-banging creates so typed refusals are asserted on real returned errors, not rescued raises.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW799 mix test test/xaas/ledger/reversal_deepening_test.exs   # → 5 passed
```

## Cleanup

`_build-laneW799` NOT deleted (compilation was intermittently blocked by a concurrent lane's broken lib file; build root left for coordinator, per lane contract's else-branch).
