# W650h14 — Gated lib/test integration commit (v26.10.7 fleet seal)

Lane W650h14. Repo `/Users/sac/xaas`, branch `feat/playwright-surface`.
Base at stage time: `ecf84663`; commit: **`3c03bffa`** (batch 1, 16 files),
docs commit: see below. Date 2026-10-07. Operator-delegated commit+push
authority, explicit pathspec only, no force.

## Gate (all fresh, lane root `_build-laneW650h14`, asdf toolchain)

1. `mix compile --force` from fresh lane root: **EXIT=0**
   (`Generated xaas app`; one pre-existing warning class in
   `refusal_ledger_export.ex:388` — landed file, not this batch).
2. eu_ai_act census `mix test test/eu_ai_act --include eu_ai_act
   --exclude eu_ai_act_open_gap`: **1354/1355 passed, 1 excluded** — one
   failure (`Xaas.EuAiAct.CounterfactualTest` Art 11) was a subprocess
   compile of `lib/xaas/sa2a/changes/execute.ex` hitting a concurrent
   lane's mid-edit working tree (compile-freeze SLA violation by that
   lane, disclosed). Isolated rerun of the file: **26/26, EXIT=0** →
   floor **≥1352/0/1 MET** with disclosure.
3. Staged-suite batch (16 staged files + tracked companions
   airo_shacl / w640 differential / dev_seeds / regen_check /
   actuation_test / counterfactual): **57 passed / 0 failed, EXIT=0**.

## Staged (commit `3c03bffa`, owner receipts verified on disk at stage time)

| files | owner receipt(s) |
|---|---|
| lib/xaas_web/plugs/prov_origin_header.ex (new), lib/xaas_web/router.ex, test/xaas_web/prov_origin_header_test.exs | w605-prov-o-plug.md (v26.10.7) |
| lib/xaas/dev_seeds.ex, test/xaas/dev_seeds_env_guard_test.exs, test/xaas/dev_seeds_idempotency_test.exs, e2e/seed-library.exs | w983f-devseeds-gate.md, w984bs-seed-guard.md |
| lib/xaas/semantics/airo_risk_mapping.ex, test/xaas/semantics/airo_risk_mapping_depth_test.exs | w984ce-airo-dedup.md |
| test/xaas/semantics/airo_ledger_surface_test.exs | w984dt-probe.md |
| priv/airo_risk_description.ttl (new) | w982m-airo-xaas-ttl.md |
| lib/mix/tasks/xaas.airo.compile_shacl.ex, priv/airo/profile.shacl.ttl | w650i-profile-iri.md (W640 finding-b IRI repair, shapes-digest rotation disclosed) |
| lib/mix/tasks/xaas.generated.regen_check.ex (new) | w982g-lspec-wave.md |
| test/test_helper.exs (:perf_smoke tag) | w982x-perf-smoke.md |
| test/xaas/conference_deepening_test.exs | w983a-w981s-restore.md |

## Excluded (typed, left to owners / later sweeps)

- **SPG files** (actuation.ex, spg_gate.ex, spg_gate_test, spg_integration_test):
  landed by their own lane mid-flight before staging (w984dq6 receipt landed;
  files absent from stage-time diff).
- **Unattributed/running-lane diffs**: oversight_governance pair,
  freeze_window_active_gate, multitenant_approval, capability_liveness,
  platform_route, return_hold_cascade_avatars, run_idempotency,
  art_27_1f, approval_tier_downgrade_controller, priv/packs manufacture.ex.eex
  template, priv/semantic/generated/, lib/xaas/compat/, test/sa2a/, and all
  untracked w984d*-series courts (no owner receipt verified at stage time).
- **test/xaas/airo/ pin courts**: ENV-DRIFT, pre-existing (w650h5 exclusion
  carried forward; confirmed still failing on external-checkout drift).

## Docs commit

Batch 2: v26.10.6 `_INTEGRATION_RUNBOOK.md` (runbook-merge lane),
`w984cj-coverage-map.md` (w650h8 re-census append), `w983g-freeze-deepening.md`
(receipt verification completion), plus this receipt.

## Standing

ALIVE for the gated landing itself (compile + census + batch all EXIT=0 on the
staged subject). Content standing of each staged file is its own lane's
standing, unchanged. Push: ff-only after fetch.
