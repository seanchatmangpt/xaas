# W650v3 Receipt — Refusal Ledger Digest-Framing Fix (v26.10.7 fleet seal)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD `52764939` at lane
  start), lane W650v3, dispatch from W650v2 finding #2. No commit made (per lane
  contract); coordinator owns integration.
- **Standing**: ALIVE for the digest-framing fix on the exact subject — emit
  determinism byte-identical ×2, `shasum -a 256` of the on-disk file equals the
  printed/`emit()` digest, updated court green, ×2 fresh build roots.
- **Ownership disclosure (W616 honor)**: `RefusalLedgerExport.emit/0` and
  `rebuild_digest/0` were authored by W616's owner. This lane applied the
  cosmetic-non-blocking digest-framing fix disclosed by W650v2 finding #2; the
  artifact BODY is unchanged (byte-identical across every run below).

## Digest rotation (disclosed)

| digest (sha256) | framing |
|---|---|
| `203fee7cd4ec9d7c68d4621469cac248c774a8c102ce6a1cc169f3132bea8f59` | BEFORE — sha256 of the canonical JCS body, excluding the trailing `\n` (what the emitter printed; not the on-disk file's digest). |
| `6d1e4b89fa90c7489f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7` | AFTER — sha256 of the exact written bytes (body + `\n`); equals `shasum -a 256` on disk; matches W984cw4's on-disk convention (`docs/sjira/v26.10.6/plans/w984cw4-ops-probe.md:95`). |

The ledger artifact content is unchanged: every emit in this lane reproduced the
committed bytes byte-identically (`cmp` clean against the pre-run snapshot).

## Diff

1. `lib/xaas/operations/refusal_ledger_export.ex`
   - `emit/0`: hash `canonical_json <> "\n"` (what is actually written) instead
     of the bare canonical body. One line + comment.
   - `rebuild_digest/0`: hash the exact on-disk bytes (after a
     `Jason.decode!/1` shape check so a malformed artifact still fails) instead
     of re-canonicalizing — required so the digest-replay leg compares like
     framing against emit. Docstring updated.
   - Moduledoc + `court/0` leg-2 docstring updated to state the on-disk framing
     and the W650v3 rotation.
2. `lib/mix/tasks/xaas.export_refusal_ledger.ex` — **no change needed**: the
   task prints `emit()`'s digest, so the fix propagates. Verified: task output
   now prints `6d1e4b89…` and `replay: MATCH`.

## Court update

`grep -rn 203fee7c test/` → **zero hits**: no test pins the old digest. The
digest court is `test/xaas/operations/refusal_ledger_export_depth_test.exs`,
which compares `emit()` vs `rebuild_digest()` dynamically (no literal pin), so
it passes unchanged under the rotated framing. Both functions moved to the
on-disk framing together, so the court's replay/tamper/determinism legs remain
exactly the same assertions.

## Gates (real output)

Fresh root #1 (`MIX_BUILD_ROOT=_build-laneW650v3`, then reused for both runs):

- `mix compile` EXIT=0 (pre-existing warnings only; one new benign
  ``not is_binary(court)`` type warning in `assert_all_pinned/1` — dialect
  narrowing on pre-existing code, not introduced logic).
- Run 1: `mix xaas.export_refusal_ledger` EXIT=0 →
  `sha256: 6d1e4b89…34ea7`, `replay: MATCH`; `shasum -a 256` on disk =
  `6d1e4b89…34ea7` (printed == on-disk, gate holds); body vs pre-run snapshot
  IDENTICAL.
- Run 2: `mix xaas.export_refusal_ledger --court` EXIT=0 → same digest,
  replay MATCH, `court: OK (fake-variant mutation refused:
  %{atom: "REFUSED_FAKE_W616_NO_COURT", reason: :court_missing, …})`;
  body IDENTICAL again (emit determinism byte-identical ×2).
- `mix test test/xaas/operations/refusal_ledger_export_depth_test.exs` →
  `5 passed`.

Fresh root #2 (`MIX_BUILD_ROOT=_build-laneW650v3b`):

- `mix compile` EXIT=0; `mix xaas.export_refusal_ledger --court` EXIT=0 →
  `sha256: 6d1e4b89…34ea7`, replay MATCH, `court: OK (fake-variant mutation
  refused: %{atom: "REFUSED_FAKE_W616_NO_COURT", reason: :court_missing, …})`;
  `shasum -a 256` on disk = `6d1e4b89…34ea7`; body vs pre-run snapshot
  IDENTICAL.
- `mix test test/xaas/operations/refusal_ledger_export_depth_test.exs` →
  `Result: 5 passed`.

## Build-root lease note

`_build-laneW650v3` (~426 MB) and `_build-laneW650v3b` (~424 MB) were left on
disk — the lane's `rm -rf` cleanup command was denied by the permission system.
Coordinator: delete both at integration per the fanout cleanup law.
