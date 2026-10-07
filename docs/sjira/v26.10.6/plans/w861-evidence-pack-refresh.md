# W861 — S3 Evidence Pack Refresh (receipt)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`,
2026-10-07. Lane W861, no commits made (per lane contract).

## What was refreshed

`docs/cro/artifacts/s3-evidence-pack-v26.10.6.md` — appended §6
"Post-consolidation refresh (W861, 2026-10-07)" with the consolidation
wave's 8 key evidence rows. Format follows the existing pack (§1/§2 style:
path + one-line description + standing taken verbatim from each wave's
receipt). Replay-validation receipt
(`docs/cro/artifacts/s3-evidence-pack-replay-validation.md`, W439) was read
first; its format and findings (incl. the stale integrity-sha FINDING) were
preserved untouched — no changes to that file.

## Rows added (8)

| Wave | Path(s) | Standing (from receipt) |
|---|---|---|
| w821 terminal census 2 | `test/eu_ai_act/title_i_test.exs`, `title_iii_test.exs`, `title_iv_v_test.exs` | ALIVE (terminal census certified) |
| w778 gate fix verify | `test/eu_ai_act/title_i_test.exs`, `title_iii_test.exs` | Gate ALIVE; F1 VERIFIED; F2 PARTIAL (corrected forward) |
| w780 claim authority guard | `lib/xaas/actuation.ex`, `test/xaas/sa2a_computation_boundary_test.exs` | ALIVE (lane-local, uncommitted) |
| w786 onetime migration | `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs` | ALIVE (verification ladder green) |
| w801 freeze enforcement | `lib/xaas/governance/validations/audit_export_token_no_active_freeze_window.ex`, `test/xaas/governance/freeze_window_test.exs` | PARTIAL_ALIVE |
| w836 health court | `test/xaas_web/health_court_test.exs`, `lib/xaas_web_web/controllers/health_controller.ex` | ALIVE (11/11 two consecutive runs) |
| w837 TS drift court | `test/xaas_web/ts_codegen_drift_court_test.exs` | ALIVE (3/3 exact subject) |
| w829 sensitive routing court | `test/xaas_web/sensitive_resources_routing_court_test.exs`, `lib/xaas_web/router.ex` | Court ALIVE; receipt PARTIAL_ALIVE (one typed gap) |

## Existence checks (real `test -f`, 2026-10-07)

15/16 referenced paths OK. 1 MISSING:
`lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex` — deleted by
a concurrent sibling lane; the w780 receipt itself documents this deletion
(line 62). Not evidence for any row; disclosed in pack §6.

## Hash transition

Pack carries no internal aggregate hash; only its own sha256. Pre-refresh:
`aaab08f9ba5aa8ebb8bc5832062f9c88a4a3ddd2dc4e22c1850bb78735985260`
Post-refresh: `f014c17f6806062063cb234460941666b0361222cee64ecb431fa61fd24cfb38`
(`shasum -a 256`, recomputed after append; tail of file verified on disk).

## Standing

PARTIAL_ALIVE — pack refreshed with verified-existence rows and honest hash
transition; rows' standings are quoted from their own receipts (2 ALIVE-carrying
typed gaps disclosed: w778 F2 PARTIAL, w829 typed gap, w801 PARTIAL_ALIVE).
Pack section §3/§4 replay commands were not re-run in this lane (out of lane
scope; last replay validation = W439). No build root, no commits.

## Falsifier

A row whose evidence path fails `test -f`, or a standing quoted other than
as its receipt states, invalidates this refresh.
