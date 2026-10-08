# W984js — Execution-Fabric Controller Probe (receipt)

Lane: W984js, canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface` (no branch switch, no commit, no stash).

Subject: `lib/xaas_web/controllers/execution_fabric_controller.ex`.
`format_reason/1`'s atom clause was already courted by W984ej; this probe
censused the controller's other branches against the fabric test family
(`fabric_controller_test.exs`, `execution_fabric_controller_test.exs` (54),
`execution_fabric_deepening_test.exs`, `execution_fabric_hook_depth_test.exs`,
`quiescent_fabric_tie_test.exs`, `controllers/execution_fabric_surface_test.exs`).

## Dispositions

| Branch | Disposition |
|---|---|
| hook `session_start` / `pre_tool_use` allow+deny / post_tool_use family / `stop` close + not_closeable / unknown-event 404 | COVERED (existing fabric family) |
| `rpc/1` initialize / tools/list / tools/call ok + isError | COVERED |
| `rpc/1` **-32601 method-not-found arm** | UNCOVERED → courted (unknown method + tools/call-without-params) |
| `rpc/1` **`notifications/` arm** | UNCOVERED → courted; **residue finding**: `{:ok, :notification}` flows into `json(conn, :notification)`; Jason encodes the bare atom as the JSON string `"notification"` — HTTP 200 whose body is neither a JSON-RPC envelope nor the JSON-RPC 2.0-mandated silence. No crash (rescue arm does not fire). Behavior pinned as observed; silencing it is a deliberate future transition. |
| `dispatch_tool` argument-shape catch-alls: `heartbeat` (missing token), `record_provider_event` (missing event), `close_candidate` (missing head), `cancel_work` (missing token/reason) | UNCOVERED (a.3/c.4 hit only unknown-lease and `refuse`) → courted; all answer the W984ca bare-atom `format_reason/1` clause (no leading colon), exercising that clause on the MCP surface |
| `dispatch_tool("surface", _)` / `("resolve_capability", _)` missing-arg arms | UNCOVERED (existing courts hit unknown-lease only) → courted (WORK_NOT_FOUND / NO_CAPABILITY with the typed details) |
| `lease_token/1` empty-binary clause via hook `pre_tool_use` | UNCOVERED → courted (`""` → typed 403 `no_lease`, never a blank token handed to `Lease.admit_tool`) |
| `claim_opts/1` both arms, `outcome/1` casing + fallback, `reason_atom/1` atom-DoS fence, `actuation_capability` capability-required arm, `quiescent_intent?` both arms, `format_actuation` quiescent/non-quiescent, `create_run` 201/400/429/403, `rate_limited?` family, `receipts` org-scoped 404 / invalid-id 400 / unscoped regression | COVERED or INDIRECTLY-COVERED (deepening b.1/b.2/a.2/a.4, controller tests, quiescent tie courts) |
| `read_json` Unfetched raw-read fallback | INDIRECTLY COVERED (c.3 text/plain raw-read path) |
| `format_reason/1` Ash.Error.Invalid / Ash.Changeset field:message clauses | INDIRECTLY COVERED (submit 400 courts) |

## Court

`test/xaas_web/controllers/fabric_court_w984js_test.exs` — 10 tests, real
ConnCase through the router behind the real `RequireInternalApiToken` bearer
gate, real sandboxed Postgres, zero mocks. Mutation rationale per test.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984js \
  mix test test/xaas_web/controllers/fabric_court_w984js_test.exs
→ ..........  Finished in 0.9 seconds   Result: 10 passed

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984js \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []
```

Standing: ALIVE (observed execution on the exact subject; both gates exit 0).

## Cleanup

Lane build root `_build-laneW984js` deleted after gates (see session note if
denied). No commit made, per lane contract.
