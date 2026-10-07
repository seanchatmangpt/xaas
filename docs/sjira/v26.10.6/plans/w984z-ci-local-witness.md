# W984z — Local CI Witness: Generated-Surface Regen Drift Check

Lane: W984z · campaign v26.10.6 · repo /Users/sac/xaas · branch feat/playwright-surface · HEAD 5f7f70d9094c37669b56bc34be6edd7011c9e3e3 (plus uncommitted working-tree state of the branch, disclosed).

## Task

W984v (w984v-w849-ci-leg.md) noted the regen-drift CI step (`.github/workflows/ci_cd.yaml:112-113`, `run: mix xaas.generated.regen_check`) is committed-surface only, awaiting push/PR. Witness it locally with lane build isolation.

## Commands (both runs)

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984z /usr/bin/time -p mix xaas.generated.regen_check
```

Toolchain: elixir 1.20.2-otp-28 via asdf (pinned, `.tool-versions`), as required.

## Results

| run | exit | real time | census |
|---|---|---|---|
| 1 (fresh `_build-laneW984z`, full compile) | 0 (clean) | 1094.32s | 4 OK / 6 SKIP / 0 DRIFT |
| 2 (warm) | 0 (clean) | 100.18s | 4 OK / 6 SKIP / 0 DRIFT |

Determinism: identical census and identical per-surface verdicts across both runs. Run 2 compiled 1 changed .ex (working-tree churn from other lanes on the shared checkout, not drift).

### Census (10 surfaces, aligned 1:1 with registry_drift_guard)

OK (4): `assets/js/ash_rpc.ts`, `lib/xaas/generated/capital_census/facts.ex`, `lib/xaas/generated/zcode_event_registry.ex`, `lib/xaas/telemetry/ocel_envelope.ex`

SKIP (6):
- `lib/mix/tasks/xaas.library.manufacture.ex` — BLOCKED(policy-floor-upgrade-pending), witnessed 2026-10-07 (W983c triage, W984g correction): no renderer escape bug; tracked file drifted from ontology render solely in policy direction (tracked `authorize_if always()` vs ontology-backed deny-by-default `authorize_if actor_present()` floor at 4 sites). Owner-decision actuation; sha256 pin authoritative.
- 5 × UNSUPPORTED: `castle_bridge_contract.ex`, `castle_bridge_edges.ex`, `sa2a_bridge_contract.ex`, `sa2a_bridge_edges.ex`, `sa2a_mcp_descriptor.ex` (regen-toolchain-external), `lib/xaas_web/mcp_scope.ex` (regen-command-not-in-repo) — sha256 hand-edit pins authoritative (registry_drift_guard).

## Drift classification

**No drift (exit 0)** — nothing to classify. `w984g-regen-pins-upgrade.md` does NOT exist at `docs/sjira/v26.10.6/plans/`; however its correction content is already carried inline in the regen_check SKIP message (W983c/W984g witness text), so the pins as-deployed are clean: 0 DRIFT on the committed surface.

## Standing

WITNESSED — ALIVE (local witness of the CI step, exact command, pinned toolchain, lane build root). Exit 0 twice, deterministic. CI execution on push/PR remains the formal leg; this receipt is the local pre-witness W984v called for.

Falsifier: `MIX_ENV=test mix xaas.generated.regen_check` returning non-zero or a differing census on this HEAD.

Cleanup: `_build-laneW984z` deletion was denied by the session permission boundary; the lease is left on disk for coordinator deletion (disclosed, ~full test-compile tree, warm).
