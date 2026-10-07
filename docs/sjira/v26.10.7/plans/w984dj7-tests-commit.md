# W984dj7 — completed-probe-lane test files onto HEAD (2 batches)

Lane: W984dj7, v26.10.7 fleet seal, checkout `/Users/sac/xaas`, branch
`feat/playwright-surface`.

## Subject

- Base: `ab0f3870` (origin HEAD at lane start)
- Batch 1: **`abdd9af9`** — 12 new files, 1930 insertions
- Batch 2: **`e2e9f95d`** — 5 new files, 801 insertions
- Push: fast-forward to `feat/playwright-surface` at
  `https://github.com/seanchatmangpt/xaas.git` (fetch-then-ff, no force).

## Staged table (18 candidate lanes → 17 landed files + 1 already-on-HEAD)

| file | owner lane | receipt on disk | landed |
|---|---|---|---|
| test/xaas/ultracode/process_group_court_test.exs | w984dj4 | w984dj4-ultracode.md | abdd9af9 |
| test/xaas/ultracode/durable_close_court_test.exs | w984cy3 | w984cy3-ultracode-probe.md | abdd9af9 |
| test/xaas/generation/lock_persistence_depth_w984dj5_test.exs | w984dj5 | w984dj5-generation.md | abdd9af9 |
| test/xaas/generation/manifest_depth_w984cp_test.exs | w984cp | w984cp-depth.md | abdd9af9 |
| test/xaas/generation/substitution_policy_depth_test.exs | w984cw3 (also claimed w984dj4) | w984cw3-depth.md | abdd9af9 |
| test/xaas/a2a/agent_identity_policy_depth_test.exs | w984db + w984ak | w984db-a2a-probe.md / w984ak-depth-batch3.md | abdd9af9 |
| test/xaas/a2a/catalog_ingest_depth_test.exs | w984db | w984db-a2a-probe.md | abdd9af9 |
| test/xaas/igniter/refusal_code_policy_depth_test.exs | w984ak | w984ak-depth-batch3.md | abdd9af9 |
| test/xaas/temporal_memory/observation_supersede_chain_depth_test.exs | w984ak | w984ak-depth-batch3.md | abdd9af9 |
| test/xaas/conference/attendee_session_lifecycle_court_w984dm_test.exs | w984dm | w984dm-probe.md | abdd9af9 |
| test/xaas/actuation/spg_gate_test.exs | w984dj2 | w984dj2-spg-gate.md | **already on HEAD via W650g2 `a5f81439`** (landed mid-flight) |
| test/xaas/accounts/revoke_verifier_depth_test.exs | w984cw5 | w984cw5-accounts-probe.md | abdd9af9 |
| test/xaas/accounts/stale_struct_update_chain_test.exs | w984ct2 (stale-struct) | w984ct2-stale-struct.md | abdd9af9 |
| test/xaas/platform/webhook_delivery_lifecycle_w984dc_test.exs | w984dc | w984dc-probe.md | e2e9f95d |
| test/xaas/witness/audit_chain_invariant_test.exs | w984bn | w984bn-audit-chain.md | e2e9f95d |
| test/xaas/sjira/delivery_batch_depth_court_test.exs | w984di | w984di-sjira-probe.md | e2e9f95d |
| test/xaas/research_runtime/closure/coordinator_test.exs | w984cy2 | w984cy2-families-probe.md | e2e9f95d |
| test/xaas/governance/w984cy4_override_decision_court_test.exs | w984cy4 | w984cy4-gov-73.md | e2e9f95d |

## Exclusions (not staged this lane)

- `finding_lifecycle_depth_test.exs` — already landed by W650r (`ab0f3870`).
- `hddl_mermaid_depth_test.exs` — already tracked (landed by W650g corpus).
- All other untracked test files in `test/xaas/` — no on-disk owner receipt
  verified this lane (airini/airo, deepening/, vault/, perf/, self_digest/,
  dev_seeds*, coupling, graphlaw_limit_seams, os_register, sparql_bridge,
  tunnel, billing w650y/w984dp/w984dd, conference w984do/w984dn, marketplace
  w984dg, oban w984cn, platform w984bq, ultracode w984bt, witness w984cm,
  governance w984cq/w984cz, semantics w640/w6xx, accounts org_*,
  execution_fabric_hook, prov_origin_header, generated regen_check,
  causal_receipt, chicago graphlaw deepening, catalog_consumption w984dg,
  provider_preapprove, castle_*, refusal_ledger_export_depth,
  approval_deployment_quarantine, freeze_window_deepening,
  audit_export_token_actor (claimed by w984cy4 receipt but file not
  confirmed co-landed — left for its owner sweep), etc.). These belong to
  other completed/running lanes and are left to their owners or a later
  sweep lane.

## Gates (real output)

- Build root `_build-laneW984dj7` (deleted at integration per lane-lease law).
- Fresh-root compile: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj7 mix
  compile` → **EXIT=0** (warnings only; e.g.
  `lib/xaas/operations/refusal_ledger_export.ex:388` — untracked file
  belonging to another lane, not in scope).
- Staged suites ×1, single batched run of all 17 files on disk (incl.
  spg_gate, already on HEAD — its suite ran green too): **99 tests,
  0 failures, 0 skipped** (5.2s). `TEST_EXIT=0`.
- Compile ran in background and hit the 10-min harness cap twice before
  completing on the third resume (incremental, same root) — disclosed,
  final state EXIT=0 witnessed.

## Standing

ALIVE for the staged subject: 17 test files committed in 2 pathspec
batches (`abdd9af9`, `e2e9f95d`), suites green on a fresh lane build root
under the pinned asdf toolchain, receipts verified per file before
staging. Batch 2 files were not re-run as a separate suite invocation —
they ran in the single batched gate above from the same on-disk bytes.
