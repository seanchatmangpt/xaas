# W871 — Autonomic-capability-loop tutorial verify (claim-by-claim)

Lane W871, xaas v26.10.6 campaign, repo `/Users/sac/xaas`, branch
`feat/playwright-surface`, HEAD `a0723bf6` (+ this lane's working-tree diff,
per lane contract; no commit). Sole written surfaces:
`docs/claude/diataxis/tutorials/build-an-autonomic-capability-loop.md` +
this receipt. No build root, no `mix test` run in this lane (documentation
verification lane; every court is cited from its own existing receipt/suite
on disk, file existence witness-checked below).

## Method

Every claim in the tutorial was checked against the module on disk at this
subject: snippet text compared to the real DSL, prose claims to the real
code path. The wave's landed reality (ultracode W840 clock seam, W817
negotiation court, W749 10 fabric verbs, W666 OCEL egress courts) was read
from its receipts and confirmed against code.

## Per-claim table

| # | Tutorial claim (step) | Verdict | Evidence |
|---|---|---|---|
| 1 | Intro: loop files exist in repo (intro) | VERIFIED | all 13 cited files `ls`-checked OK, incl. `~/chatman-ecosystem/scripts/weaver-live-matrix.sh` |
| 2 | Step 1: `weaver-live-matrix.sh` emits `{"capability", "authority", "status", "executed", "exit_code", "subject", "detail"}` rows (step 1) | VERIFIED | row shape matches the resource's `accept` list (`capability_liveness_receipt.ex:174`) and the task's decode map (`xaas.ingest_capability_receipts.ex:46-54`) |
| 3 | Step 2 ingest snippet (`accept` list, upsert identity) | CORRECTED | snippet lacked the W768 `validate CapabilityLivenessReceiptStatusGate` line; added (`capability_liveness_receipt.ex:179`) |
| 4 | Step 2 policies snippet: bypass-read + deny floor only | CORRECTED | resource now also carries `bypass action(:check_regressions)` (SystemActor) and `bypass action(:ingest)` (SystemActor `:oban_scheduler`) (`capability_liveness_receipt.ex:80-112`) and an AshOban `*/15 * * * *` schedule (`:45-59`); snippet + bullets updated |
| 5 | Step 3: task calls `Ash.create(authorize?: false)` and "bypasses the deny-by-default floor" (step 3) | **CORRECTED (stale)** | task now runs THROUGH authorization as `Xaas.SystemAuthority.new(:oban_scheduler)`, `authorize?: true` (`xaas.ingest_capability_receipts.ex:61-64`; comment :55-60 states "No authorize?: false bypass remains"); snippet, prose, and "What you built" item 3 rewritten |
| 6 | Step 3: "one-shot batch import" characterization of the loop | CORRECTED | Analyze step also fires on the AshOban 15-min cron (`capability_liveness_receipt.ex:45-59`), not only on ingest/HTTP poll; step 3 + "What you built" updated |
| 7 | Step 4: `detect/1` orders by `inserted_at`, flags latest non-ALIVE after prior ALIVE, `authorize?` defaults to `true` | VERIFIED | `capability_liveness_regressions.ex:24-57` matches snippet and prose exactly |
| 8 | Step 5: task output strings ("Ingested N/N ...", "No capability regressions ...", "N REAL capability regression(s) detected:") | VERIFIED | `Mix.shell().info/error` lines at `xaas.ingest_capability_receipts.ex:70,82,85` match |
| 9 | Step 6: token plug constant-time compare, fail-closed 503 when env unset, 401 otherwise | VERIFIED | `require_internal_api_token.ex:93-108,138` (`Plug.Crypto.secure_compare`, 503/401 paths) |
| 10 | Step 6: `/internal-api` specific routes registered before the catch-all `forward "/internal-api"` (shadowing rationale, commit `e07b9c8`) | VERIFIED | `router.ex:84-92` scope + comment |
| 11 | Step 6: controller calls `detect/1` and renders plain JSON | VERIFIED | `capability_regressions_controller.ex:18-26` matches snippet |
| 12 | Step 6: InternalApiRouter mounts the resource read-only at `/internal-api` | VERIFIED | `internal_api_router.ex:10-12` (`domains: [Xaas.Operations]`) |
| 13 | Step 6: ApiRouter "explicitly excludes Xaas.Ledger and Xaas.Accounts resources" (step 6) | **CORRECTED (stale)** | ApiRouter mounts ALL 7 domains incl. `Xaas.Accounts` + `Xaas.Ledger` (`api_router.ex:12-20`); the exclusion is resource-level — sensitive resources declare no JSON:API routes — and `Xaas.Accounts.Org` is the exception declaring routes under `/api/orgs` (`lib/xaas/accounts/org.ex:178-188`); paragraph rewritten |
| 14 | Step 7: three test files exist, Chicago-style | VERIFIED | all three `ls`-checked; suites exist on disk (not re-run in this lane) |
| 15 | Step 7 curl paths/responses | VERIFIED (routes exist) | router lines above; responses not reproduced in this lane (no server boot) |
| 16 | See Also: emitter attached to `:stop`, never `:exception` | VERIFIED | `ocel_ash_emitter.ex:14-27` moduledoc states exactly this |
| 17 | (new) Courts section added | ADDED | "Courts backing this tutorial (v26.10.6)" section, dated 2026-10-07, citing W723/W817/W768/W840+W811/W749/W666 with file:line anchors; every cited test file + receipt `ls`/grep-checked on disk (incl. `test/xaas/ultracode/lease_kernel_deepening_test.exs:485` describe block) |

## Corrections made in place

1. Step 2 policies snippet + bullets: added the two scoped bypasses
   (`check_regressions`/`ingest` via `Xaas.Checks.SystemActor`), the AshOban
   15-min schedule, and the W768 status-gate `validate` line (claims 3, 4).
2. Step 3: replaced the stale `authorize?: false` snippet and prose with the
   current system-authority path (claim 5); dropped the "one-shot batch
   import" framing (claim 6).
3. Step 6: corrected the ApiRouter exclusion claim (claim 13).
4. "What you built" item 3: same fix as claim 5/6.
5. Added the dated, receipt-cited "Courts backing this tutorial
   (v26.10.6)" section (claim 17).

## Standing

PARTIAL_ALIVE: every correction is verified against code on disk at this
subject (file:line evidence in the table); the courts section cites suites
whose standing rests on their own receipts (W723 16/16 ALIVE, W666 6
passed, W840/W817/W749 as received). No court re-run and no commit in this
lane; the tutorial's runnable claims (step 5 commands, step 7 tests/curls)
were witness-checked for existence/wiring, not re-executed here.
