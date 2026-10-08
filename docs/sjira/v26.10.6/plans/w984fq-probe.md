# W984fq — probe receipt: OPEN_GAP prose residue refresh (post-W984eb FRIA flip)

- Lane: W984fq, canonical checkout /Users/sac/xaas, branch feat/playwright-surface.
- No commit (per dispatch). Prose-only diff: exactly one file touched,
  `test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs` (moduledoc only).
- Subject: lib flip verified on disk first —
  `lib/xaas/semantics/oversight_governance.ex` fria/0 now returns **all five rights
  `status: :EVIDENCED`** (lines 281/305/320/334/354); authority-channel entry
  (`:access_to_effective_remedy_authority_channel`, line ~337) cites
  `lib/xaas/semantics/incident_report.ex` + `transmit/1` `:PREPARED_NOT_TRANSMITTED`.
  W984eb flip confirmed; `worker_notification/0`'s separate
  `incident_reporting: {:OPEN_GAP, ...}` (line 130-133) intentionally remains OPEN_GAP.

## Residue matrix (grep "OPEN_GAP" across test/)

| file | site | class | disposition |
|---|---|---|---|
| test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs | moduledoc lines 5-9 ("honestly-typed OPEN_GAP authority channel recorded in the FRIA itself") | prose, stale | **FIXED** — now states the W984eb :EVIDENCED flip with date |
| same | moduledoc "deterministic, open-gap present" | prose, stale | **FIXED** — now "per-right typed statuses (post-W984eb all five rights are :EVIDENCED)" |
| same | moduledoc "Disclosed finding" block (lines 36-42) | prose, stale | **FIXED** — reclassified as "Resolved disclosed finding (closed by W984eb)" |
| test/eu_ai_act/{title_i,title_ii,title_iii,title_iv_v,title_vi_xiii,smoke}_test.exs, README.md | flunk-by-design OPEN_GAP corpus + inventory prose | intentional contract (tagged :eu_ai_act_open_gap) | LEFT — intentional OPEN_GAP contract, untouched |
| test/eu_ai_act/title_iii_test.exs:196 | "typed EVIDENCED/OPEN_GAP statuses" | accurate as written | LEFT — describes the status vocabulary, not a claim of an open gap |
| test/xaas/semantics/oversight_governance_test.exs:7,55,66-68,89 | worker_notification/0 OPEN_GAP contract | intentional contract; lib still returns OPEN_GAP for wn.incident_reporting | LEFT — assertion matches live lib; line 89 `status in [:EVIDENCED, :OPEN_GAP]` is tolerant |
| test/xaas/dataset_admission_test.exs:107 | historical W865 comment | historical note | LEFT |
| test/xaas/actuation/quiescent_stop_deepening_test.exs:194,199 | prose "honestly-recorded OPEN_GAP materialisation channel is still open" | prose, stale (all rights now EVIDENCED) | LEFT (not this lane's file; disclosed below) |
| test/xaas/actuation/quiescent_stop_deepening_test.exs:203 | `assert Enum.any?(fria.rights, &(&1.status == :OPEN_GAP))` | **assertion reads the stale contract** | LEFT as-is (outside lane file scope; see disposition below) |

**quiescent_stop disposition**: line 203's assertion now contradicts the flipped lib
(all five rights :EVIDENCED, zero OPEN_GAP) and would fail if run. It is an
assertion, not prose — outside this lane's prose-only contract, not in a lane-owned
file. Flagged for the owning lane/corpus owner; not silently patched.

## Gates (real output)

1. Touched files: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fq mix test test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs test/xaas/semantics/oversight_governance_test.exs`
   → **21 passed, 3 excluded, exit 0.**
2. Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'` → **`[]`**.
3. Full census: repeated **compile-aborts from concurrent lanes' in-flight court
   files** (compile-abort is not a failure count, per W876): excluded per run —
   `test/xaas_web/live/family_court_w984gh_test.exs`,
   `test/xaas/telemetry/family_court_w984gj_test.exs`,
   `test/xaas/semantics/master_equation_test.exs` ("module currently being defined"
   — parallel-compile race while another lane rewrites it),
   `test/xaas/operations/audit_log_court_w984go_test.exs`.
   One real test failure observed mid-run: `test/xaas/sjira/ard_court_test.exs:720`
   ARD-005 — ontology-shape inventory drift (ClosureResidual +
   MarketplaceCapabilityDelta missing from an expected string). **Not this lane's
   diff** (prose-only moduledoc strings cannot change outcomes) — pre-existing /
   other-lane churn, disclosed.
   Full census result (run 6, excluding all `*_w984*_test.exs` in-flight lane court
   files + `master_equation_test.exs`): **4941 passed / 35 failed / 37 skipped /
   1610 excluded, exit 2, Finished in 1238.3s**. Passed ≥ 1388 gate met; 0
   compile-aborts in this run. The 35 failures are concentrated in 17 files churned
   by concurrent lanes' landed lib changes (semantic_replay_test ×9, origin_authority
   ×4, ranker ×7, execution_fabric/next_read web tests, ard_court ARD-005 inventory
   drift, ash_surface drift guards, ...) — **zero failures in either touched file**
   (both touched files: 21 passed / 0 failed, exit 0). Disclosed as other-lane /
   pre-existing relative to this lane's prose-only diff, which cannot alter outcomes.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW984fq` **denied by the permission system** —
the lane build-root lease (`_build-laneW984fq`, ~one full test compile) is left on
disk for the coordinator to remove at integration.
