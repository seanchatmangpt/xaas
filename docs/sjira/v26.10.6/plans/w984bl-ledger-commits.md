# Lane W984bl — ledger/ocel/library integration commits — receipt

- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, base `0f25f5cd`.
- **Gate (pre-commit, observed)**: fresh `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bl`
  compile → **EXIT=0**; `mix test test/xaas/ledger/ test/xaas/ocel/ test/xaas/library/`
  → **210 passed, 5 excluded, EXIT=0** (×1, real Postgres sandbox).
- **Standing: ALIVE** for the landed subjects; excluded items below remain owner-owned.

## Commits (2, not 3 — see collision disclosure)

| SHA | content | owner receipts |
|---|---|---|
| `f1936194` | test(ledger): `reversal_deepening_test.exs` (real read_one lookup + assert de-flake). 1 file — the `reverse_transfer.ex` sufficiency fix was already landed by W984ao (below). | w983j-reverse-sufficiency-fix.md |
| `67ecacf4` | test(ocel): `w983e_ocel_log_courts_test.exs` (410 lines, 6 courts) + `w984h-ocel-findings.md` receipt. | w984h-ocel-findings.md |

## Collision disclosure (concurrent lanes swept my lib files)

While this lane's gate ran, concurrent integration commits landed the lib halves of
this workstream with their own disclosures:

- **`12d5f6d3` (W984ao, 11:32)** — graphql-removal sweep committed
  `lib/xaas/ledger/changes/reverse_transfer.ex` (full W983j `run_sufficiency` fix),
  `lib/xaas/ocel/case_view.ex` + `event.ex` (full W984h determinism + `:destroy`
  drop), and **`lib/xaas/library/changes/enforce_borrow_cap.ex`** (W984ad's new file,
  committed BEFORE W984ad's receipt exists — W984ao disclosed this class in its
  commit message).
- **`32487e08` / `d7beb066` (w984u integration, 11:22)** — landed W982r's
  `score_book.ex` Decimal fix and W984b's `checkout_policy_deepening_test.exs`
  contract flips, plus receipts w982r-nextread-cluster.md / w984b-checkout-leak.md.
  My planned third commit (library) therefore had no unlanded files and was not made.

All gated content is in HEAD; nothing landed twice.

## Exclusions (owner-owned, NOT landed by this lane)

- `lib/xaas/library/hold_request.ex` (M) — W984ad fulfill-cap change; receipt
  `w984ad-fulfill-cap.md` still absent at 11:50. Excluded per task.
- `test/xaas/library/checkout_hold_lifecycle_stress_test.exs` (untracked) — W982j's
  stress test but current content carries W984ad edits (asserts EnforceBorrowCap on
  the `:fulfill` path); committing it now would break the committed tree while
  `hold_request.ex` stays uncommitted. Left for W984ad integration (with
  `w982j-checkout-deepening.md`).
- graphql-removal files (billing/*, domain extension lists, `checkout.ex`, etc.) —
  W984ao/W984bk territory; skipped throughout.

## Cleanup

`_build-laneW984bl` lane build root deletion attempted by this lane as part of
integration; if the `rm` was permission-blocked, deletion passes to the coordinator
per the lane-lease law.

## Falsifier

- Any of the two SHAs missing from `feat/playwright-surface` history, or
  `git show --stat` on them not matching the tables above.
- Re-running `mix test test/xaas/ledger/ test/xaas/ocel/` at `67ecacf4` on a fresh
  build root failing any of the landed courts.
