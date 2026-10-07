# W547 — Consolidation flip pass: OPEN_GAP → EVIDENCED / NOT_APPLICABLE

Lane W547 · EU-AI-Act wave · repo `/Users/sac/xaas` @ `feat/playwright-surface` ·
build root `_build-laneW547` (lease; coordinator deletes at integration).

## Scope

Flip OPEN_GAP corpus lines whose implementing surfaces landed this wave
(W533/W536/W537/W539/W540), asserting the real modules + their real test files.
Flips only where BOTH the module AND its test file exist on disk (verified
before each flip). No lib edits.

## Flip table

| line_id | verdict | surface (module + test) | receipt |
|---|---|---|---|
| 50.2 | EVIDENCED | `lib/xaas_web/plugs/synthetic_marking_plug.ex` + `test/xaas_web/synthetic_marking_test.exs` | `w533-art50-2-marking.md` |
| 15.3 | EVIDENCED | `lib/xaas/semantics/declared_metrics.ex` + `test/xaas/semantics/declared_metrics_test.exs` | `w536-art15-3-metrics.md` |
| 15.5.s3 | EVIDENCED | `lib/xaas/semantics/vulnerability_lifecycle.ex` + `test/xaas/semantics/vulnerability_lifecycle_test.exs` | `w540-art15-5-lifecycle.md` |
| 14.4.b | EVIDENCED | `lib/xaas/semantics/automation_bias_countermeasure.ex` + `test/xaas/semantics/automation_bias_countermeasure_test.exs` | `w539-art14-4b-bias-countermeasure.md` |
| 26.6 | EVIDENCED | `lib/xaas/semantics/oversight_governance.ex` (`retention_policy/0`) + `test/xaas/semantics/oversight_governance_test.exs` | `w537-art26-27-governance.md` |
| 26.7 | EVIDENCED | `lib/xaas/semantics/oversight_governance.ex` (`worker_notification/0`) + its test | `w537-art26-27-governance.md` |
| 27.1 | EVIDENCED | `lib/xaas/semantics/oversight_governance.ex` (`fria/0`, structured machine-checkable FRIA) + its test | `w537-art26-27-governance.md` |
| 27.1.a | EVIDENCED | `fria/0` `subject_system` + per-right protections | `w537-art26-27-governance.md` |
| 27.1.c | EVIDENCED | `fria/0` rights entries w/ Charter citations (affected categories) | `w537-art26-27-governance.md` |
| 27.1.d | EVIDENCED | `fria/0` per-right protection statements (risks of harm) | `w537-art26-27-governance.md` |
| 27.2 | NOT_APPLICABLE | scoping clause ("applies to the first use") — no independent obligation beyond evidenced 27.1 | — (typed reason in `not_applicable_map`) |
| 27.3 | EVIDENCED | safeguards on materialised risk = `lib/xaas/actuation/quiescent_stop.ex` + test (W507) + FRIA materialisation entry | `w507-art14-estop.md` + `w537-art26-27-governance.md` |
| 99.4.e | EVIDENCED | stale basis flipped: Art.26 duties now evidenced → governance + audit chain + quiescent-stop family | `w537-art26-27-governance.md` + `w503-art12-audit-chain.md` + `w507-art14-estop.md` |

13 flips total (12 OPEN_GAP → EVIDENCED, 1 OPEN_GAP → NOT_APPLICABLE).

Held honestly OPEN (gap inventory remains executable pressure):

- `27.1.b` — FRIA has no period/frequency schedule field
- `27.1.e` — FRIA does not describe oversight-measure implementation
- `27.1.f` — FRIA's only materialisation entry is the typed OPEN_GAP authority channel
- `49.3`, `8.1` (Title III), Art. 73/74/86 families, `3.49`/`4.1` (Title I —
  outside this lane's file contract)

## Verification

- `MIX_BUILD_ROOT=_build-laneW547 MIX_ENV=test mix test test/eu_ai_act
  --include eu_ai_act --exclude eu_ai_act_open_gap` —
  **Result: 1048 passed, 24 excluded** (green)
- `MIX_ENV=test mix test test/eu_ai_act --include eu_ai_act --include
  eu_ai_act_open_gap` — **Result: 1048/1072 passed, Failed: 24** (the 24
  remaining honest OPEN_GAPs: 37 → 24, target ≤25 met)
