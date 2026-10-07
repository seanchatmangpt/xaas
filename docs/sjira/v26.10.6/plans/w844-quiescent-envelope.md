# W844 — Quiescent envelope surfacing on the MCP actuate verb receipt

- **Lane**: W844, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD `a0723bf6` (no commit — coordinator
  owns transitions).
- **Standing**: ALIVE (fabric surface). W824's typed gap — "the module's
  quiescent envelope (`REFUSED_STOP_*` / `target: :quiescent`) never surfaces
  on MCP; the wire response is the generic actuate result" — is now false:
  the halt response carries the module's typed envelope additively.
- **Diff** (hand-written, 2 files; no kernel change, no new verb):
  - `lib/xaas_web/controllers/execution_fabric_controller.ex`:
    `dispatch_tool("actuate", ...)` now formats with
    `quiescent?: quiescent_intent?(args)`; `quiescent_intent?/1` matches the
    exact QuiescentStop halt shape (`action: "actuate_status"` +
    `input.status == "suspended"` — the module's `@quiescent_status`). For a
    quiescent intent, `format_actuation/2` adds additive fields:
    `target: "quiescent"` always, `already_stopped: (status == :replayed)`
    (the wire analog of the module contract's
    `{:ok, %{already_stopped: true}}` idempotent no-op), and `refusal:` (a
    string code from `envelope.error`) when the kernel returns
    `:refused`/`:failed`. Non-quiescent actuations keep the exact generic
    shape (no field leak, courted).
  - `test/xaas_web/quiescent_fabric_tie_test.exs`: extended W824's file with
    two courts (6 total in the file now):
    - **(e) regression court** — first halt: `status == "succeeded"`,
      `target == "quiescent"`, `already_stopped == false`, generic fields
      still present; same-key replay: `status == "replayed"`,
      `already_stopped == true`.
    - **(f) no-leak court** — a `"status" => "active"` actuation answers the
      generic envelope with NO `target`/`already_stopped`/`refusal` keys
      (the additive-only contract).
- **Mutation rationale (executed, not asserted)**: with the surfacing
  reverted (`quiescent?: false` hardcoded), the (e) court fails at
  `assert halt["target"] == "quiescent"` with `left: nil, right: "quiescent"`
  → `Result: 5/6 passed`. Restored and re-ran: 6/6 green. The failing assert
  on revert is the (e) `target` line; the (f) court additionally guards the
  additive-only direction (a leak would fail it).
- **Before/after wire shape** (halt, first run):
  - before: `%{"status" => "succeeded", "replay" => false, "intent_id" => …,
    "receipt_id" => …, "result" => …}`
  - after: same fields + `"target" => "quiescent"`,
    `"already_stopped" => false` (true on same-key replay); `"refusal"` only
    when the kernel refused/failed.
- **Commands / exits** (real tails, `MIX_BUILD_ROOT=_build-laneW844`,
  `MIX_ENV=test`, pinned asdf toolchain):
  ```
  mix test test/xaas_web/quiescent_fabric_tie_test.exs
  # => Finished in 1.0 seconds (0.00s async, 1.0s sync)
  # => Result: 6 passed            (W824's 4 + W844's 2)

  mix test test/xaas_web/execution_fabric_deepening_test.exs \
        test/xaas/actuation/quiescent_stop_test.exs \
        test/xaas/actuation/quiescent_stop_deepening_test.exs
  # => Result: 20 passed, 7 excluded
  #    (the 7 excluded are W704's @moduletag :eu_ai_act, default-excluded by
  #     config — pre-existing, matches W824's receipt exactly, not a W844
  #     regression)

  # post-mutation-restore combined rerun:
  mix test test/xaas_web/quiescent_fabric_tie_test.exs \
        test/xaas_web/execution_fabric_deepening_test.exs
  # => Result: 21 passed
  ```
- **Typed notes / disclosures**:
  - The `refusal` mapping path is wired but not yet courted end-to-end: the
    fabric halt path (Lease-registered pair → kernel) has no observed
    `:refused`/`:failed` envelope in these courts (W824's (c) refusals all
    fail BEFORE the kernel, surfacing as `WORK_NOT_FOUND`/`UNAUTHORIZED`
    tool errors). The mapping is exercised by `maybe_refusal/2` only when
    the kernel itself refuses a quiescent intent — honest UNKNOWN, not
    claimed ALIVE.
  - W824's fresh-key-on-quiescent-subject refusal
    (`:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`) remains a module-layer
    refusal (its court asserts it directly); through the fabric, a fresh key
    on the quiescent subject is admitted by the kernel (a second suspended
    DO) — that monotonicity enforcement is the module surface's job and was
    NOT changed here (no kernel change per lane contract).
  - `intent_count/0` in the tie test is a pre-existing unused-function
    warning (present before W844's diff; not touched).
  - Lane build root `_build-laneW844` deleted after final green run.
- **Replay**: from `a0723bf6` + this diff, the three mix test commands above
  under the pinned toolchain reproduce the receipts; court of record is
  `test/xaas_web/quiescent_fabric_tie_test.exs` (e)+(f).
