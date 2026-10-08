# W984kr — Unclaimed-Family Probe: Xaas.Test.VKGObservationEngine Helper Court

- Lane: W984kr on `/Users/sac/xaas` @ branch `feat/playwright-surface` (no commit, per lane contract)
- Subject: `test/support/vkg_observation_engine.ex` (`Xaas.Test.VKGObservationEngine`, single `execute/2`)
- Consumers: 6 files (workspace, replay, integration, family_court_w984hn, vkg_refusal_negative, castle_alive) — all invoke indirectly via `VKG.observe`/`observe_all`, never asserting the helper's own output contract

## Census and dispositions

| Helper branch | Prior coverage | Disposition |
|---|---|---|
| Synthesized fallback row (`Map.get_lazy` else-branch, `String.capitalize`, subject prefix) | Exercised (replay/refusal/family_court call without `rows_by_contract`) but never asserted on content | COURTED — shape + capitalization + prefix asserted (`vkg_engine_helper_court_w984kr_test.exs` t1) |
| Explicit `rows_by_contract` passthrough | Exercised (workspace/integration/castle) but rows passthrough never asserted | COURTED — verbatim passthrough + `row_count`/`output_bytes` (t2) |
| Digest determinism (`:deterministic` term_to_binary) | Only indirect via `Replay.witness` identity | COURTED — same-input repeat gives identical digests (t3) |
| Digest preimage sensitivity (4 tuple components) | Never courted | COURTED — per-component mutation must move `observation_sha256` (t4) |
| Field invariants (command==observation==output digest, hex-64, standing/status/session nil, stage sha passthrough) | Never courted | COURTED (t5) |
| Bad input (non-binary `contract_id`) | Never courted; helper has no typed refusal path | COURTED — real behavior is `ArgumentError` from binary construction; asserting no silent coercion (t6) |

No fully-covered branches remained after the content-level census: every branch is either content-unasserted or input-unmutated, so no `COVERED` filler tests were needed.

## Verification (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984kr mix test test/xaas/semantics/vkg_engine_helper_court_w984kr_test.exs` → `6 passed`, exit 0 (one initial failure — expected `FunctionClauseError`, actual `ArgumentError` — repaired by asserting the real exception, not by touching the helper).
- No `:eu_ai_act` tag: all 6 consumers are plain ExUnit (e.g. `test/xaas/semantics/vkg/replay_test.exs` has no suite tag), so the court is plain `ExUnit.Case, async: true`. `--include eu_ai_act` not applicable.
- Mock gate scoped to the new file → `[]`.
- Zero mocks; the helper is the real collaborator under test (Chicago).

## Files

- Added: `test/xaas/semantics/vkg_engine_helper_court_w984kr_test.exs` (6 tests)
- Added: this receipt
- No lib/ changes; no commit made.

## Standing

ALIVE — all 6 courts executed and passed on the exact working-tree subject.
