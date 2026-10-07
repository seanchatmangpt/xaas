# W828 — Castle Execute Court

- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface`, lane W828
- **Date**: 2026-10-07
- **Standing**: PARTIAL_ALIVE
- **Deliverable**: `test/xaas/castle_execute_court_test.exs` (new; 10 tests, all passing; mock gate `[]`)
- **Receipt**: this file

## Scope executed

Read `lib/xaas/castle.ex` (`Xaas.Castle`, `Xaas.Castle.Admission`,
`Xaas.Castle.Actions.Execute`, `Xaas.Castle.Kernel.CLI`),
`lib/xaas/generated/castle_bridge_edges.ex`
(`Xaas.Castle.Generated.EdgeCatalog`), `lib/xaas/operations/route_castle_run.ex`,
`lib/xaas/actuation.ex` (`prepare_external`/`checkpoint_external`/
`seal_external`/`json_safe`), plus existing tests
(`castle_bridge_test.exs`, `castle_refusal_negative_test.exs`,
`test/xaas/generated/castle_bridge_contract_test.exs`). New court covers:

1. **(a) Edge catalog** — real structure assertions on the real catalog: 8
   ordered edges (sequences 10..80), exact names, exactly one DO boundary
   (`nested-brce-do`, sequence 50, from
   `Xaas.Operations.RouteCastleRun.execute`, to `CASTLE BRCE`, authority
   `BRCE_ONLY`, receipt-before/after + replayable all true — the W793 trace);
   authority vocabulary `[ADMIT_ONLY, BRCE_ONLY, CONSTRUCT_ONLY, RECEIPT_ONLY,
   VERIFY_ONLY]`; sequence 10 is the only edge without a receipt-after
   obligation; all edges replayable.
2. **(b) Execute admission, typed refusals with zero durable state yield**:
   `RouteCastleRun :execute` without Reactor context →
   `REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED`; expired envelope →
   `REFUSED_XAAS_ADMISSION_EXPIRED`; foreign witness digest →
   `REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH` at the kernel boundary (on the
   Ash-action path this check is currently shadowed by the protocol defect
   below); lawful traversal refused
   `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH` (defect witness, below).
3. **Lawful traversal, real durable result** — real `prepare_external` → real
   `Admission.witness/3` → real `Kernel.CLI.execute` subprocess →
   `standing == "ALIVE"`, 64-hex construct/receipt/process/replay digests,
   1 prepare + 1 outcome BRCE receipt digests, `evidence_commit` ALIVE,
   `recovered_from_evidence == false`, `kernel_binary_sha256` bound to the
   checkpoint. Determinism ×2: identical result maps; and after
   `seal_external`, re-prepare replays (`status == :replayed`, same receipt
   id, same intent id, zero new receipts).
4. **(c) RouteCastleRun reflection (honest absence)** — execution persists
   zero `RouteCastleRun` rows (`Ash.read! == []`); the durable reflection is
   the outer `ActuationReceipt` (`resource_module ==
   "Xaas.Operations.RouteCastleRun"`, `action == "execute"`, `:prepared` on
   refusal, `:succeeded` only via explicit `seal_external`).

## W828 defect witness (typed gap)

At HEAD `a0723bf6` the lawful Execute traversal through the admitted Ash
action is refused: `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH`.

- Root cause: `Xaas.Castle.Contract.identity().protocol` is the **atom**
  `:CASTLE_PAAS_XAAS_BRIDGE_V2` — the GGEN override at
  `lib/xaas/castle.ex:114` redefines `@protocol` from the original string
  literal to an atom — while `Xaas.Actuation` persists checkpoints through
  `json_safe/1` (`lib/xaas/actuation.ex:892`), which stringifies atoms before
  the jsonb write. `Xaas.Castle.Admission.checkpoint/2` reloads the persisted
  checkpoint from Postgres and compares `checkpoint["protocol"]` against the
  atom, so every lawful traversal through `RouteCastleRun :execute` refuses
  after the real durable checkpoint binds. The kernel surface (witness +
  hand-bound checkpoint, no jsonb round trip) completes the same traversal and
  yields the real DO result — this localizes the defect to the
  persist/reload protocol compare, not to admission or DO logic.
- Consequence: the full `Xaas.Castle.run/2` Reactor pipeline
  (witness → manufacture → checkpoint → private execute → seal) cannot reach
  `:succeeded` at this HEAD; the `:castle_kernel` court
  (`test/xaas/castle_bridge_test.exs`) exercises the same path and is
  expected red against a real CASTLE binary until this is fixed.
- Witnessed by two dedicated tests (`(b4)` + the jsonb round-trip proof).
- Minimal fix (not applied in this lane — lane scope is test-only): either
  restore `@protocol` to the string literal in the GGEN override block, or
  compare `to_string(contract.protocol)` in
  `Xaas.Castle.Admission.verify_checkpoint/2` and
  `Xaas.Castle.Kernel.CLI.verify_runtime_checkpoint/4`.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW828 \
  mix test test/xaas/castle_execute_court_test.exs
# Result: 10 passed (2.2s), 0 failures, 0 skipped
```

Iteration receipts: first run 1/8 (cold lane build; failures were real-behavior
discovery — wrong assumed flags in the catalog assertion, and the protocol
skew surfacing as REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH); 7/10; then
8/10; final 10/10. All lib-side behavior assertions were corrected to the
observed real behavior; the protocol skew was kept as an explicit defect
witness rather than normalized away.

Mock gate: `scan_mock_usage(["test/xaas/castle_execute_court_test.exs"])` → `[]`.

## Falsifier / replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW828 \
  mix test test/xaas/castle_execute_court_test.exs
```

- If `Xaas.Castle.Contract.identity().protocol` becomes a string (or the
  compare is stringified), the two (b4) defect-witness tests fail by design
  and must be flipped to assert `{:ok, result}`.
- If the edge catalog is regenerated with different content, test (a) fails by
  design (content pin).

## Standing vocabulary

- Test file: **ALIVE** (10/10 passing at `a0723bf6`)
- Edge catalog court: **ALIVE**
- Lawful Execute-through-Ash path: **BLOCKED
  (REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH)** at this HEAD — Ash/reload
  path only; the kernel-level traversal is **ALIVE**
- RouteCastleRun honest-absence reflection: **ALIVE**
- Determinism ×2 (kernel result identity + sealed-receipt replay): **ALIVE**

## Typed gaps

- `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH` on the lawful Ash-action path
  (atom/string skew, see defect witness) — docketed here for a fix lane; the
  fix must flip the two (b4) witness tests.
- The `:castle_kernel` court with the exact real CASTLE binary was NOT run in
  this lane (requires the cross-repo workflow's binary + env); kernel
  traversal here used the disclosed real-subprocess stub pattern.
- `_build-laneW828` left on disk — lane-local `rm -rf` was permission-denied;
  coordinator must delete it at integration (per the lane-lease cleanup law).
