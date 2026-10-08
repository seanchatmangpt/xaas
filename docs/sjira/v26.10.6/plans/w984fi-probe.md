# W984fi — unclaimed-family probe: `lib/xaas/marketplace/` (receipt)

- Lane: W984fi, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface` (uncommitted lane artifact; no commit per dispatch)
- Date: 2026-10-07
- Sibling in-flight: `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` (untracked, W984dg's lane — disjoint; all Catalog-surface courts left to that lane, this lane did not touch Catalog in the court file)
- Subject files (9 modules, 868 LOC):

| module | LOC | disposition | evidence |
|---|---|---|---|
| `marketplace/provider.ex` | 123 | covered | provider_test.exs, provider_preapprove_lifecycle_test.exs, marketplace_deepening_test.exs, controller/live/json-api courts |
| `marketplace/pack.ex` | 128 | covered | pack_test.exs, pack_catalog_depth_test.exs, controller/live courts |
| `marketplace/catalog.ex` | 161 | covered | catalog_test.exs, pack_catalog_depth_test.exs; Catalog-surface deepening owned by in-flight sibling W984dg |
| `marketplace/approval_provider_status_change.ex` | 158 | covered | marketplace_deepening_test.exs (refusal grid), controller courts, stress test (50-way race), pack_test.exs (real approve→actuation) |
| `checks/actor_org_filter.ex` | 34 | covered | deepening cross-org read/update/filter courts; provider_test.exs |
| `checks/actor_org_matches.ex` | 90 | covered except catch-all | all shape-conforming paths covered; the `match?(_actor,_context,_opts), do: false` non-conforming-actor fallthrough was UNCOVERED — now courted here |
| `changes/apply_provider_status_change.ex` | 64 | covered | pack_test.exs (receipt/authority/replay/idempotency courts incl. `authority/1` + key format); stress test; BUT the `:suspended` requested_status through a real successful approve was UNCOVERED — courted here |
| `validations/...provider_org_matches.ex` | 77 | covered | its own dedicated court file |
| `validations/...requires_approver.ex` | 33 | covered | deepening tests ("refuses missing approved_by", "refuses self-approval"), controller courts |

## New court: `test/xaas/marketplace/family_court_w984fi_test.exs` — 4 tests, 4 passed

1. **`:suspended` approve→suspend, then re-activate (round-trip)** — every existing success-path court hardcodes `:active`; `:suspended` appeared only in refusal-path courts. Mutation rationale: kills a mutant hardcoding/dropping `requested_status` wiring in `ApplyProviderStatusChange`'s `Actuation.run/4` call. Asserts real row state after each approve (`pending → suspended → active`).
2. **`requested_status` one_of constraint** — `:deleted` atom refused (`Ash.Error.Invalid`), provider untouched. Mutation rationale: kills deletion of `constraints(one_of: [:active, :suspended])`.
3. **`ActorOrgMatches` catch-all fallthrough** — non-conforming actor (binary actor / `%{unrelated: :shape}`) denied `:create` on **Provider**; no row persists. Mutation rationale: kills deletion of `def match?(_actor,_context,_opts), do: false`.
4. **Same catch-all on ApprovalProviderStatusChange** (moduledoc claims verbatim reuse across both Marketplace resources) — denied, no row persists. Mutation rationale: kills a mutant swapping either resource's `:create` bypass off the shared check.

## Gates (all run under pinned toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW984fi)

- `mix test test/xaas/marketplace/family_court_w984fi_test.exs`: **4 passed, exit 0** (real sandboxed Postgres/ETS, zero mocks; warnings clean)
- Mock gate `scan_mock_usage(["test","lib"])`: **`[]`**
- Transport note: one transient compile race against another lane's in-flight untracked `lib/xaas/a2a/tofu.ex` (not this lane's file; resolved on retry after that lane's write settled)

## Standing

- ALIVE: the three gap branches are now exercised on the exact subject with real state assertions.
- Not committed (per dispatch). Cleanup: `rm -rf _build-laneW984fi` — see below.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW984fi` — **DENIED** by the permission system in this lane's session (2026-10-07). Lease remains on disk; coordinator should delete at integration per the fanout cleanup law.
