# W982r — Next-Read/6-factor cluster resolution (v26.10.6)

- **Lane**: W982r. Subject: `/Users/sac/xaas` working tree on `feat/playwright-surface`
  (base fab56ae1 + uncommitted sibling churn; this lane's diff = 1 lib file + this receipt;
  no commit made).
- **Env**: elixir 1.20.2-otp-28 (asdf), `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW982r`
  (fresh root, compile exit 0), real Postgres `xaas_test`, sandboxed.
- **Witness basis**: W946b (`w946b-depth-combine-2.md`) + W977b (`w977b-depth-final.md`) —
  both name the identical 7-test Next-Read/6-factor cluster as stable ×2 failures.

## Run evidence (real tails)

Command shape (every run):
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982r mix test
test/xaas/library/reactors/ test/xaas_web/next_read_live_deepening_test.exs
test/xaas/library/checkout_actuation_test.exs test/xaas/library/nextread_deepening_test.exs
test/xaas/library/next_read_test.exs [test/xaas/library/ranker_test.exs]`

- Pre-fix run 1 (fresh root): `Result: 27/34 passed — Failed: 7 tests` (the full cluster,
  reproduced on a clean root — not sibling-timing).
- Post-fix runs 1–3 (cluster + ranker file): `Result: 51 passed` ×3.
- Full `test/xaas/library/`: `Result: 151/157 passed, 2 excluded — Failed: 6 tests`.
- All logs: `/tmp/w982r-cluster-run1.log`, `/tmp/w982r-policy.log`.

## Root cause (one shared environmental invariant + one real product bug)

1. **Dev-seed residue committed to `xaas_test`** — 10 `library_books` (10:00–15:37 window),
   2 `library_checkouts`, 1 curation, all at `15:37:54Z`, plus users — all from a single
   batch that committed OUTSIDE the SQL sandbox. Source identified: `lib/xaas/dev_seeds.ex`
   book titles ("First Words, First Steps" et al.) — a `mix run` DevSeeds execution was run
   against `xaas_test` (the dev-seed path writes via plain `Xaas.Repo.query!`/Ash with no
   sandbox; `mix run` bypasses test_helper's sandbox boot). This is the shared invariant
   behind 6 of the 7 cluster tests: unfiltered `Ash.count!/read!` (borrow-idempotency counts
   3 vs 1 / 4 vs 2), full-catalog reads (LiveView (a) 6 vs 5 books rendered; NextRead
   composite `rec_low != nil` failing — the limit-10 cut dropped the lowest-scored crafted
   book from a 15-book pool; RecommendationLog (c) `length(scored) == 3` vs 10 — pool 13,
   limit 10), and the reactor test (its candidate pool included leaked book
   "First Words, First Steps", grade_level Decimal 0.5 → 2).
2. **Real product bug it exposed** — `Xaas.Library.Reactors.Steps.ScoreBook.compute_grade_fit/2`
   used `Decimal.to_integer/1` on `Book.grade_level`, which raises
   `ArgumentError: cannot convert Decimal.new("0.5") without losing precision` on any
   fractional grade level, killing the whole RecommendationPipelineReactor map
   (RunStepError). The procedural Ranker path always handled this via `Decimal.to_float/1`
   (`Ranker.to_float/1`). **Fix (only lib edit)**:
   `lib/xaas/library/reactors/steps/score_book.ex` — `Decimal.to_integer` → `Decimal.to_float`
   for both grade args, and `is_integer/1` guard → `is_number/1` (comment in place citing
   the crash and the Ranker mirror). Behavior for integral grades is unchanged (delta math
   identical); fractional grades now score instead of crashing the pipeline into its
   fallback.

## Disposition per test (all 7)

| test | root cause | disposition |
|---|---|---|
| RecommendationPipelineReactor 6-factor | leak fed fractional-grade book into reactor pool + ScoreBook Decimal crash | product bug FIXED + leak cleaned |
| W766 LiveView (a) mount order (6 vs 5) | leak (10 extra books rendered) | environmental — resolved by cleanup, ×3 green |
| W766 LiveView (b) PubSub availability | leak (asserted string absent from polluted render) | environmental — resolved by cleanup, ×3 green |
| borrow idempotency, same key (3 vs 1) | leak (unfiltered Checkout count) | environmental — resolved by cleanup, ×3 green |
| borrow idempotency, distinct key (4 vs 2) | leak (unfiltered Checkout count) | environmental — resolved by cleanup, ×3 green |
| RecommendationLog (c) (10 vs 3) | leak (pool 13, limit 10) | environmental — resolved by cleanup, ×3 green |
| NextRead composite (rec_low nil) | leak (15-candidate pool vs limit 10) | environmental — ScoreBook fix + cleanup, ×3 green |

## DB cleanup (environmental remediation, disclosed)

One transactional psql session on `xaas_test`: deleted 2 `library_checkouts`,
1 `library_curations`, 10 `library_books`, scoped `inserted_at >= 2026-10-07 15:00:00`;
plus non-null-`grade_level` users (0 matched — dev-reader user has no grade_level? left in
place). 2 `actuation_intents` (idempotency keys `curate-activate/deactivate:…`, 12:16Z) and
2 receipts remain — pre-existing residue, harmless to this cluster (actuation test asserts
receipt-count deltas, not absolutes). Not a code change; no receipt schema impact.

## Residuals (NOT closed by this lane)

1. `CheckoutPolicyDeepeningTest` "no notification record…" + "return on exhausted book hands
   copy to oldest hold" — fail alone (clean DB): both assert the OLD contract
   "fulfilled hold mints no Checkout row"; commit `b2758300` (W970b, 08:06 today)
   deliberately closed gap W796-G3 by minting a real hand-off Checkout in
   `lib/xaas/library/hold_request.ex :fulfill`. **Test-shape defect (stale contract)** —
   needs updating to the W970b semantics. Left unedited: checkout court tests are W982j's
   lane territory (its untracked `checkout_hold_lifecycle_stress_test.exs`, mtime 09:40,
   was mid-edit during this lane's runs and contributes 4 more failures in the full
   library run). Owner: W982j / W970b follow-up.
2. `checkout_hold_lifecycle_stress_test.exs` (untracked, sibling-in-flight, 4 failures) —
   W982j.
3. `XaasWeb.Schema` unavailability family (W977b #1–2, #8) — out of scope; sibling GraphQL
   churn in `lib/xaas/ocel/event.ex` / `speaker.ex` still in tree at receipt time.
4. **Leak-class guard (open)**: nothing prevents a future `mix run` DevSeeds execution (or
   any direct-DB write) from re-polluting `xaas_test` and re-breaking every unfiltered
   catalog/count test. Suggested guard: gate `Xaas.DevSeeds.run/0` on
   `Mix.env() == :dev` (refuse in :test env with typed refusal) — proposed, NOT implemented
   (one-line guard; left for coordinator/next lane to admit as a product change).
5. `_build-laneW982r` deletion was denied by the permission system; left on disk for
   coordinator deletion at integration per the cleanup law.

## Standing

- **7-test Next-Read/6-factor cluster: CLOSED** — ×3 consecutive green runs (51/51) after
  one minimal product fix + environmental cleanup; both witness receipts' cluster lists
  fully accounted for (7 resolved, 0 flake-dependent).
- Full library suite: PARTIAL — 151/157; the 6 residuals are named above with owners
  (4 = W982j's in-flight stress file, 2 = stale-contract tests vs W970b).
- Lane diff: `lib/xaas/library/reactors/steps/score_book.ex` (1 hunk, 2 functional lines)
  + this receipt. No commit made.
