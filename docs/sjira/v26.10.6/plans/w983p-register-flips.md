# W983p — register sweep: 4 flips (W731 limits, W750-G2, W765 GAP-D, W802/W819 mounted)

- Lane W983p, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (dirty campaign tree; no commit — coordinator owns commits).
- Register: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`. Only writes:
  register row flips (4) + this receipt.

## Method

Re-read the register fresh on disk (post-W982t/W983d). For each remaining OPEN row,
determined already-landed vs genuinely-open against this session's receipts, then
witnessed the cited courts on a fresh lane build root
(`_build-laneW983p`, `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`):
`mix compile` exit 0 (fresh full compile of deps + app), then one combined court run —

```
mix test test/xaas/graphlaw_limit_gate_test.exs \
         test/xaas/graphlaw_limit_seams_test.exs \
         test/xaas/operations/capability_liveness_deepening_test.exs \
         test/xaas/governance/freeze_window_active_gate_test.exs \
         test/xaas_web/graphql_http_surface_test.hxss  # (typo guard: graphql_http_surface_test.exs)
         test/xaas/graphql_domain_wiring_court_test.exs \
         test/xaas/graphql_schema_test.exs
# Actual: graphql_http_surface_test.exs (no typo); Result: 44 passed, exit 0
```

## Per-row verdict table

| row | verdict | evidence |
|---|---|---|
| W731 GAP(graphlaw-limits-not-enforced) | **FLIPPED → REPAIRED** | w976-design-wave5.md SPEC-10 (`Xaas.Graphlaw.LimitGate`, depth-gate consumer) + w981k-registry-limits-seams.md (byte-limit gates at the real `Xaas.Bridges.Graphlaw.do_assess/3` seams: max_request_bytes / n3_max_term_bytes / n3_max_total_bytes, typed `:limit_exceeded`, fail-open pinned) + w982l (SPEC-10 LANDED-UNCOMMITTED, limit_gate.ex on tree). Court green this lane. Row demand "no consumer gates on EngineLimit rows" is answered by two real consumer gates with mutation-rationale courts. |
| W750-G2 (detect/1 blind to upsert-overwritten regressions) | **FLIPPED → REPAIRED** | w968c-design-wave1.md SPEC-14 (previous_status column + migration `20261007231000`, `SetPreviousStatus` before_action change, detect/1 in-place regression branch; blindness pin flipped; 11 passed ×5 in receipt) + w982l (SPEC-14 LANDED-COMMITTED, commit `fd471722`). Court green this lane (capability_liveness_deepening_test.exs in the 44-run). |
| W765 GAP-D (FreezeWindow runtime consumer gates) | **FLIPPED → REPAIRED** | w969b SPEC-18 (check + court 5 passed, commit `5a853130`) + w969c (wired on `ApprovalEnvironmentPromote :approve`; W970b open-sweep ceded the row to this landing) + w982l (SPEC-18 LANDED-COMMITTED). Court green this lane. |
| W802/W819 graphql-http-surface (never mounted) | **FLIPPED → REPAIRED** | w975b-design-wave4.md §SPEC-30 (Absinthe.Plug mounted at `lib/xaas_web/router.ex:302-313` behind internal-API auth, absinthe_plug dep mix.exs:148, court `test/xaas_web/graphql_http_surface_test.exs`) + w982l (SPEC-30 LANDED-UNCOMMITTED verified; http-api-surface.md `/api/graphql` section written). Courts green this lane (graphql_http_surface + domain wiring + schema tests in the 44-run). Sibling domain-coverage row stays OPEN (see below). |
| W819 GAP(graphql-domain-coverage) "3 wired, not all" | still OPEN | W973c extended the schema domain list 3→19 and w982a/w982u deepened per-resource wiring 10/19→12/19 — but the row's demand is "not all", and 7 domains (A2a, Coupling, Graphlaw, Generation, Igniter, Ledger, TemporalMemory… per w982a/w982u still-absent lists) remain without graphql blocks. Landed work narrows the gap; it does not close the row. |
| W729 UNSUPPORTED(atomic_update) | still OPEN | w982l: SPEC-08 STILL-PENDING — no lane, no receipt, no atomic_update diff in `lib/xaas/billing/changes/`. |
| W824 (QuiescentStop MCP wire coupling) | still OPEN | SPEC-32 STILL-PENDING per w982l (banned surface per w969c, no receipt); w982f confirms out of test-lane scope. |
| W849 backlog-2 (CI/regen leg) | still OPEN | SPEC-34 STILL-PENDING per w982l: no CI leg, no regen-check task, no receipt. |
| W902 (shared xaas_test DB contamination) | still OPEN | environmental; coordinator hygiene pass / per-lane test DBs; no repair receipt. |
| W804 (dev DB migration stamp operator action) | still OPEN | operator action on xaas_dev, not lane-safe; W971 audit annotation stands. |
| W784 (TOFU trust chain) | still OPEN | UNSUPPORTED deferred to campaign backlog; no receipt names a landing. |

## Register tally after this lane (grep on disk)

- `grep -c "OPEN | "` → **12**; `grep -c "| REPAIRED |"` → **39** (of 51 rows).
- OPEN remainder: W729 atomic_update, W819 domain-coverage, W824, W849 backlog-2,
  W902, W804, W784 + rows whose repairs are design-class (W729 multitenancy
  PARTIAL, etc. — see register body).

## Standing

- Flips: 4 rows OPEN → REPAIRED, each backed by (a) a landed surface on tree and
  (b) a court I witnessed GREEN ×1 this lane on a fresh pinned-toolchain root
  (the combined 44-passed run above).
- Standing of this receipt: ALIVE for the witness run (commands quoted, exit 0);
  register/receipt edits uncommitted on tree.
- Falsifier: re-run the combined court command on a fresh root; any RED, or any
  cited surface absent from tree (`lib/xaas/graphlaw/limit_gate.ex`,
  `lib/xaas/operations/changes/set_previous_status.ex`,
  `lib/xaas/governance/checks/freeze_window_active.ex`,
  `lib/xaas_web/router.ex:302-313`), invalidates the corresponding flip.

## Lane hygiene

`_build-laneW983p` (450 MB) deletion was DENIED by the session permission system —
left for the coordinator at integration (same precedent as W982t/W983d). No
lib/test files touched; only `w859-typed-gap-register.md` (4 row flips) + this
receipt. No commit.
