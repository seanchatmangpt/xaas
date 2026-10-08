# W984hu — unclaimed-family probe: remainder of `lib/xaas/marketplace/` (receipt)

- Lane: W984hu, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface` (no commit per dispatch)
- Date: 2026-10-07
- Prior lanes gone past: **W984fi** (`docs/sjira/v26.10.6/plans/w984fi-probe.md` — approval flow, ActorOrgMatches catch-all, ApplyProviderStatusChange `:suspended` round-trip, its court `test/xaas/marketplace/family_court_w984fi_test.exs`) and **W984dg** (in-flight `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` — Catalog upsert-UPDATE branch, tier fallback chain, binary readiness, description search, `:invalid_json` / `get_pack!` raise). Both confirmed on disk before this lane started; all Catalog-surface and W984fi-courted branches were excluded from this lane's court file.
- Disjointness: `git status` shows the marketplace tree clean except W984dg's untracked test file (untouched by this lane). This lane created exactly one file: `test/xaas/marketplace/remainder_court_w984hu_test.exs`.

## Per-module dispositions (9 modules, 868 LOC, CamelCase-grepped against `test/`)

| module | LOC | disposition | evidence |
|---|---|---|---|
| `provider.ex` | 123 | covered | provider_test.exs (pending default, slug identity, Reactor boundary, org read grid), marketplace_deepening_test.exs (update/status smuggle, cross-org grid), provider_preapprove_lifecycle_test.exs, controller/live/json-api courts |
| `pack.ex` | 128 | covered (2 gap branches closed by this lane) | pack_test.exs, pack_catalog_depth_test.exs, marketplace_pack_json_api_test.exs; GAPS: direct `:update` (name immutability + full-field round-trip) and `get_by_id` on absent name — courted here |
| `catalog.ex` | 161 | covered | catalog_test.exs, pack_catalog_depth_test.exs + W984dg's depth court (excluded per lane partition) |
| `approval_provider_status_change.ex` | 158 | covered (1 gap branch closed by this lane) | deepening refusal grid (missing/empty/self/foreign approver, dangling + cross-org provider), controller courts, W984fi stress + `:suspended` round-trip; GAP: cross-org READ of approval rows — courted here |
| `checks/actor_org_matches.ex` | 90 | covered | deepening grid + W984fi catch-all court |
| `checks/actor_org_filter.ex` | 34 | covered | deepening read/update/filter courts; exercised on Approval rows by this lane's test 3 |
| `changes/apply_provider_status_change.ex` | 64 | covered | pack_test.exs actuation courts, stress test, W984fi `:suspended` round-trip |
| `validations/...provider_org_matches.ex` | 77 | covered | its own dedicated court file (same-org / zero-rows / different-org / approve-unaffected) + deepening |
| `validations/...requires_approver.ex` | 33 | covered | deepening "refuses missing approved_by" (nil AND `""` branches, line 319), "refuses self-approval" |

## New court: `test/xaas/marketplace/remainder_court_w984hu_test.exs` — 3 tests, 3 passed

1. **Pack `:update` name-immutability + full-field round-trip** — supplying `:name` to `:update` is refused at the real boundary (`Ash.Error.Invalid`/NoSuchInput), then every other accepted v2 field round-trips in place with the persisted name unchanged and no `hijacked-name` row. Mutation rationale: kills an accept-list mutant adding `:name` (silent rename of a primary-key/slug).
2. **Pack `get_by_id` on an absent name filters to empty** (present-name sanity in the same test). Mutation rationale: kills removal of `filter(expr(name == ^arg(:id)))` — W984dg courted `Catalog.get_pack!/1` raising (different path); the HTTP court only hits an existing id, so the absent branch was unexercised.
3. **Org A's actor cannot read org B's approval request rows** — filtered to `{:ok, []}` (not errored), row still readable by its own org. Mutation rationale: kills removal of the `:read` bypass's `ActorOrgFilter` on `ApprovalProviderStatusChange`; only Provider's cross-org read was previously courted.

First-run disclosure: test 1 initially failed because the non-accepted-attribute refusal raises (NoSuchInput) rather than silently ignoring `:name` — the test was corrected to assert the raise; the production behavior was already correct. No production files touched.

## Gates (pinned toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984hu)

- `mix test test/xaas/marketplace/remainder_court_w984hu_test.exs`: **3 passed, exit 0**
- Mock gate `scan_mock_usage(["test","lib"])`: **`[]`**, exit 0
- Transport note: two transient compile breaks from a sibling lane's in-flight `lib/xaas/eds/falsifier.ex` (syntax error mid-write) — resolved on retry after that lane's write settled; not this lane's file, not modified by this lane.

## Standing

- ALIVE: the three remainder gap branches are exercised on the exact subject with real state assertions (real sandboxed Postgres for Provider/Approval, real ETS for Pack, zero mocks).
- Not committed (per dispatch).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW984hu` post-gates — **SUCCEEDED** (exit 0; directory confirmed absent). No lease left on disk.
