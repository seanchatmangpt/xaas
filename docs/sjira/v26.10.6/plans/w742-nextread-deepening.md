# W742 — Next Read library-domain atomic-concurrency deepening

Lane: W742, xaas v26.10.6 campaign.
Subject: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD at lane start `a0723bf6` (uncommitted working tree, campaign-shared; my delta = exactly 2 files listed below).
Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW742 mix test test/xaas/library/nextread_deepening_test.exs --seed 0`
Exit: **0**

```
Finished in 3.0 seconds (0.00s async, 3.0s sync)
Result: 9 passed
EXIT=0
```

## Files written

- `test/xaas/library/nextread_deepening_test.exs` (new, ~340 lines) — the only source delta.
- `docs/sjira/v26.10.6/plans/w742-nextread-deepening.md` — this receipt.

## Courts added (9 tests, all Chicago-style: real Ash actions on real Postgres sandbox, zero mocks)

**(a) Borrow/return atomicity under real concurrency**
- 10 parallel `Task.async_stream` `Checkout :borrow` creates vs a 5-copy book →
  exactly 5 `{ :ok, _ }`, exactly 5 `{:error, _}`, `available_copies` re-read at
  exactly 0, exactly 5 real `Checkout` rows all `:borrowed` with 5 distinct users.
- Exhaust-then-return court: 1-copy book, borrow→exhaust→0-copy borrow fails→
  `:return` restores inventory to exactly 1 and sets `status=:returned`,
  `returned_at` non-nil; freed copy re-borrowable.

**(b) DecrementBookInventory exactly-once**
- 3 sequential successful borrows on a 3-copy book: inventory re-read 3→2→1→0
  stepwise after each create; `total_copies` untouched.
- Failed borrow at 0 copies: `{:error, _}`, inventory stays 0, zero checkout rows.

**(c) RecommendationLog 6-factor capture**
- `Ranker.weights()` returns the real 6-key vector
  (collab 0.34 / semantic 0.26 / grade_fit 0.16 / available 0.10 / diversity 0.06 /
  curation 0.09), sums to 1.01 (real ontology values, ±0.02 envelope asserted).
- Real `Ranker.rank_recommendations/3` run over a 3-book catalog (one curated,
  one out-of-stock): every entry carries the 6 factors; every score equals
  Σ wᵢ·factorᵢ (±1e-4); curated book has curation=1.0/available=1.0; out-of-stock
  has available=0.0; exactly ONE `RecommendationLog` row persisted; stored
  `weights` (string-keyed after jsonb round-trip) equal the weights actually used;
  stored `ranked_items` (book_id/title/score) equal the produced ranking exactly;
  `candidate_pool_size == 3`, `accepted == false`.

**(d) Curation.active_for_grade real scoping**
- Asserted the real action shape: filter is `active == true` only (grade-band
  matching happens in `Ranker.matches_grade_band?/2`, not the query).
- Active rows returned; no inactive row ever returned; flipping `active: false`
  removes it from results; `grade_level` argument is required.

## Verification ladder

narrow (this file, 9/9, exit 0). Not run: full `mix test` (coordinator's
integration ladder; ~9 sibling lanes active on this checkout during the run —
one sibling's mid-write edit to `lib/xaas/ocel.ex` transiently broke
compilation, resolved by waiting + recompile; a second transient compile
surfaces sibling-lane warnings only, none from my file).

## Typed gaps / notes

- `Xaas.Generator.create_book!/1` with `grade_level` override: `book.ex` declares
  `grade_level` as `:decimal`, generator uses `StreamData.integer(3..8)`, so
  `create_book!(%{grade_level: 5})` and the decimal column round-trip a Decimal —
  fine in-heap, noted for anyone asserting raw-integer equality on it.
- `RecommendationLog.weights` is `:map` → Postgres jsonb → string-keyed on read;
  the comparison in court (c) normalizes keys. If a future change makes weights
  an atom-keyed field type, that normalize step is dead but harmless.
- Real ontology weights sum to 1.01, not 1.00 — asserted against a ±0.02
  envelope, not exact 1.0. If weights ever normalize to exactly 1.0 the court
  still passes.
- Concurrency court uses `authorize?: false` (matching the existing
  checkout_concurrency_test.exs pattern) — policy-floor coverage is owned by
  curation_test.exs / next_read_test.exs, not this file.
- Lane build root `_build-laneW742` — cleanup attempt was denied by the
  permission system; left on disk for the coordinator's per fanout cleanup law
  (coordinator deletes lane build roots at integration).
