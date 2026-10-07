# W850 — Next Read case-study README verify/correct (Lane Receipt)

- **Subject**: /Users/sac/xaas @ `feat/playwright-surface`, HEAD a0723bf6 (uncommitted lane delta; coordinator owns the commit)
- **Wave**: v26.10.6, lane W850
- **Standing**: PARTIAL_ALIVE — every claim re-read against `lib/xaas/library/` and the named receipts; corrections are documentation-only (no code delta, no build root, no commit).
- **Diff**: 2 files
  - `docs/case-studies/next-read/README.md` — 4 corrections + 1 new section
  - `docs/sjira/v26.10.6/plans/w850-nextread-readme-verify.md` — this receipt

## Per-claim table

| # | README claim | Verdict | Action / evidence |
| --- | --- | --- | --- |
| 1 | Book has `:borrow_copy`/`:return_copy`, `:is_available`, `:has_multiple_copies`, PubSub notifiers | ACCURATE | `lib/xaas/library/book.ex:85-92,153,163,268-269,35` |
| 2 | Checkout atomic inventory trigger (`DecrementBookInventory`) | ACCURATE | `lib/xaas/library/changes/decrement_book_inventory.ex`; W742 courts (b) |
| 3 | HoldRequest / RecommendationLog / Curation / School / Config / Ranker / Embeddings resources real | ACCURATE | files present and exercised by W742/W796 courts |
| 4 | Ranker: dynamic 6-factor weights, zero hardcoded constants | ACCURATE | `lib/xaas/library/ranker.ex:28,56,198` — `Config.weights/1`; W742 (c) asserts real vector (sums 1.01) |
| 5 | Embeddings = local Nx/Bumblebee, not ash_ai/req_llm | ACCURATE | W742 (c) ran real ranking without either dep |
| 6 | Real seed data via `priv/repo/seeds.exs` (quoting the Book-row IO.puts line) | STALE | seeds.exs now delegates to `Xaas.DevSeeds.run()` (`lib/xaas/dev_seeds.ex`, `get_or_create_library_books/0`). Corrected in place; kept the IO.puts line, added the DevSeeds chain. |
| 7 | Playwright e2e `e2e/next-read-ml.spec.js` | STALE | renamed `.spec.cjs` (commit b71a3129). Corrected in both places (table + ranker section), citation added. |
| 8 | `:return` guard / refusal contract — absent from README | MISSING | Added to "What is real" bullet list: DB-read open-checkout guard, `lib/xaas/library/checkout.ex:89-122`, W809 receipt; plus the disclosed per-student-limit gap (W796 finding (a)). |
| 9 | Library-surface courts | MISSING | New "Courts (v26.10.6)" section. |
| 10 | ILS/explainer per-adapter statuses (Fixture ALIVE, SIP2 PARTIAL_ALIVE, Groq PARTIAL_ALIVE with Registry.lookup defect, Template ALIVE) | NOT RE-VERIFIED | Out of lane scope (no code delta); README pointers to `ILS-AND-EXPLANATION-SUBSTITUTION.md` left as-is. |
| 11 | A2A agent / MCP tools / LiveView claims | ACCURATE (file presence) | Files present; behavioral claims not re-run this lane (no build root per contract). |

## Courts (v26.10.6) counts cited in README

- W742 — 9/9 (`Result: 9 passed`, exit 0) — `w742-nextread-deepening.md`
- W796 — 11/11 (`Result: 11 passed`, exit 0, twice) — `w796-checkout-policy-deepening.md`. Dispatch brief said "11/12"; the receipt on disk says 11/11 (the 12th court is W809's addition). Receipt wins.
- W809 — 12/12 (`Result: 12 passed`, exit 0) — `w809-return-guard.md`
- W838 — no receipt filed yet; 8 tests landed in `test/xaas/library/pubsub_publish_court_test.exs` on the shared tree. README marks it in-flight/pending rather than inventing a count.

## Transport failures

None. Documentation-only lane; no compile, no test run, no build root (per dispatch contract).

## Verification

Re-read of the corrected README against: `lib/xaas/library/{book,checkout,ranker}.ex`, `lib/xaas/dev_seeds.ex`, `priv/repo/seeds.exs`, `e2e/` listing, and the three named receipts. All corrections cite file:line or a receipt path.
