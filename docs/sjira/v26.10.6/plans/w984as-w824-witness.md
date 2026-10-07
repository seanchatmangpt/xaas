# W984as — W824 witness receipt (corroborating, flip superseded)

- **Lane**: W984as, xaas v26.10.6 campaign, canonical checkout `/Users/sac/xaas`,
  branch `feat/playwright-surface`, HEAD at witness time `5f7f70d9` (working
  tree, uncommitted lane state).
- **Task**: witness W824 (wire-layer coupling: QuiescentStop typed envelope on
  the MCP wire) per W982g's SPEC-32 ALREADY-LANDED disclosure, and flip the
  register row if warranted.
- **Adjudication**: **FLIP SUPERSEDED — row already REPAIRED.** W984w landed the
  identical OPEN→REPAIRED flip concurrently (register lines 55 + 89-91,
  `w984w-witness-w824.md`, citing the same SPEC-32/w982g basis: `format_actuation/2`
  additive quiescent envelope at `lib/xaas_web/controllers/execution_fabric_controller.ex:742-766`,
  commit `9f1247c1`, court `test/xaas_web/quiescent_fabric_tie_test.exs`, ×3
  green on fresh `_build-laneW984w`). This lane therefore made **no register
  edit** — re-flipping a REPAIRED row would duplicate, not advance. What this
  lane adds is an independent witnessed run.

## Independent witness run

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984as mix test test/xaas_web/quiescent_fabric_tie_test.exs`
- Environment: pinned asdf toolchain, `MIX_ENV=test`, **fresh** build root
  `_build-laneW984as` (compiled from scratch, ~330 MB, no shared `_build`).
- Real output:

```
........
Finished in 2.9 seconds (0.00s async, 2.9s sync)

Result: 9 passed
```

- Exit code 0. Runtime 2.9s sync after the fresh-root compile.

## Coverage vs the W824 row demand

The row demanded: the QuiescentStop typed envelope surfaces on the MCP wire,
not just the kernel's raw actuate envelope. The court
(`test/xaas_web/quiescent_fabric_tie_test.exs`, landed in `9f1247c1`, 539 lines)
fences the envelope directly:

- (e) block (lines 314-338): halt response asserts `halt["target"] == "quiescent"`
  and `halt["already_stopped"] == false`, additive to the generic fields
  (`intent_id`/`receipt_id`); replay asserts `"replayed"` + `already_stopped == true`.
- Non-halt actuation asserts the envelope does NOT leak (`refute Map.has_key?(…, "target")`).
- Typed kernel refusals surface as tool errors (`idempotency_conflict`,
  `idempotency_key_required`, `WORK_NOT_FOUND`/`no_lease`, `UNAUTHORIZED`/`capability_required`).
- Module↔fabric cross-check: after a fabric halt, `QuiescentStop.execute/2`
  with a fresh key answers `{:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT}`.
- W970 dead-branch fence (`maybe_refusal/2` deletion) and byte-identical
  refusal determinism also courted.

Coverage is genuine: the row's demand (typed quiescent envelope on the wire)
is asserted against real HTTP bodies via ConnCase behind the real bearer gate.
No missing hop.

## Standing

- W824 row: **REPAIRED** (standing per W984w's flip; corroborated ALIVE by this
  lane's independent fresh-root run, 9/9 exit 0).
- This lane's own standing: witness-only, no register edit, no code change.
- Cleanup: `_build-laneW984as` left for the coordinator — the lane's
  `rm -rf` of the build root was refused by the permission system; per lane
  brief ("delete when done, else leave for coordinator") the lease passes to
  the coordinator for deletion (~330 MB, disposable).

## Falsifier for this receipt

Run the court on any descendant head; if it goes red or the `target`/
`already_stopped` fields disappear from the wire envelope, the flip and this
corroboration are void.
