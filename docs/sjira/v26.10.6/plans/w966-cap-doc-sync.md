# W966 — Library/Conference doc sync to landed guards (receipt)

- **Lane**: W966, v26.10.6 campaign; repo `/Users/sac/xaas` @ `feat/playwright-surface`
  (canonical checkout, no worktree). **No commit** (per lane contract); no build root.
- **Standing**: ALIVE (doc-only lane; every claim verified against the tree before writing).
- **μ/diff**: doc-only, handwritten. 3 doc files + this receipt. No code touched.

## Facts verified in code before writing (grep/sed against the tree)

- **Borrow cap (W796-G1, repaired by W902)** — `lib/xaas/library/checkout.ex`:
  `@max_open_checkouts_per_student 3` (line 12); `create :borrow` carries a
  `before_action` guard (lines 90-112) reading the student's open
  (`:borrowed`/`:overdue`) count fresh from the DB (`Ash.count!` over `__MODULE__`,
  filter `user_id == ^user_id and status in [:borrowed, :overdue]`) and refusing typed
  (`Ash.Error.Changes.InvalidArgument` on `:user_id`, "per-student borrow cap
  exceeded") before `DecrementBookInventory` (line 115). Receipt:
  `docs/sjira/v26.10.6/plans/w902-batch3-repairs.md` (mutation: cap → 999,999 kills
  exactly the cap courts; restored byte-identical).
- **Slot release (W893 gap, repaired by W925)** —
  `lib/xaas/conference/registration.ex`: `EnforceSessionCapacity` wired on `:create`
  (line 60); module at lines 170-215 counts only ACTIVE statuses
  `@active_statuses [:registered, :attended]` (exposed as `active_statuses/0`), so a
  `:cancelled` registration frees its slot; refusal typed
  (`InvalidChanges`, "at capacity (N/M taken)"). Receipt:
  `docs/sjira/v26.10.6/plans/w925-slot-release.md` (mutation: drop the status filter →
  re-register-after-cancel create raises ~r/at capacity \(1\/1 taken\)).

## Per-doc changes

1. **`docs/case-studies/next-read/README.md`** (allowed scope:
   `docs/case-studies/next-read/` is the library case-study doc named in the order;
   note: order text said diataxis + cro for other lanes — this file is the (a) target).
   - "What is real" list, circulation bullet: replaced the stale "Disclosed remaining
     gap: there is still no per-student concurrent-checkout limit…" disclosure with a
     factual cap bullet (3 open, aggregate across books, overdue counts as open,
     DB-fresh count, typed refusal before inventory decrement, return frees capacity),
     citing `checkout.ex:12,90-112` + w809/w796/w902 receipts.
   - Courts table: added a w902 borrow-cap-courts row (13-suite run 101/102 with the
     disclosed pre-existing `next_read_test.exs:144` flake; per-file count not
     asserted — w902's receipt reports the combined run, not per-file).
2. **`docs/claude/diataxis/reference/ash-configuration.md`**:
   - `Xaas.Library` resource list, item 2 `Checkout`: added the borrow-cap sentence
     (3 open, aggregate, DB-fresh `before_action`, typed refusal on `:user_id`;
     `checkout.ex:12,90-112`; w902 receipt).
   - `Xaas.Conference` bullet: added the slot-release sentence (ACTIVE-only count
     `:registered`/`:attended`, cancel frees the slot, `capacity == nil` = unlimited,
     `registration.ex:60,170-215`; w925 receipt, closes W893's
     `GAP(CancelDoesNotReleaseSlot)`).
3. **`docs/claude/diataxis/explanation/architecture-overview.md`**: domain table —
   Library row gains the 3-open-checkout cap clause (w902); Conference row gains the
   ACTIVE-only capacity / cancel-frees-slot clause (w925).

## Explicitly not changed

- `docs/cro/CYCLE-LOG.md:191` already states the slot-release behavior (landed by
  W952's fold) — no edit needed, no duplicate entry written.
- `docs/claude/diataxis/reference/http-api-surface.md` — describes route
  declarations, not guard behavior; no capacity/cap claim present to correct.
- Conference capacity courts' receipts (w795/w893/w925) — read-only inputs.

## Verification

- Every file:line citation re-checked with grep/sed against the working tree this lane
  (checkout.ex lines 12/90-112/115; registration.ex lines 60/170-215).
- No build, no tests run, no commit — doc-only diff; the underlying guards' courts were
  run green by their owning lanes (w902: 101/102 with disclosed pre-existing flake;
  w925: 15 passed × 2 runs).

## Replay

```
cd /Users/sac/xaas && git diff -- docs/case-studies/next-read/README.md \
  docs/claude/diataxis/reference/ash-configuration.md \
  docs/claude/diataxis/explanation/architecture-overview.md
```
