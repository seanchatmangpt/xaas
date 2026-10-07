# W888 — Witness LiveView Court (receipt)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface`. Author of record: `/Users/sac/xaas/test/xaas_web/witness_live_court_test.exs` (new, the only file written besides this receipt).
- **O***: Backlog item: the witness surface had unit courts (W698/W709/W726), a pre-existing LiveView test (`test/xaas_web/live/witness_live_test.exs`, W1-era), and a Playwright e2e spec (`e2e/witness.spec.cjs`) but the backlog asked for a dedicated LiveView-level court. Read `lib/xaas_web/live/witness_live.ex`, `lib/xaas/witness/catalog.ex`, `lib/xaas/witness/certified_receipt.ex`, `lib/xaas/witness/verification_key.ex`, `test/xaas_web/live/witness_live_test.exs`, `e2e/witness.spec.cjs`, and the W766 receipt for conventions.
- **μ/diff**: +1 test file, 4 tests, Chicago-style (real sandbox Postgres via `Ecto.Adapters.SQL.Sandbox` shared with the LiveView process, real `XaasWeb.WitnessLive` mount through `live/2`, real `Xaas.Witness.Catalog.ingest/1` seeding both `CertifiedReceipt` and `VerificationKey` rows; no mocks, no stubs).
- **Commands/exits** (all under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW888`):
  - `mix test test/xaas_web/witness_live_court_test.exs` — run 1: compile blocked by two concurrent lanes' in-flight `lib/` edits (see typed gaps). Run 3 (post-repair): 2/4 passed (2 failed: (a) asserted on the Catalog's baseline subject instead of the real receipt subject `"{baseline}:{algorithm}:{index}"`; (d) compared full page HTML, which carries per-session CSRF/session tokens by design, and split on single-quoted `data-testid` instead of the rendered double-quoted form). Repaired per failure. Final runs, both 4/4, exit=0:

```
Result: 4 passed

Result: 4 passed
```

  - Determinism of the suite itself: file run twice consecutively (runs shown above), both green.
- **Coverage**:
  - (a) mount renders the real seeded receipt: `data-testid='witness-receipt-subject'` carries the real `CertifiedReceipt.subject`, the rendered page contains the first 16 hex chars of the real `payload_hash_hex`, the verified cell renders "no" (real write-once state of a fresh ingest), and a real `VerificationKey` row (seeded by the same `Catalog.ingest/1`, matched on `key_material_hex`) exists in the sandbox.
  - (b) mid-session second `Catalog.ingest/1` is reflected on re-mount — WitnessLive has no PubSub subscription and no handle_event/handle_info clauses (read happens once in `mount/3`), so a fresh mount is the real update mechanism, asserted honestly (both subjects present, newest-first per `inserted_at: :desc`).
  - (c) empty DB (`Repo.delete_all` of both resources inside the sandbox) renders the typed `witness-empty-row` ("No certified receipts ingested.") without error.
  - (d) determinism ×2: two independent mounts render a byte-identical receipts table (`render(element(view, "[data-testid='witness-receipts-table']"))`), both subjects present, exactly 2 rows. Full-page HTML is deliberately NOT compared — the layout carries per-session CSRF/session tokens that differ by design.
- **Verification ladder**: narrow (this file) only; full `mix test` NOT run (lane scope; repo operating mode allows partially-verified landing with disclosure).
- **Standing**: ALIVE (observed execution on exact subject a0723bf6, working tree +1 test file; commands/exits above).
- **Falsifier status**: run and passed — mutating the render (subject/hash/verified cell), the `inserted_at: :desc` sort, or the empty branch would fail the corresponding test.
- **Typed gaps**:
  - Concurrent-lane transport failures during the lane (not introduced by W888, disclosed as observed): (1) `lib/xaas/library/checkout.ex` (W902's in-flight edit) failed to compile for ~13 minutes (missing `require Ash.Query` on line ~91); W902 repaired it at ~06:28. (2) `lib/xaas/semantics/counterfactual.ex` had a transient SyntaxError at line 197 (~06:29, repaired by its lane within ~2 minutes). Both blocked my fresh lane build root; resolved by polling `mix compile` until green — no W888 edit to `lib/` was made or needed.
  - Full-suite regressions: UNKNOWN (full `mix test` not run this lane).
  - Pre-existing compile warnings surfaced are not introduced by this lane (`ash_affidavit` signing.ex `@envelope_domain_tag`, `Xaas.Semantics.DatasetAdmission` @doc warning, PromEx/Grafana `:nxdomain` upload noise in test env).
  - The test DB carries pre-existing witness rows (earlier lanes' seeds, visible through the shared sandbox); (c) and (d) clear within the sandbox rather than trusting an empty table.
- **Cleanup**: `_build-laneW888` deleted at integration per lane-lease law (verified gone; no `_build-*` left by this lane).
