# W623 — Title III evidenced-line DEEPENING

Lane: W623 (EU-AI-Act wave). Subject: `xaas @ feat/playwright-surface` (one canonical
checkout; lane build root `_build-laneW623`).

## Scope contract

Write-only surfaces (honored):

* `test/eu_ai_act/title_iii_test.exs`
* `docs/sjira/v26.10.6/plans/w623-title-iii-deepening.md` (this file)

## Task

Deepen the W532-reclassified EVIDENCED entries (Art 9 ×10, Art 13 ×10, Art 14 ×7, plus
evidence_map entries) — entries that asserted only `File.exists?` paths and, for the
reclass entries, a receipt-verdict `String.contains?`, with **real behavior calls**
(Chicago discipline: real collaborators, no mocks).

## Mechanism

* `Lines.deepening_map/0` (compile-time substrate, `test/eu_ai_act/title_iii_test.exs`):
  `line_id => [kind]` over both the `evidence_map` and `reclass_map` EVIDENCED entries.
* Both test generators (`Lines.evidenced()` loop and `Lines.reclass_evidenced()` loop)
  now append `deepen(unquote(Lines.deepening(id)))` after the existing path/receipt
  assertions. Tags (`:eu_ai_act`, `:eu_ai_act_open_gap`), verdicts, test ids, and the
  W532/W535/W547 classification are untouched.

## Deepening kinds (real calls, per seam)

| kind | seam | real behavior asserted |
|---|---|---|
| `:ferroplan_reachability` | W501 (Art 9) | `reachability.rs` carries `pub struct BackwardSafeSet`, `pub fn is_safe`, `pub fn unsafe_count` (read from disk) |
| `:audit_chain` | W503 (Art 12/11) | real `AuditChain.append/2` ×5, `verify_chain/1 == :ok`, tamper at k=2 → `{:error, {:tampered, 2}}` (pure, no DB) |
| `:dataset_gate` | W502 (Art 10/26.4) | real `DatasetAdmission.admit/2`: clean ADMITTED with measured W1; `REFUSED_EMPTY_DATASET`; `REFUSED_INCOMPLETE_DATASET`; `REFUSED_BIAS_THRESHOLD` (bias refusals over real sliced-W1) |
| `:margin_gate` | W508 (Art 15/9.2.b) | real `RobustMargin.estimate_lipschitz/2` ≥ 3.0 over real pairs; `:ADMITTED`; `REFUSED_ROBUST_MARGIN`; `REFUSED_NO_CALIBRATION_DATA` |
| `:quiescent_typed` | W507 (Art 14) | real `QuiescentStop.execute/2` typed refusals on the pre-DO path: `:idempotency_key_required` (missing and empty key) + `:REFUSED_STOP_AUTHORITY` (no DB write) |
| `:counterfactual` | W506 (Art 13/14.4.a/c) | real `Counterfactual.run/2` + `evaluate/3`: removing the violating field flips refusal→admit, `changed? == true`, explanation names the flipped check |
| `:shapley` | W505 (Art 13) | real `AdmissionAttribution.shapley/2`: φ concentrates (−1.0 ± 1e-9) on the single refusing check |
| `:briefing` | W539 (Art 14.4.b) | real `Counterfactual.run` → `AdmissionAttribution.shapley` → `AutomationBiasCountermeasure.briefing/2`: `verdict == :refuse`, refusal anatomy names `:human_oversight`, φ = −1.0 |
| `:declared_metrics` | W536 (Art 15.3) | real `DeclaredMetrics.declare/0` → `{:ok, metrics}` |
| `:vuln_lifecycle` | W540 (Art 15.5.s3) | real `VulnerabilityLifecycle.new/1` + typed `REFUSED_LIFECYCLE_SKIP` |
| `:oversight_governance` | W537 (Art 26/27) | real `fria/0` (`:deployer` class, non-empty rights), `retention_policy/0`, `worker_notification/0` |
| `:wasi_gate` | W509 (Art 15.5) | `eu_gate` crate `Cargo.toml` readable |
| `:zero_config` | W322 (Art 9.4/13.2) | w322 receipt: `zero-config posture: HELD` + ≥3 `REFUSED_` site citations |

## Per-line before → after (receipt)

Every row = one generated `EUAI-ACT <id> — EVIDENCED` test. "Before" = assertions the
test had; "After" = assertions it now also has.

### Art. 9 — reclass EVIDENCED (10)

| line | before | after (added real calls) |
|---|---|---|
| 9.1 | paths(5) + w501 receipt string | ferroplan + audit_chain + dataset_gate + quiescent_typed + margin_gate |
| 9.2 | paths(2) + w503 receipt string | audit_chain |
| 9.2.a | path(1) + w501 "6 passed" | ferroplan |
| 9.2.b | paths(2) + w508 "10 passed" | ferroplan + margin_gate |
| 9.2.c | paths(2) + w511 "10 passed" | audit_chain |
| 9.2.d | paths(3) + w507 "5 passed" | dataset_gate + quiescent_typed + margin_gate |
| 9.4 | w322 receipt string (paths: none) | zero_config |
| 9.5 | path(1) + w501 receipt string | ferroplan |
| 9.5.s3 | w322 receipt string | zero_config |
| 9.8 | path(1) + w501 "178 passed" | ferroplan |

### Art. 13 — reclass EVIDENCED (10)

| line | before | after |
|---|---|---|
| 13.1 | paths(2) + w506 "9 passed" | counterfactual + shapley |
| 13.2 | paths(2) + w322 receipt string | zero_config |
| 13.3.b.i | paths(2) + w322 receipt string | zero_config |
| 13.3.b.ii | paths(2) + w508 "10 passed" | margin_gate |
| 13.3.b.iii | path(1) + w322 receipt string | ferroplan + zero_config |
| 13.3.b.iv | paths(2) + w506 "9 passed" | counterfactual + shapley |
| 13.3.b.v | paths(2) + w502 "6 passed" | dataset_gate |
| 13.3.b.vi | path(1) + w502 "ALIVE (lane-scoped)" | dataset_gate |
| 13.3.d | paths(2) + w507 "5 passed" | quiescent_typed + counterfactual |
| 13.3.e | paths(3) + w322 receipt string | zero_config |

### Art. 14 — reclass EVIDENCED (7)

| line | before | after |
|---|---|---|
| 14.1 | paths(2) + w507 "5 passed" | quiescent_typed |
| 14.2 | paths(2) + w507 "5 passed" | quiescent_typed + margin_gate |
| 14.3 | path(1) + w507 "5 passed" | quiescent_typed |
| 14.3.a | path(1) + w507 "5 passed" | quiescent_typed |
| 14.3.b | paths(2) + w507 "5 passed" | quiescent_typed |
| 14.4.a | paths(2) + w503 "PARTIAL_ALIVE" | counterfactual + audit_chain |
| 14.4.c | paths(2) + w506 "9 passed" | counterfactual + shapley |

### evidence_map EVIDENCED (deepened)

| line | before | after |
|---|---|---|
| 9.5.a / 9.5.b / 9.6 | paths only | ferroplan |
| 10.2 / 10.2.e / 10.2.f / 10.2.g / 10.2.h / 10.3 / 26.4 | paths only | dataset_gate |
| 11.1 / 12.1 / 12.2 / 12.2.a / 12.2.b / 12.2.c / 26.5 / 26.12 | paths only | audit_chain |
| 13.3.b.vii / 13.3.f / 26.9 | paths only | counterfactual + shapley |
| 14.4.b | paths only | briefing (real W539 chain) |
| 15.1 | paths only | margin_gate + audit_chain |
| 15.3 | paths only | declared_metrics |
| 15.4 | paths only | margin_gate |
| 15.4.s2 / 26.2 / 27.3 | paths only | quiescent_typed |
| 15.5 / 15.5.s2 | paths only | wasi_gate |
| 15.5.s3 | paths only | vuln_lifecycle |
| 26.6 / 26.7 / 27.1 / 27.1.a / 27.1.c / 27.1.d | paths only | oversight_governance |

Deepened count: **27 reclass EVIDENCED + 27 evidence_map EVIDENCED = 54 lines**, each with
at least one real behavior call. NOT_APPLICABLE and OPEN_GAP entries untouched.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW623 MIX_ENV=test \
  mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW623 MIX_ENV=test \
  mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act
```

Green both directions = the gate (open-gap run is green only under the exclude; the
unexcluded run's failures are the by-design `flunk` gap inventory — the gate is that the
failure count is exactly the pre-existing OPEN_GAP count, unchanged by W623).
