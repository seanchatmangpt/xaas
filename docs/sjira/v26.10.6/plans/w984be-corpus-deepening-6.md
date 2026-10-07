# W984be — Corpus evidenced-line deepening wave 6 (2 lines, 6 courts)

Lane W984be · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Build root `_build-laneW984be` — cold compile, pinned asdf toolchain
1.20.2-otp-28, `MIX_ENV=test`. **Build root deleted by the lane at
integration** (`rm -rf _build-laneW984be` succeeded — unlike W981t/W982z/
W984p, no fallback needed).

## First step: W984al check

W984al's receipt (`w984al-corpus-deepening-5.md`) did not exist at lane
start → treated as still running, per dispatch. Its two disclosed-failing
files (`art_9_4_zero_config_env_invariance_test.exs`,
`art_133e_live_toolchain_pin_test.exs`) were NOT touched. By lane end,
BOTH the receipt and both files had landed green: the final census ×2
(seeds 469313, plus the run-A seed) shows the whole deepening dir at
**36/36 passed ×2, exit 0**, including those two files. No fix leg needed
from this lane.

## Gap-inventory provenance

Receipts w981t / w982z / w984a / w984p were read; their taken lines
excluded (27.3, 26.6, 14.4.b, 15.5.s3, 26.7, 27.1.c+d, 10.2.h, 10.3,
26.1, 26.9/art13, 9.4, 13.3e, and W704's 27.3). The live
`deepening_map` + `evidence_map` (`test/eu_ai_act/title_iii_test.exs`)
were re-read on disk; the two lines courted here are already **EVIDENCED**
with `deepening_map` entries (`26.5 => [:audit_chain]`,
`26.2 => [:quiescent_typed]`) but had no dedicated deepening court file.
No overlap with any prior wave: 26.5's OCEL-egress composition and 26.2's
oversight-assignment/sig-verification composition are new. W984al's
receipt (landed mid-run) independently lists 26.2/26.5 as "taken (lanes
W984be/W984p-family)" — consistent, no conflict.

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 26.5 | deployer shall ensure operation monitoring via the log | REAL monitoring pipeline: real `Xaas.Actuation.run/4` DO receipts become real OCEL 2.0 egress lines on disk (the emitter's exact per-line document law), admitted by the real `Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` court; the real `Xaas.Witness.AuditChain` over digests read back off disk verifies against its real head — and detects a real byte tamper of the file, naming the head mismatch | `test/xaas/deepening/art_26_5_operation_monitoring_egress_test.exs` (3 courts) | if the egress stops being individually conformant (a line drops a required OCEL 2.0 key or a relationship dangles), or `read_document/1` stops returning events in append order with attributes intact, or the chain head stops binding the on-disk content, the conformance/order/tamper courts fail while `audit_chain_test.exs`'s synthetic courts and the emitter's own shape tests still pass |
| 26.2 | deployer shall assign human oversight to competent persons | oversight ASSIGNMENT over the real kernel: a NAMED human authority (kind+source) drives a real stop DO; the assignment is echoed exactly in the stop receipt, durable as a real `ActuationIntent` row; an unassigned (source-less / non-map) authority is refused typed `:REFUSED_STOP_AUTHORITY` before any DO with no durable row and an untouched subject; the receipt becomes a sig-verified chain witness whose sig callback admits ONLY the assigned authority — a reassigned identity is rejected `:invalid_signature` |
`test/xaas/deepening/art_26_2_human_oversight_assignment_test.exs`
(3 courts) | if the stop surface stops echoing the authority into its receipt, the fail-closed gate stops refusing a source-less authority, or the chain's signature court stops rejecting a reassigned oversight identity, these courts fail while `quiescent_stop_test.exs`'s typed contracts and `audit_chain_test.exs`'s unsigned synthetic courts still pass |

## Verification (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984be \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run 1 (two lane files only, seed 338819): `Result: 6 passed`, exit 0.
- Run 2 (two lane files only, post-tightening): `Result: 6 passed`, exit 0.
- Census run A (whole dir, 12 files, 36 courts): `Result: 36 passed`, exit 0.
- Census run B (whole dir, different seed): `Result: 36 passed`, exit 0.
- Mock gate: grep of both new files → zero `Mock`/`patch(`/`.expect(`
  hits. Chicago: real Ash actions over real sandboxed Postgres, real
  actuation DOs, a real tmp-dir file with real byte tamper, the real
  hash chain with a real sig callback — no mocks.

## Sibling-lane crossing (disclosed both directions)

W984al applied a compile-freeze SLA fix to this lane's in-flight
`art_26_5_..._test.exs` mid-run: a real bug (this lane's `[first, rest] =
Enum.split(lines, 1)` pattern — `Enum.split/2` returns a tuple) plus a
semantics fix (rebuilt-from-tampered chains are self-consistent, so
tamper evidence must ride `expected_head`). W984al's census runs
witnessed the pre-fix 1/3 failure; this lane's post-fix runs are green.
W984be then tightened W984al's fix: `original_head` is now the REAL head
captured from the final `AuditChain.append/2` (their version recomputed a
lookalike from the second-to-last link's `prev_hash`), and the clean
chain is asserted against it before the tamper. Disclosed in-code in the
file comments.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  6/6 twice + census 36/36 ×2 (different ExUnit seeds), real commands +
  real exits.
- W984al's wave-5 files: **ALIVE** (green in both final census runs).
- `_build-laneW984be`: **deleted by the lane** (per the fanout cleanup
  law; no coordinator fallback needed this wave).
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
