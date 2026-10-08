# W650y3 — AtlassianCursor depth court (retrospective receipt)

- **Wave**: v26.10.7 fleet seal, lane W650y3 (court author, unreceipted at
  creation; receipt authored post-hoc by landing lane W650h15 per W650h14b's
  truth table, which found "no w650y3 receipt anywhere").
- **Subject**: `/Users/sac/xaas`, branch `feat/playwright-surface`.
  Court executed green at HEADs `b522fb45` (W650h14b run) and `983ca0ae`
  tree (W650h15 run below); file last present in tree before W984dp3's
  rotation replaced it.

## Artifact (retired)

`test/xaas/sjira/w650y3_atlassian_cursor_depth_court_test.exs` — 10-test
mutation-rationale court over `Xaas.Sjira.AtlassianCursor`
(`lib/xaas/sjira/atlassian_cursor.ex`): offset roundtrip threading `startAt`
exactly once per page, exhaustion typed refusal `{:error, :cursor_exhausted}`,
termination-cond precedence (total → isLast → short-page), `seen`
accumulation, token-mode roundtrip/exhaustion. Chicago-style, no mocks.

## Disposition: RETIRED (SUPERSEDED)

The court file was deleted from the tree mid-seal by the W984dp3 lane
(authored its own `test/xaas/sjira/w984dp3_atlassian_cursor_court_test.exs`,
5 tests, same module surface, receipt
`docs/sjira/v26.10.6/plans/w984dp3-sjira.md`, tracked at HEAD). Coverage
carries via W984dp3's court; w650y3's file was never committed, so no tree
mutation is required — the court's history is its receipts and run logs.

## Executed verification (real output)

- W650h14b (2026-10-07): 5-file batch 18/22 passed, w650y3 suite green
  (only failures were the RED w984dg marketplace file).
- W650h16 (bdc6d823 receipt): 4-suite batch 15/15 passed, w650y3 included
  ("pre-deletion").
- W650h15 (this lane), fresh strict compile
  `MIX_BUILD_ROOT=_build-laneW650h15 mix compile --force` EXIT=0 (warnings
  pre-existing in `lib/xaas/operations/refusal_ledger_export.ex` only), then
  batch of w650y3 + w650y4 + w984dr suites:

```
Finished in 1.2 seconds (0.8s async, 0.4s sync)
Result: 10 passed
```

## Standing

RETIRED(SUPERSEDED) — court never landed; its coverage surface is ALIVE via
`w984dp3_atlassian_cursor_court_test.exs` (tracked, receipted, green).
No open work remains on w650y3.
