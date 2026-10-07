# W749 — Runtime-contract reference refresh (how-to/reference deepening)

- **Standing**: PARTIAL_ALIVE — every page edit below is verified against code on the exact
  subject; the three deepening-court suites are cited as evidence sources but were NOT
  re-run in this lane (no build root allocated; lane constraint). Standing of those courts
  is inherited from their own receipts (w723: ALIVE 16/16; w745/w747 suites exist on disk
  and are cited as pinned contracts).
- **Lane**: W749, v26.10.6 campaign, repo /Users/sac/xaas, branch `feat/playwright-surface`,
  HEAD a0723bf6. No commit (coordinator owns commits). Sole written surfaces:
  `docs/claude/diataxis/reference/ultracode-runtime-contract.md` +
  this receipt.
- **Evidence sources**: receipts `docs/sjira/v26.10.6/plans/w723-token-floor-court.md`,
  `test/xaas_web/execution_fabric_deepening_test.exs` (W745),
  `test/xaas/actuation/run_idempotency_deepening_test.exs` (W747), plus direct reads of
  `lib/xaas_web/controllers/execution_fabric_controller.ex`,
  `lib/xaas/ultracode/lease.ex`, `lib/xaas/ultracode/runtime_surface/failure.ex`.

## Per-claim verdicts

| # | Claim (page, pre-edit) | Verdict | Evidence |
|---|---|---|---|
| 1 | Header "v26.9.27", branch `v26.9.27/closure-runtime` | **CORRECTED** -> v26.10.6 / `feat/playwright-surface` @ a0723bf6 | git status of this checkout; page header now v26.10.6 |
| 2 | Ten MCP tools on `POST /internal-api/execution/mcp`, nine lease-token-gated, `claim_next` the only non-lease verb | **ADDED** (new "Worker verbs" table). Note: the W749 task brief said "8 worker verbs"; code has 10 `dispatch_tool/2` verbs / 10 `@mcp_tools` rows (`execution_fabric_controller.ex:72-220`, `dispatch_tool` clauses :423-556). The brief's count was stale, not the page. | controller grep: 10 `name:` rows, 20 `dispatch_tool` clauses (10 verbs x success/arity fallback) |
| 3 | Per-verb required args + kernel calls (`Lease.renew/1`, `admit_tool/2`, `record_provider_event/2`, `close/4`, `refuse/3`, `cancel/3` -> `:blocked` receipt, actuate re-resolution, `lease_context`+`CapabilityPort.resolve/4`, `surface/1`) | **ADDED** (verb table) | controller `dispatch_tool/2`; `lib/xaas/ultracode/lease.ex:509-527,753-757,948-1028,1107-1121,1253-1335` |
| 4 | Directed `claim_next` `epoch_id`: malformed non-UUID is typed `invalid_epoch_id`, never silent oldest-first fallback | **ADDED** | controller `claim_opts/1` (:409-419 region) |
| 5 | Token floor: absent env + no header 503 exact body; absent env + wrong bearer still 503; env + no/wrong bearer 401 exact body; Bearer parse single-element discipline | **ADDED** (W723 section; page previously had NO auth-floor statement) | w723 receipt (16/16 ALIVE); `test/xaas_web/require_internal_api_token_deepening_test.exs` exists on disk |
| 6 | 406-vs-auth residual on `/internal-api` json-api scope (Accept outranks floor); only `/api` forward scope fixed | **ADDED** (court finding, disclosed as residual) | w723 receipt Findings §1 |
| 7 | Refusal shapes: `WORK_NOT_FOUND/no_lease` Failure map on actuate w/o lease; `UNAUTHORIZED/capability_required` with `required` route string; `no_lease:"token"` string form for admit_tool/heartbeat/close_candidate; `lease_token_required` bare; capability court precedes registry so unregistered pair never downgraded to shape error; `unknown_tool`; 400 `invalid_request`/`invalid_json`; raise -> JSON-RPC 500 -32603 (never DebugPage); determinism x2; refuse seals receipt readable on `GET /internal-api/execution/epochs/:id/receipts` | **ADDED** (W745 section) | `test/xaas_web/execution_fabric_deepening_test.exs` courts a.1-e.2, c.4, (+); controller `mcp/2` rescue (:323-339), `rpc/1`, `tool_error/1` |
| 8 | `Xaas.Actuation.run/4` idempotency/replay contract beneath `actuate`: same-key replay returns original consequence, no new rows; distinct keys no dedup; replay survives restart; missing key / missing authority / unknown action exact typed refusals; key reuse while `:executing` not replayable; determinism x2 | **ADDED** (W747 section) | `test/xaas/actuation/run_idempotency_deepening_test.exs` tests (a)-(e); `Failure.from_term({:idempotency_conflict,_}) -> CONFLICTING_REPLAY` (`failure.ex:44`) already on page |
| 9 | Existing: closed 10-code failure vocabulary (`failure.ex:11-22`) | **VERIFIED** unchanged | `failure.ex` @codes matches page list exactly |
| 10 | Existing: tool-floor rows (`lease_admit` set, WebFetch/WebSearch forbidden-edge, Bash/git_push/publish refused, narrow-only override) | **VERIFIED** | `lease.ex:138,733-766` unchanged |
| 11 | Existing: actuate registry empty-by-default, subject from registry never wire, lease_fingerprint not raw token | **VERIFIED** | `lease.ex:969-1081` (`resolve_registered/3`, `actuation_registry/1`, `lease_fingerprint/1`) |
| 12 | Existing: atomic single-statement lease writes, pool capacity (prod 5, advisory lock), DurationBudget claim gate, AliveRequiresCourt downgrade | **VERIFIED** | `lease.ex:95-131,267-341,1495-1508` |
| 13 | Existing witness table rows | **VERIFIED** (all files exist); **ADDED** 3 rows for w723/w745/w747 suites | `ls` on test tree |

## Corrections made to the page in place

1. Header version/branch stale (v26.9.27 -> v26.10.6, `feat/playwright-surface`).
2. No stale factual claims found in the v26.9.27 body: every checked claim (work-envelope
   fields, surface fields, capability verdicts, failure codes, gate law, worker-env law,
   actuation registry law) still matches code at a0723bf6. Deepening content was ADDED as
   three new sections (worker verbs, token floor, refusal-shape contract) plus 3 witness
   rows, not substituted.

## What was NOT done

- No court re-run (no `mix test` in this lane; w745/w747 standing rests on their own
  receipts/suites, not a fresh run here). No commit. No other pages touched.
