# W984gh — unclaimed-family probe: lib/xaas_web/live/ court coverage

Lane: W984gh · Date: 2026-10-07 · Branch: feat/playwright-surface · NO commit (shared checkout)

## Census (grep of module base names against test/)

| Module | File | Disposition |
|---|---|---|
| XaasWeb.WdFa.CaseStudyLive | lib/xaas_web/live/wd_fa/case_study_live.ex | **UNCOVERED — courted this lane** (0 test hits; only reference is router line 66) |
| XaasWeb.Chicago.DrillDownLive | lib/xaas_web/live/chicago/drill_down_live.ex | covered — test/xaas_web/live/chicago/drill_down_live_test.exs |
| XaasWeb.Chicago.SellerLive | lib/xaas_web/live/chicago/seller_live.ex | covered — test/xaas/chicago/seller/seller_live_test.exs |
| XaasWeb.MarketplaceCatalogLive | lib/xaas_web/live/marketplace_catalog_live.ex | covered — test/xaas_web/live/marketplace_catalog_live_test.exs |
| XaasWeb.MarketplacePplanExplorerLive | lib/xaas_web/live/marketplace_pplan_explorer_live.ex | covered — test/xaas_web/live/marketplace_pplan_explorer_live_test.exs |
| XaasWeb.WitnessLive | lib/xaas_web/live/witness_live.ex | covered — witness_live_court_test.exs + live/witness_live_test.exs |
| XaasWeb.System.CommandCenterLive / CommandCenterAdapter | lib/xaas_web/live/system/ | covered — test/xaas/chicago/surface/command_center_live_test.exs + dev_routes_court_test.exs |
| XaasWeb.AutofdeLab.StatusLive | lib/xaas_web/live/autofde_lab/status_live.ex | covered — test/xaas_web/live/autofde_lab/status_live_test.exs |
| XaasWeb.NextRead.ReaderLive | lib/xaas_web/live/next_read/reader_live.ex | covered — next_read_live_deepening_test.exs + test/xaas/library/next_read_live_test.exs |

## Court

`test/xaas_web/live/family_court_w984gh_test.exs` — 6 tests, all passing, zero mocks
(real mounts over sandboxed Postgres ConnCase, real handle_event round-trips, real
`LearningLoop.verify_novel_fixture/0`).

State-bearing branches exercised:

1. mount defaults (known_firmware KNOWN/ALIVE reference state)
2. mount domain assigns (morning_brief / evaluation / architecture / dfcm_metrics all
   dereferenced by render/1 — dropping any crashes mount)
3. select_scenario → partial_firmware (PARTIAL branch + missing-evidence render)
4. select_scenario → novel_x unadmitted (UNKNOWN branch + admit button conditional)
5. admit_experience (real VerificationReceipt/MachineExperience/ArchitectureChange
   assign chain + receipt render block)
6. learned? guard (admit → re-select novel_x stays KNOWN — the only true-branch path
   of `id == "novel_x" and experience_admitted`)

Mutation rationale per test inline in the file. Remaining uncovered surface in
case_study_live.ex is presentational only (render-only lists: requirements, viewpoints,
building blocks, ingestion modalities, offline controls) — typed COVERED-ADJACENT, no
filler tests added.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gh mix test
  test/xaas_web/live/family_court_w984gh_test.exs` → `6 passed`, exit 0
- mock gate `scan_mock_usage(["test","lib"])` → `[]`

## Cleanup

`rm -rf _build-laneW984gh` pending at receipt-write time (see lane report).
