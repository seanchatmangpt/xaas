# W399 — Runbook freshness re-verify (2026-10-06, lane W399)

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only audit; sole write is this file.
Verified against live `git status --porcelain` (238 lines: 156 M, 2 R, 80 ??) and the
w214 G1–G11 add-lists (`docs/sjira/v26.10.6/plans/w214-staging-sequence.md`, 208 path
tokens) exactly as the runbook cites them.

Method: exact-path diff of porcelain vs w214 group paths (dir entries cover by prefix).
Known DO-NOT-COMMIT items (`ggen.lock`, `GGEN-SH-*` logs, `.clap-noun-verb/`,
`.ggen_igniter/receipts/2026-10-06.jsonl`) excluded per runbook §2 before classifying gaps.

## Per-group verdicts

| group | verdict | correction |
|---|---|---|
| G1 deps | CURRENT | — |
| G2 release | CURRENT | — |
| G3 config | CURRENT | — |
| G4 CI | GAP | add `.github/workflows/closure-gates.yml` (untracked). FLAG: w354 marks it do-not-commit until the GGEN_SHA-vs-ggen.lock SHA question (w327) is resolved — commit only after coordinator admission. |
| G5 lib (66 lines) | GAP | add 4 paths: `lib/xaas/vault.ex` (OS-17 vault guard, M), `lib/xaas/ultracode/autonomic.ex` (M), `lib/xaas_web/live/chicago/seller_live.ex` (M), `lib/xaas_web/a2a/v1_transport_plug.ex` (?? new; pairs with G5's `a2a_parse_floor.ex`). 66 → 70 lines. |
| G6 generated (8 lines) | GAP | add 8 `priv/resource_snapshots/repo/*` entries (actuation_intents/actuation_receipts JSONs, billing_revenue_recognitions/, graphlaw_capabilities/, graphlaw_engine_limits/, ultracode_runs/, witness_certified_receipts/, witness_verification_keys/). Same generated family as G7b's W247 migration; alternatively split into a new **G7c** `chore(repo): add W247 resource snapshots` staging `git add priv/resource_snapshots/`. |
| G7 / G7b migrations | CURRENT | — |
| G8 scripts/courts/bench | CURRENT | — |
| G9 tests (70 lines) | GAP | add 10 paths: `test/xaas/vault_env_guard_test.exs` (??; OS-17 test pin), `test/xaas/receipt/r_projection_test.exs` (M; w369 conversion), `test/mix/tasks/xaas_self_digest_test.exs` (M), `test/xaas_web/a2a/v1_sse_test.exs` (??), `test/xaas_web/execution_fabric_controller_test.exs` (M), `test/xaas/chicago/presence_pin_test.exs` (??; w359), `test/xaas/ultracode/{autonomic_profile_sense,machine_experience,semantic_drive}_test.exs` (3× M). 70 → 80 lines. |
| G10 e2e + playwright (22) | CURRENT | all 22 paths still on porcelain (2 R renames, 2 M e2e, 17 new e2e, playwright.config.cjs) |
| G11 docs/plans (24 lines) | GAP | add 4 paths: `docs/claude/diataxis/README.md` (M) + 3 how-to corrections — `docs/claude/diataxis/how-to/{add-a-real-json-api-route-to-an-ash-resource,author-ggen-templates-safely,fix-ash-admin-and-use-ggen-for-codegen}.md` (M). 24 → 28 lines. |

## Unplaced-path inventory (27 paths across 5 groups)

- G4: 1 path (closure-gates.yml, admission-gated)
- G5: 4 paths
- G6/G7c: 8 paths (priv/resource_snapshots/repo/*)
- G9: 10 paths
- G11: 4 paths

`priv/semantic/` appears in porcelain only as an untracked directory line; its
`generated/castle_bridge_shacl.ttl` placement is already handled by the w214 C1
admission gate — no gap.

## Item 3 — w390 sync-output staging dir in the castle.ex caveat: GAP

The runbook's castle.ex caveat (§1.1, cites w334, BINDING) instructs staging the
SYNC-OUTPUT version of `lib/xaas/castle.ex` (`26839b9d…`) but names no location for the
materialized copies. They live in
`/Users/sac/xaas/docs/sjira/v26.10.6/plans/w390-sync-output-staging/` (8 files, relative
paths preserved: `lib/xaas/castle.ex` + the 7 generated files incl.
`priv/semantic/generated/castle_bridge_shacl.ttl`; verified on disk).
**RUNBOOK-GAP:** the caveat must reference this path — without it the coordinator cannot
execute the w334 binding without re-deriving w390's materialization. Correction text: in
§1.1 caveat, append "Materialized sync-output copies:
`docs/sjira/v26.10.6/plans/w390-sync-output-staging/` (w390)." Note this dir is inside
`docs/sjira/v26.10.6/` so it will be swept into the G11 directory add — coordinator should
confirm whether w390 staging copies should ship inside the G11 commit or be deleted
pre-G11.

## Receipt

- Gap count: **5 group-level gaps (G4, G5, G6, G9, G11) + 1 caveat gap (w390 path) = 6
  runbook corrections; 27 unplaced paths.**
- Falsifier: any path listed above absent from fresh porcelain at execution time voids
  its row (paths go stale same-day, w214 C7).
- No git mutations; sole write is this file.