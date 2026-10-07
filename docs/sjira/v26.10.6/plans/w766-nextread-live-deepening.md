# W766 — Next Read LiveView Deepening (receipt)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface`. Author of record: `/Users/sac/xaas/test/xaas_web/next_read_live_deepening_test.exs` (new, only file written besides this receipt).
- **O***: Backlog item: the public `/next-read` LiveView surface was undocketed at the LiveView level. Read `lib/xaas_web/live/next_read/reader_live.ex`, `lib/xaas/library/ranker.ex`, `lib/xaas/library/config.ex`, `lib/xaas/library/book.ex`, and pre-existing `test/xaas/library/next_read_live_test.exs`.
- **μ/diff**: +1 test file, 4 tests, Chicago-style (real sandbox Postgres, real Ash resources, real `XaasWeb.Endpoint.broadcast/3`, real LiveView mount via `live/2`; no mocks, no stubs).
- **Commands/exits** (all under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW766`):
  - `mix test test/xaas_web/next_read_live_deepening_test.exs` — run 1: 1/4 passed (3 failed: hardcoded oracle grade 8 vs the LiveView's real `Config.default_grade()`; `Ash.Changeset.for_update/3` given module not record; over-broad page-level refute). Repaired per failure; run 4 (final, /tmp/w766_run4.log):

```
Finished in 2.3 seconds (0.00s async, 2.3s sync)

Result: 4 passed
```

  exit=0.
- **Coverage**:
  - (a) mount renders the real 6-factor ranker order: rendered `data-book-id` sequence == `Ranker.rank_recommendations/2` real output for the same (user, grade) — the ranker is the oracle, not a hand-computed expected list; plus a non-degeneracy assert (>1 unique score across 5 differentiated fixtures: available/unavailable, grade-fit delta, distinct genres).
  - (b) real PubSub inventory event: `Ash.update!` available_copies 2→0, then real `XaasWeb.Endpoint.broadcast("library:books:events", ...)` (a topic the LiveView actually subscribes to in `mount/2`) → `handle_info(%Phoenix.Socket.Broadcast{})` → re-render; asserts the target card now renders "all copies checked out" and no longer its on-shelf count (scoped to the card, since other fixtures legitimately keep their counts).
  - (c) unauthenticated public access: `live(conn, ~p"/next-read")` with no session → real guest fallback user path renders student + librarian windows.
  - (d) determinism ×2: two independent mounts produce identical card-id sequences, both equal to the ranker oracle.
- **Verification ladder**: narrow (this file) only; full `mix test` NOT run (lane scope, repo operating mode allows partially-verified landing with disclosure).
- **Standing**: ALIVE (observed execution on exact subject a0723bf6, working tree +1 test file; commands/exits above).
- **Falsifier status**: run and passed — mutating the ranker order, the broadcast path, or the public route would fail the corresponding test.
- **Typed gaps**:
  - `R_missing_replay`: none — commands reproducible as written above (fresh lane build root; full first build ~15 min, incremental ~10 s).
  - Full-suite regressions: UNKNOWN (full `mix test` not run this lane).
  - Compile warnings surfaced are pre-existing (`ash_affidavit` signing.ex, `Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate`) — not introduced by this lane.
  - `missing_form_id` LiveView test warning on `/next-read` (pre-existing template issue: grade form lacks an id) — file under a future lane, not fixed here.
- **Cleanup**: `_build-laneW766` deleted at integration per lane-lease law.
