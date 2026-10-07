# W982i — Independent Adverse Court: `Xaas.Ledger.Transfer :reverse` (W968c SPEC-27)

- **Lane**: W982i, xaas v26.10.6 campaign, branch `feat/playwright-surface` (working tree, NOT committed)
- **Subject**: new court `test/xaas/ledger/transfer_reverse_adverse_court_test.exs` (6 tests, 4 attacks)
- **Constraint honored**: no W968c test or production code modified; W968c's `reversal_deepening_test.exs` cross-checked green (9/9) after my runs.
- **Environment**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982i` (fresh root created this session, full recompile, exit 0); Postgres = real local `postgresql@14`, sandboxed per test.

## Executed

```
mix compile                                        # exit 0 (fresh _build-laneW982i)
mix test test/xaas/ledger/transfer_reverse_adverse_court_test.exs   # run 1: 6 passed
mix test test/xaas/ledger/transfer_reverse_adverse_court_test.exs   # run 2: 6 passed (×2, deterministic)
mix test test/xaas/lexical/... (no)                 # (cross-check only)
mix test test/xaas/ledger/reversal_deepening_test.exs               # 9 passed (W968c, untouched)
```

Real tails: two consecutive 6/6 runs; scratch probe file used during investigation was deleted (`test/xaas/ledger/w982i_probe_test.exs` removed).

## Per-attack verdicts

### Attack 1 — compensating mint vs. source account state — **GAP (real, typed): sufficiency-dead-code**

**Observed behavior (asserted in court, run twice):** the compensating mint does NOT
respect the source account's balance. Setup: platform seeded 30.00, org credited
20.00, org spends 15.00 (real `:transfer` creates). `:reverse` on the original
credit → **`{:ok, ...}`, org drains to −15.00**. Compensation does not respect
account state.

**Mechanism (read from source, not inferred from the failure alone):** `:reverse`
uses `accept([])` and forces `amount/from/to/reverses_transfer_id` in a
`before_action` hook (`lib/xaas/ledger/changes/reverse_transfer.ex:58-64`). The
declared `validate(Xaas.Ledger.Validations.TransferSourceSufficiency)` runs
*before* `before_action`, at which point `from_account_id`/`to_account_id` are
nil → `check_sufficiency/1` takes the `is_nil → :ok` skip
(`lib/xaas/ledger/validations/transfer_source_sufficiency.ex:62-64`).
The sufficiency validation on `:reverse` is dead code. W968c's court never
probed an underfunded compensating source, so this was invisible to it.

**Also recorded:** the W785 `xaas_ledger.allow_overdraft` context question is
**vacuous** on `:reverse` — with or without the context the outcome is identical
(negative-drain admitted), because no check runs at all. Asserted in court as
identical-outcome.

Direction note (fix orientation for the owner lane): the compensating source is
the **original recipient** (from/to are swapped), so a lawful fix is to re-run
the sufficiency check inside the `before_action` after forcing the attributes
(or move validation after attribute forcing) — not my lane's diff.

### Attack 2 — authority — **REFUSED(policy-absent), report-only**

`Xaas.Ledger.Transfer` carries only the ash-migration Phase 5 deny-by-default
floor: `bypass action_type(:read)` + `policy always() do forbid_if(always())`
(`lib/xaas/ledger/transfer.ex:13-26`). There is **no authorizing policy for
`:reverse`** (nor for `:transfer`/`:open`), and `Xaas.Ledger.Account` has **no
org/tenant attribute** to scope a cross-org policy against. Asserted behavior:
`authorize?: true` with any actor (nil actor) → `{:error, %Ash.Error.Forbidden{}}`.
So cross-org attack is refused — but only in the sense that *everything* is
refused; no legitimate actor can be admitted either. Typed finding:
**REFUSED(policy-absent)** — a real per-action policy (and tenant scoping on
Account) is required before `:reverse` can be lawfully actuated by anyone.

### Attack 3 — concurrent replay — **HOLDS**

Two concurrent `Task.async` processes over real Postgres (joined to the test's
sandbox connection via `Sandbox.allow/3`), same `transfer_id`: **at most one
succeeds**; observed loser error is reversal-aware: `transfer already reversed`
(field `:transfer_id`). Org balance reads 0.00 after (exactly one compensating
mint moved money). Caveat recorded honestly: the `Sandbox.allow` pattern
serializes both attempts on one connection, so this exercises the
application-level guard; the true cross-connection race window is backstopped
by attack 4's DB index.

### Attack 4 — DB-layer partial unique index — **HOLDS**

Raw `Xaas.Repo.query!` insert of a second reversal row (same
`reverses_transfer_id`, fresh 16-byte id) → **Postgres 23505 unique_violation
naming `ledger_transfers_reverses_transfer_id_index`** (the partial index,
`where: "reverses_transfer_id IS NOT NULL"`). Observed nuance: raw SQL surfaces
`Postgrex.Error` (23505), not Ecto's `ConstraintError` translation — that
translation applies to changeset inserts only; asserted accordingly. The
lawfully minted reversal remains the only reversal row discoverable for the
original (count == 1).

## Standing

| Attack | Verdict | Standing |
|---|---|---|
| 1 sufficiency vs. compensating mint | real typed gap, asserted in court | **BUILD_BROKEN(invariant-absent)** — sufficiency validation on `:reverse` is dead code |
| 2 cross-org/actor authority | refused (deny floor), no authorizing policy | **REFUSED(policy-absent)**, report-only |
| 3 concurrent replay | at most one wins | **ALIVE** |
| 4 DB-layer unique index | 23505 on the partial index | **ALIVE** |
| W968c regression cross-check | 9/9 untouched, green | ALIVE (adjacent surface intact) |

- Court file: `test/xaas/ledger/transfer_reverse_adverse_court_test.exs` — **ALIVE** (6/6 ×2 on fresh lane root)
- Transfer/`reverses_transfer_id` + partial index: **ALIVE**
- Sufficiency-on-reverse: **BUILD_BROKEN(invariant-absent)** — owner-lane work order
- Authority policy on Transfer: **REFUSED(policy-absent)** — owner-lane work order

## Lane discipline

- No W968c files or production code touched (git shows only my new test file + this receipt).
- Scratch probe `test/xaas/ledger/w982i_probe_test.exs` deleted.
- Build root `_build-laneW982i` left in place (task permits leaving; disk recovered to 56GB free mid-lane after a transient ENOSPC — disclosed).
- Typed transport failures this session: ENOSPC (transient, resolved externally), lumen semantic_search backend unhealthy (fell back to direct reads), 2 denied/degraded tool emissions during heavy writes (recovered by rewrite).
