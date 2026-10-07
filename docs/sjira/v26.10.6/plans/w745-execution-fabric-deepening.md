# W745 — Execution-fabric deepening receipt

- **Lane**: W745, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6`.
- **Standing**: PARTIAL_ALIVE — the MCP surface's typed-refusal lattice,
  actuation boundary, and auth floor are now courted; the lane did not add
  production code (test-only lane by design).
- **Deliverable**: `test/xaas_web/execution_fabric_deepening_test.exs`
  (15 tests, Chicago-style, real ConnCase HTTP, real sandbox rows, no mocks;
  capability source is a hand-written real interface impl injected through
  `:ultracode_capability_sources`, actuation registry through
  `:ultracode_actuation_registry`, both restored `on_exit`).

## Courted invariants (all asserted against real wire bodies)

- (a) Lease gating: `actuate`/`admit_tool`/`heartbeat`/`close_candidate` on an
  unknown lease answer the real typed shapes — surface-failure vocabulary
  (`WORK_NOT_FOUND`, details reason `no_lease`) for actuate; exact
  `no_lease:"no-such-lease"` strings for the pre-existing tools;
  `:lease_token_required` / `:lease_token_and_reason_required` arity
  refusals; live-lease-missing-capability → `UNAUTHORIZED`
  (`capability_required`) — the two-port law, not a shape error.
- (b) Actuate valid path: lease + actuating capability (`publish_change`
  via real source module) + registered `{Xaas.Marketplace.Provider,
  actuate_status}` pair routes into `Xaas.Actuation.run/4` and lands a real
  `ActuationIntent` (authority.kind `ultracode_lease_actuation`, provider,
  epoch_id, sha256 lease fingerprint ≠ raw token) + `ActuationReceipt` +
  real Provider mutation (`status == :active`). Unregistered pair →
  typed `unregistered_actuation` refusal, never a silent DO. No success
  fabricated: the refusal path is courted on the same wire.
- (c) Unknown verb → `unknown_tool:"deploy_everything"`; malformed JSON-RPC
  (no `method`) → 400 `bad_request`/`:invalid_request`; non-object JSON body
  (raw read path) → 400 `bad_request`/`:invalid_json`; malformed tool
  payload (non-binary lease_token) → typed
  `:lease_token_and_reason_required`, never a crash page.
- (d) W723 auth floor on this surface: missing bearer → 401 exact
  documented body; wrong bearer → 401; unset `INTERNAL_API_TOKEN` + wrong
  bearer → 503 fail-closed exact body.
- (e) Determinism ×2: actuate no-lease refusal and unknown-tool refusal
  produce byte-identical full HTTP JSON bodies across two calls each.
- (+) `refuse` MCP verb seals a real `Xaas.Ultracode.Receipt`
  (`outcome: refused`, evidence `refusal_reason`), epoch lands `:failed`
  via the atomic lease-guarded write, durably read back on the lawful
  `GET /execution/epochs/:id/receipts` surface.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW745 \
  mix test test/xaas_web/execution_fabric_deepening_test.exs
# => Finished in 1.6 seconds ... Result: 15 passed

... mix test test/xaas_web/execution_fabric_controller_test.exs \
      test/xaas_web/controllers/execution_fabric_surface_test.exs \
      test/xaas/ultracode/lease_test.exs
# => Result: 87 passed
```

## Typed gaps / disclosures

- **Shared-tree blocker repair (other lane's diff)**: `lib/xaas/ocel.ex`
  carried another lane's in-flight, non-compiling diff (missing `::` in the
  new `fold_object_state/2` `@spec`). Every `mix` command was blocked; per
  fix-forward I added the one token (`::`) — no behavioral change — and
  disclose it here for the owning lane/coordinator to fold into their
  commit. Files I did NOT touch otherwise; no commit made (per dispatch).
- **Lane build root**: `_build-laneW745` left in place (rm denied by the
  permission system) — coordinator to delete at integration per the
  fanout cleanup law.
- **Rescue-arm (-32603) contract** on the MCP dispatch is documented in the
  controller but not exercised by a real raise (no honest in-process way
  without mocking); c.4 instead courts the real malformed-payload behavior
  (typed tool error, HTTP 200). Left as a typed gap, not papered over.
- **Org-carrying token tier** for receipts org-scoping is courted by the
  pre-existing `execution_fabric_controller_test.exs`; W745 pins the
  org-less legacy tier only.
- Tags excluded by default config (`:eu_ai_act` etc.) did not apply to this
  file; all 15 tests ran sync.
