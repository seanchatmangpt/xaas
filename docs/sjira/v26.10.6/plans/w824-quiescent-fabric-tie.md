# W824 — Quiescent-stop attractor ↔ execution-fabric tie receipt

- **Lane**: W824, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6`.
- **Standing**: PARTIAL_ALIVE — the fabric↔quiescent coupling is real at the
  kernel layer (both surfaces route through the admitted
  `Xaas.Actuation.run/4` DO kernel and share its idempotency ledger), but the
  coupling is absent at the wire layer: no fabric verb invokes
  `QuiescentStop.execute/2`, so the module's typed refusal envelope
  (`REFUSED_STOP_AUTHORITY`, `REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`,
  `target: :quiescent`, `already_stopped: true`) never surfaces on the MCP
  wire. Evidence, not invention: grep over `lib/` shows the only
  `QuiescentStop` references outside its own module are the AIro risk-mapping
  entry (`lib/xaas/semantics/airo_risk_mapping.ex:107`) and the test tree.
- **Deliverable**: `test/xaas_web/quiescent_fabric_tie_test.exs`
  (4 tests, Chicago-style, real ConnCase HTTP behind the real
  `RequireInternalApiToken` bearer gate, real sandbox rows
  (Run/Epoch/ActuationIntent/ActuationReceipt/Provider), capability source
  and actuation registry injected through their own config seams
  (`:ultracode_capability_sources`, `:ultracode_actuation_registry`),
  restored `on_exit`. No mocks; no path bypasses `Xaas.Actuation.run/4`.

## Wiring fact (evidence over invention)

The fabric has NO dedicated halt verb. The halt reaches the wire through
W745's lease-gated `actuate` verb with `action: "actuate_status"`,
`input: %{"status" => "suspended"}` —
`POST /internal-api/execution/mcp` → `dispatch_tool("actuate", ...)` →
`Xaas.Ultracode.Lease.actuate/2` → `Xaas.Actuation.run/4`. This court ties
the fabric layer to the SAME durable halt record the W704 module court
asserts, and files the wire-layer gap as a typed finding.

## Courted invariants (all asserted against real wire bodies / real rows)

- (a) A halt initiated through the admitted fabric path (lease-gated
  `actuate` verb, registered `{Xaas.Marketplace.Provider, actuate_status}`
  pair, suspended status) lands the durable halt record W704's module court
  asserts: a real `ActuationIntent` keyed by the halt's `idempotency_key`
  with lease-bound authority (`kind` `ultracode_lease_actuation`, sha256
  `lease_fingerprint` ≠ raw token), a sealed `ActuationReceipt` bound to the
  intent, and the provider driven to the quiescent status `:suspended`.
  Cross-checked against the module-level contract: after the fabric halt,
  `QuiescentStop.execute/2` on the same subject with a fresh key answers the
  typed `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT` — both layers observe the
  one monotone attractor through the one ledger.
- (b) Idempotent replay through the fabric: same lease, same key → the
  kernel surfaces the distinct `status: "replayed"` envelope with
  `replay: true` and the SAME `intent_id`/`receipt_id` — a typed no-op, no
  new ledger rows, subject unchanged. (The first run asserted `"succeeded"`
  here; the real wire answers `"replayed"` — the court was corrected to the
  observed, stronger contract.)
- (c) Typed refusals at the fabric layer for malformed halt authority:
  missing lease → `WORK_NOT_FOUND`/`no_lease` surface failure; live lease
  without the capability → `UNAUTHORIZED`/`capability_required` (the
  two-port court, authority never forms); kernel-level missing
  `idempotency_key` → `:idempotency_key_required` tool error. After every
  malformed shape the subject is untouched (`status == :pending`).
  The W723 auth floor (401/503 matrix) is already courted on this exact
  surface by W745's (d) — not re-courted here.
- (d) Determinism: the halt no-lease refusal produces byte-identical full
  HTTP JSON bodies across two calls.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW824 \
  mix test test/xaas_web/quiescent_fabric_tie_test.exs
# => Finished in 1.4 seconds (0.00s async, 1.4s sync)
# => Result: 4 passed

# boundary check (W745 fabric + W704 module courts)
... mix test test/xaas_web/execution_fabric_deepening_test.exs \
      test/xaas/actuation/quiescent_stop_test.exs \
      test/xaas/actuation/quiescent_stop_deepening_test.exs
# => Result: 20 passed, 7 excluded
#    (the 7 excluded are W704's @moduletag :eu_ai_act — default-excluded by
#     config, pre-existing behavior, not a W824 regression)
```

## Typed gaps / disclosures

- **Wire-layer coupling absent (the honest finding)**: `QuiescentStop`'s
  typed envelope never surfaces on the MCP wire — a fabric halt returns the
  kernel's raw envelope (status/replay/intent_id/receipt_id keys), not the
  module's `{stopped_at, target: :quiescent, authority}` /
  `{:error, :REFUSED_STOP_*}` contract. The quiescent attractor is
  court-level coupled (shared kernel + shared ledger), not verb-level
  coupled. Closing this would mean either a dedicated fabric halt verb or a
  QuiescentStop projection of the kernel envelope — out of lane scope
  (test-only lane by design; no production code changed).
- **Replay contract correction during the lane**: the initial (b) assertion
  expected `"succeeded"` on the second same-key call; the real kernel
  surfaces `"replayed"`. Test corrected to the observed contract —
  disclosed per fix-forward.
- **Lane build root**: `_build-laneW824` deletion denied by the permission
  system — coordinator to delete at integration per the fanout cleanup law.
- **No commit made** (per dispatch); the deliverable is the new test file +
  this receipt.
