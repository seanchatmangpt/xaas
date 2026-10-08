# W984nd — landing batch #15 (the W984mo remainder)

Lane: W984nd · Branch: `feat/playwright-surface` · Subject: canonical checkout `/Users/sac/xaas`
Base: `20a24db0` (W984mo batch #14 receipt) · Date: 2026-10-08

## Commits (5, explicit pathspec only, no stash, no branch switch)

1. `4d96b097` fix(ci) — `.github/workflows/ci_cd.yaml` (regen-drift CI leg) +
   `lib/xaas/generated/regen_check.ex` (`--engine oxigraph` pin). Diff verified
   as exactly the pin + CI step; receipts `w984md-gate-fix.md`, `w984le-probe.md`
   (both already landed as docs in batch #14).
2. `2e77ce47` test(courts) — `pack_gate_engine_court_w984md_test.exs` (3) +
   `pack_queries_court_w984le_test.exs` (8).
3. `7904b088` fix(lib) — comment-sweep residue `book.ex`, `audit_log_entry.ex`
   (W984ex, comment-only diffs verified); `refusal_ledger_export.ex` (W984eu
   compile-freeze vacuous-guard drop); `oversight_governance.ex` + test
   (W984eb OPEN_GAP→EVIDENCED). Owner receipts: `w984ex-probe.md`,
   `w984eu-probe.md` (1388 passed exit 0), `w984eb-probe.md` (1355 passed exit 0).
4. `df22abb6` test — W984lm bare-atom pin repairs (exactly 4 pins across
   `execution_fabric_controller_test.exs` / `execution_fabric_deepening_test.exs`;
   receipt `w984lm-repair.md`).
5. `17ef4b54` test(courts) — 14 court files from finished lanes
   (la 4 / dz 13 / jr 5 / dv 10 across 2 files / ei 9 / ih 4 / if 4 / dr3 /
   ds2 ×2 / w650y3 5 / w650h21 5 / mm 16) + probe receipts `w984mm-probe.md`,
   `w984nb-probe.md` + docs (diataxis README orphans per w984nb, `e2e/README.md`
   per W984kz).

## Gates (real output, lane build root `_build-laneW984nd`)

- Mock gate `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'`
  → `[]`, exit 0 (cold compile in lane root).
- Batch gate A (md/le/lm/eb/eu files: 2 generation courts + 2 fabric tests +
  oversight test + refusal depth test) → **101 passed**, exit 0.
- Batch gate B (la/dz/jr/dv×2/ei/ih courts) → **45 passed**, exit 0.
- Batch gate C (dr3/ds2×2/w650y3/w650h21/mm courts) → **46 passed**, exit 0.
- Batch gate D (w984if prometheus court) → **4 passed**, exit 0.
- lib compile exercised via all runs, exit 0. 196 tests total, 0 failures.

## Deliberately NOT landed (disclosed)

- `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` — RED 4/22,
  **EXCLUDED** per coordinator (`w650h16-commit.md`), no owner green run.
- In-flight lanes mj/mr/mt/na files (ranker_fallback_court_w984mt,
  internal_api_followon_court_w984na, w984mr/mj/na probes, execution_fabric_hook
  files, run_idempotency / art_27 / freeze_window / multitenant /
  checkout_actuation / capability_liveness / platform_route /
  approval_tier_downgrade / return_hold_avatars M tests — owner lanes lm/lh-family
  partial, not in this batch's candidate list).
- mf-family `priv/ash_surface/*` + `manufacture.ex.eex` graphql removal —
  no landed receipt in this repo claims them.
- `cleanup-plan.json` / `emergency-reclaim-receipt.json` / `priv/semantic/generated/` —
  coordinator triage, not lane deliverables.

## Replay

```
git fetch origin && git checkout feat/playwright-surface
git log --oneline 20a24db0..17ef4b54   # 5 commits
```
Receipt self-carried at `docs/sjira/v26.10.7/plans/w984nd-commit.md`.
