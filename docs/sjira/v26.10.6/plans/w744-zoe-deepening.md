# W744 — zoe-deepening (lane receipt)

- Subject: /Users/sac/xaas @ a0723bf6, branch `feat/playwright-surface`. NOT committed (lane rule).
- New file: `test/xaas/zoe_deepening_test.exs` (15 tests, one file). No other file touched.
- Standing: **ALIVE** for the tested surface; deepening receipted, not a production diff.

## What was read first (O)
- `lib/xaas/zoe/event_simulation.ex` — two surfaces: whole-event timeline
  (`simulate/2`, no contract_version) and `zoe-event-ops/v1` snapshot surface.
- `lib/xaas_web/a2a/zoe_event_simulation_agent.ex` — A2A agent (`contract` /
  `simulate {json}` / input_required usage).
- `lib/xaas_web/a2a/zoe_event_plug.ex`, `router.ex` scope `/a2a` with
  `:api` + `:require_internal_api_token` pipelines; `XaasWeb.Plugs.RequireInternalApiToken`
  (401 on bad/missing token while `INTERNAL_API_TOKEN` set; 503 when env unset —
  fail closed). Test token fixed in `test/test_helper.exs`.
- Existing tests: `test/xaas/zoe/*`, `test/xaas_web/a2a/zoe_event_simulation_agent_test.exs`
  (GenServer-level, no wire coverage existed before this lane).

## What the tests assert (real values, no mocks)
- (a) Determinism, byte-identical: same input ×3 → identical `Jason.encode!` of the
  whole result (both surfaces). Mutation: `registration_exceptions 1→0` (timeline)
  and `walk_ins 1→3` (snapshot) change both the encoded stream and the digest /
  `simulation_receipt.digest` (64-hex). Digest replay: `EventSimulation.digest/1`
  of the digest-less result equals the embedded digest.
- (b) Wire path via ConnCase through the real router: missing/garbage bearer → 401
  (fail-closed marking plug; 503-on-unset-env asserted in existing tests, not
  duplicated). `contract` → 200 JSON-RPC, `result.task` state `TASK_STATE_COMPLETED`,
  text decodes to contract map. `simulate` → completed task, `simulation_status
  COMPLETE`, `attendance.total == 2`, `security.shortfall == 1`, incident report
  routed to `["church_event_lead", "security_management"]`. Malformed simulate JSON
  → `TASK_STATE_FAILED` with typed text `invalid_simulation_json` /
  `Jason.DecodeError` / `position:`. Malformed JSON-RPC body → `error.code == -32700`.
  Unknown text → `TASK_STATE_INPUT_REQUIRED` with usage text (carried in
  `status.message`, not artifacts — real wire behavior).
- (c) Enforced invariants: timeline obligations all `authority: NONE`,
  `CONSTRUCT_ONLY`, `CANDIDATE`, `NOT_EXECUTED`, sorted by id; summary counts and
  capability set match obligations; specific real policy firings (roster incomplete,
  admin reinforcement at seq 1 (staff 1 < min 2), registration reinforcement
  (backlog 30 > cap 10), security reinforcement, incident report, submit attendance).
  Snapshot trace sequences strictly 1..N; every item `do_authority: false`, boundary
  in OBSERVE/SELECT/CONSTRUCT; incident report/resolve/routing/reconciliation
  payloads asserted at exact values.

## Verification (real run, lane build root)
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW744 \
  mix test test/xaas/zoe_deepening_test.exs
# ... 15 tests, 0 failures (0.6s); one mid-lane run was interrupted by a
# concurrent lane's transient broken `lib/xaas/ocel.ex` on disk (not this
# lane's file; re-ran clean after it resolved)
```
Final run tail: `Result: 15 passed` / `Finished in 0.6 seconds`. Mock gate: grep for
`mock|Mock|patch(` over the new file matches only the moduledoc line "No mocks".

## Typed gaps (admitted)
- GAP(seed): `Xaas.Zoe.EventSimulation` exposes no seed parameter — determinism is
  input-determined; the task's "same seed → byte-identical / different seed →
  different" is realized as identical-vs-mutated inputs, which is the only seed-like
  axis the code offers. UNKNOWN whether an RNG-seeded mode is desired upstream.
- GAP(503-tier): the plug's 503 (unset `INTERNAL_API_TOKEN`) branch is not
  duplicated here (existing `execution_fabric_controller_test.exs` covers it);
  this lane asserts the 401 tier only.
- GAP(wire-vs-agent): the `/a2a/zoe-event` agent GenServer is app-supervised
  (`Xaas.Application`), so wire tests run against the real supervised agent —
  no per-test start_link; covered states are COMPLETED/FAILED/INPUT_REQUIRED.
- GAP(task_text helper): on the wire, failed/input-required task text lives in
  `status.message.parts`, artifacts only on completed tasks (observed, now asserted).

## Lane lease
- `_build-laneW744` deletion was refused by the session permission system
  (`rm -rf` denied), so the lane build root is **left for the coordinator** to
  remove at integration (per lane brief: "delete when done, else leave").
- No commit; no other files modified.
