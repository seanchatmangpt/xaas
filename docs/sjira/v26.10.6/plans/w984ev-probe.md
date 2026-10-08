# W984ev — corpus evidenced-line deepening wave 9 (4 lines, 4 courts)

Lane W984ev · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Build root `_build-laneW984ev` — cold compile, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims`), `MIX_ENV=test`.

## Gap-inventory provenance

W984ec's receipt (`w984ec-probe.md`) names 11.1/12.1/12.2.a–c as
court-free evidenced lines in the audit-chain range; W984ec took the
dataset-purpose lines instead. The live `deepening_map`
(`test/eu_ai_act/title_iii_test.exs:546-551`) was re-read on disk:
11.1, 12.1, 12.2, 12.2.a, 12.2.b, 12.2.c all cite
`lib/xaas/witness/audit_chain.ex` (W503). Prior audit-chain coverage
excluded as duplication: `deepen_kind(:audit_chain)` (append N/verify/
tamper-at-2), `test/xaas/witness/audit_chain_test.exs` (link-law
mechanics, sig modes, martingale), Art 99 lane (refusal envelope,
invalid attrs). The statutory legs courted here were bound to the
statute nowhere: documentation REPLAYABILITY (11.1/12.1), exact
mid-chain tamper attribution by field class + intact-prefix survival
(12.2.a), post-market monitoring through the REAL OCEL court (12.2.b),
operation monitoring receipts over actuation ids (12.2.c).

## Courts — `test/eu_ai_act/art11_1_art12x_audit_chain_deepening_test.exs`

| line | article requirement | court |
|---|---|---|
| 11.1 + 12.1 | automatic recording; logs/technical documentation kept "up-to-date" = replayable | chain head is a deterministic, byte-replayable function of the recorded events (replay of the same sequence reproduces the identical head; recorded chain re-verifies against recorded head+length), and the head is independently recomputed in-test as SHA256(JCS(R_last) <> H_{t-1}) — real crypto, not an opaque returned value |
| 12.2.a | risk-situation traceability via the digest chain | tamper of the risk-situation payload digest at index 2, of sig_slot at index 3, and of the recorded position t at index 1 are each attributed at their EXACT index mid-chain with no head anchor; the intact PREFIX before the break still verifies :ok; the tampered chain also fails under the recorded head |
| 12.2.b | post-market monitoring traceability via the event log | real OCEL 2.0 ndjson file (3 monitoring events bound to one deployed-system object) in a real per-test sandbox; `Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` runs the real `Xaas.Ultracode.Ocel.Validator` court over it → status "valid", event/object counts and types asserted; every event's relationships bind the deployed object; a corrupt line fails closed with typed violation at exactly "line 2" |
| 12.2.c | operation monitoring via audit receipts over actuation ids | receipts keyed by the operation ids, in operation order; replay reproduces the head; reversing the SAME operation sequence changes the head (order-sensitive attestation); dropping the last operation fails with `{:truncated, 4}` under recorded head+length |

Mutation rationale (shared): a chain whose hash ignored any recorded
field, a non-deterministic hash, a successor-consistency gap, an OCEL
assembly that launders corrupt lines, or an order-insensitive
attestation each fails its leg while `deepen_kind(:audit_chain)` and
`audit_chain_test.exs` still pass.

## Verification (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ev \
  mix test test/eu_ai_act/art11_1_art12x_audit_chain_deepening_test.exs --include eu_ai_act
```

- Run 1: `Result: 3/4 passed` — court 1's independent head recompute used
  `Enum.at(chain, 4).prev_hash` (H_3) where the link law needs the last
  receipt's OWN stored `prev_hash` (H_4).
- Run 2 (post-repair): `Result: 4 passed` — exit 0.

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ev \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Census run 1 (cold build): exit 1 — **no tests ran**; the cold compile
  aborted with `== Type checking failed with errors ==` (1099 type
  warnings escalated, spread over many pre-existing test files incl.
  title_vi_xiii/title_iii/title_iv_v and lane files). Pre-existing
  campaign-tree condition, not introduced by this lane.
- Census run 2 (incremental, tests ran): `1387/1388 passed, 1 excluded,
  1 failed` — the one failure was `art15x_robustness_deepening_test.exs`
  (NOT this lane's file): its owner lane (W984fa, per the file's own
  comment) edited the file MID-RUN (mtime ~3 min before the check); the
  failure matched the older single-receipt unanchored-tamper snapshot,
  which trips the documented last-link limitation. Current on-disk
  content (two-receipt anchored tamper) is correct.
- Census run 3: `Result: 1388 passed, 1 excluded` — exit 0.
  (1388 ≥ the dispatch's 1355 floor; +4 over W984ec's 1355 = this lane's
  four courts plus other lanes' concurrent landings. Census is a shared
  moving surface; counts are as-of these runs.)

## Mock gate

`grep -nE "Mock|patch\(|\.expect\("` over the new file → zero hits
(exit 1). Chicago: real `Xaas.Witness.AuditChain` hash-chain
executions, real `Xaas.Telemetry.OcelNdjson` + real
`Xaas.Ultracode.Ocel.Validator` court over a real ndjson file in a real
sandbox dir; assertions on final returned state; zero mocks, zero
application env.

## Tagging convention

`@moduletag :eu_ai_act` only; no `eu_ai_act_open_gap` tags — no line
flipped; this lane deepens already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  4/4 standalone + census 1388/1388 (exit 0), real commands + real
  exits.
- Remaining-range update: the audit-chain range 11.1/12.1/12.2/12.2.a-c
  is now courted. Remaining court-free evidenced lines (per W984ec's
  list, unchanged elsewhere): 9.1/9.2.a-d/9.5/9.5.s3/9.8 (ferroplan
  reachability), 13.1/13.3.b.ii/13.3.b.iv/13.3.f (counterfactual),
  14.1/14.2/14.3.a-b (quiescent/oversight), 15.1/15.4 (margin-gate),
  15.5/15.5.s2 (wasi-gate), 26.12, 10.2.f/g partially (purpose leg),
  plus Title VI-XIII lines. Rough order: 20-30 lines remain court-free.
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
- Build root: `rm -rf _build-laneW984ev` attempted at lane close —
  **DENIED** by the session permission system (rm refused; the 426 MB
  build root remains on disk at `/Users/sac/xaas/_build-laneW984ev`).
  Coordinator should delete it at integration per the fanout cleanup
  law.
