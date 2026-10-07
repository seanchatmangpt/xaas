# W866 — Kernel-refused quiescent halt: refusal-mapping court (typed finding on W844's UNKNOWN)

- **Lane**: W866, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6` (no commit — coordinator
  owns transitions).
- **Standing**: ALIVE (ledger + wire refusal semantics, as actually wired).
  W844's disclosed UNKNOWN — "the `refusal` mapping path in `format_actuation`
  is wired but never courted end-to-end" — is now courted, and the court
  **refines the premise**: the end-to-end wire response carrying a `refusal`
  key is **not reachable through the admitted fabric path** under the current
  kernel contract. The courts pin the real behavior on both layers instead.
- **Diff** (hand-written, 1 file, test-only; no lib change per lane contract):
  - `test/xaas_web/quiescent_fabric_tie_test.exs`: extended with two courts
    (8 total in the file now, W824's 4 + W844's 2 + W866's 2):
    - **(g) kernel-refused quiescent attempt** — first halt succeeds (key
      bound to a sealed-succeeded intent); a second quiescent-shaped attempt
      (same key, different input) is refused by the kernel **at admission**
      (`replay_or_refuse/6` input-hash mismatch). Real asserts: wire tool
      error `error =~ "idempotency_conflict"`; exactly ONE intent row for the
      key; its receipt still `:succeeded`; provider still `:suspended`.
    - **(h) malformed stop authority** — `QuiescentStop.execute/2` with
      authority missing `:source` (W704's `authority_admitted?/1` contract)
      answers `{:error, :REFUSED_STOP_AUTHORITY}`; NO `ActuationIntent` row
      exists for the key; subject untouched (`:pending`).
- **Code-reading facts the courts execute against** (all witnessed by the
  passing asserts):
  - `REFUSED_STOP_AUTHORITY` is emitted by `QuiescentStop.execute/2`'s own
    admission court **before** `Xaas.Actuation.run/4` — the kernel never sees
    it, so no intent and no receipt row is minted for the refused attempt.
    (Answers the lane question: the kernel does NOT seal a refused receipt
    for it — the refusal precedes admission.)
  - The fabric path (`Lease.actuate/2` → `Xaas.Actuation.run/4`) cannot carry
    wire-supplied stop authority: authority is server-constructed
    (`ultracode_lease_actuation` map with string keys), so malformed stop
    authority is structurally unreachable over the wire.
  - `Xaas.Actuation.run/4`'s `normalize_transaction_result/1` converts a
    kernel `:refused`/`:failed` **envelope** to `{:error, error}`. Every
    kernel-level refusal reachable through the fabric is therefore
    admit-time (rollback, tool error). `format_actuation`'s `maybe_refusal/2`
    branch (which adds `refusal` to a `:refused`/`:failed` OK envelope) is
    **dead on this path**: an OK envelope only ever has status
    `:succeeded`/`:replayed`.
- **Mutation rationale** (task item 2, answered honestly): the task asked
  "which assert fails if the refusal mapping is dropped (the refusal key
  disappears)". On the current kernel contract **no assert fails** — the
  mapping is unreachable via the wire, so dropping `maybe_refusal/2` changes
  no response. That IS the finding. What the new courts DO pin: if the
  kernel's OK-envelope contract ever surfaces refused envelopes (making
  `maybe_refusal` reachable), the (g) admit-refusal asserts (tool error +
  one-intent + receipt-still-succeeded) and the (h) no-ledger-row asserts
  are the regression fence; any change to those responses kills these
  courts.
- **Commands / exits** (real tails, `MIX_BUILD_ROOT=_build-laneW866`,
  `MIX_ENV=test`, pinned asdf toolchain `PATH=$HOME/.asdf/shims:$PATH`):
  ```
  mix test test/xaas_web/quiescent_fabric_tie_test.exs
  # => Result: 8 passed   (first run, W824 4 + W844 2 + W866 2)

  mix test tie ×2 + execution_fabric_deepening + quiescent_stop +
      quiescent_stop_deepening            (combined, pre-break)
  # => Result: 28 passed, 7 excluded

  mix test tie (run 2)  # => Result: 8 passed
  mix test boundary (execution_fabric_deepening_test.exs +
                     quiescent_stop_test.exs +
                     quiescent_stop_deepening_test.exs)
  # => Result: 20 passed, 7 excluded  (identical to W844's receipt — the 7
  #    excluded are W704's @moduletag :eu_ai_act, pre-existing, not a
  #    regression)
  # tie green ×2 confirmed: 8/8 twice in separate invocations after the
  # shared-tree blocker cleared.
  ```
- **Transport failures during the lane** (both transient, shared-tree,
  neither caused by this diff):
  1. `lib/xaas/library/checkout.ex` (another lane's in-flight generated
     change: unbound `status` / missing `require Ash.Query` in
     `change_0_generated_...`) broke whole-tree compilation for ~10 min;
     healed by the owning lane; tie re-ran green after.
  2. One mix boot refusal `required project boot input VERSION unreadable:
     :enoent` (concurrent mix race in the shared checkout); retried once,
     green. No unchanged-failure re-run: each retry followed a distinct
     transport diagnosis.
- **Typed notes / disclosures**:
  - The `refusal` wire key remains UNKNOWN-to-reachable-only-if the kernel
    OK-envelope contract changes; W844's phrase "wired but never courted"
    is refined to "wired but currently unreachable through the admitted
    fabric path" (code-read + executed courts above). No kernel change was
    made (lane contract), so the dead branch stands as written.
  - `intent_count/0` and `fabric_halt/4`'s unused-param warning are
    pre-existing (W844 disclosed the former; not touched).
  - Lane build root `_build-laneW866`: deletion `rm -rf` was denied by the
    session permission layer; directory LEFT IN PLACE for the coordinator
    per the lane contract's fallback.
- **Replay**: from `a0723bf6` + the tie-file diff, the three mix test
  invocations above under the pinned toolchain reproduce the receipts.
  Court of record: `test/xaas_web/quiescent_fabric_tie_test.exs` (g)+(h).
