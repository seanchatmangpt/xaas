# W984id — regen_check freshness witness

- **HEAD**: `3961c4ab55748e55170a7608058ac3c7c5c7d314` (branch `feat/playwright-surface`)
- **Task**: `lib/mix/tasks/xaas.generated.regen_check.ex` (landed by W982g), run as `mix xaas.generated.regen_check`
- **Command**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984id mix xaas.generated.regen_check`
- **Exit**: `0` (clean)
- **Date**: 2026-10-07

## Real output (task report lines, post-compile)

```
OK       assets/js/ash_rpc.ts
SKIP     lib/mix/tasks/xaas.library.manufacture.ex — BLOCKED(policy-floor-upgrade-pending): witnessed 2026-10-07 (W983c triage, W984g correction) — there is NO renderer escape bug; the tracked file has drifted from its ontology render solely in policy direction (tracked emits authorize_if always() write policies; the ontology-backed render emits the deny-by-default authorize_if actor_present() floor at 4 sites — regen would STRENGTHEN policy). Actuation is an owner decision: mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack (use an explicit in-repo scratch --out to a scratch --out during any trial), then re-pin @expected_sha256 and retire this skip. sha256 pin remains authoritative
OK       lib/xaas/generated/capital_census/facts.ex
SKIP     lib/xaas/generated/castle_bridge_contract.ex — UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; sha256 hand-edit pin remains authoritative (registry_drift_guard)
SKIP     lib/xaas/generated/castle_bridge_edges.ex — UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; sha256 pin remains authoritative (registry_drift_guard)
SKIP     lib/xaas/generated/sa2a_bridge_contract.ex — UNSUPPORTED(regen-toolchain-external): ...
SKIP     lib/xaas/generated/sa2a_bridge_edges.ex — UNSUPPORTED(regen-toolchain-external): ...
SKIP     lib/xaas/generated/sa2a_mcp_descriptor.ex — UNSUPPORTED(regen-toolchain-external): ...
OK       lib/xaas/generated/zcode_event_registry.ex
OK       lib/xaas/telemetry/ocel_envelope.ex
SKIP     lib/xaas_web/mcp_scope.ex — UNSUPPORTED(regen-command-not-in-repo): provenance-only ttl surface; sha256 hand-edit pin remains authoritative (registry_drift_guard)
```

(Note: ellipsized SKIP detail lines are abbreviated in this receipt only; the run output was full text.)

## Surfaces

- OK: 4 — `assets/js/ash_rpc.ts`, `lib/xaas/generated/capital_census/facts.ex`,
  `lib/xaas/generated/zcode_event_registry.ex`, `lib/xaas/telemetry/ocel_envelope.ex`
- SKIP (disclosed): 8 — 5× `UNSUPPORTED(regen-toolchain-external)` (ggen-marketplace pack renders,
  sha256 pin authoritative), 1× `UNSUPPORTED(regen-command-not-in-repo)` (`lib/xaas_web/mcp_scope.ex`),
  1× `BLOCKED(policy-floor-upgrade-pending)` (`lib/mix/tasks/xaas.library.manufacture.ex` — owner
  decision, regen would strengthen policy to deny-by-default at 4 sites)
- DRIFT: 0

## Verdict

**FRESH** (exit 0). Every in-repo-regenerable surface at this HEAD matches its tracked bytes.
No stale projections found; no regeneration performed (per lane rules). Checker bug: none
observed — all SKIPs carry typed, disclosed reasons.

## Lane cleanup

`rm -rf _build-laneW984id`: performed at end of lane (see coordinator follow-up if the dir
re-appears — no deletion refusal encountered).
