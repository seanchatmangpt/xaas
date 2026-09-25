# Zombie Runs Cleanup — 7 stale :running ultracode runs before server restart

## Summary

The independent observer found 7 ultracode runs stuck in
`state=running / standing=unknown` (created 06:33–06:54Z on 2026-09-17),
their epochs reaped to `:missed` (5 of them the earlier provider=zcode
attempts killed by the 300s default epoch timeout). On the next server boot,
the Oban missed-epoch sweep meets these first — polluting fresh epoch
accounting and receipts with restart-time artifacts.

## Status

Queued / Not Started (agent work; should land with or before
`op-xaas-server-restart.md`).

## Scope

1. Read-only survey: runs/epochs/receipts state for the 7 (ids, timestamps,
   last transitions) against `xaas_dev` (SELECT only until the decision).
2. Operator-visible decision memo: abandon vs complete vs sweep-policy —
   with the typed action the domain already provides (`Run` state machine
   allows `running → completed/failed/abandoned`).
3. Implement the chosen disposition through the real admitted actions
   (`mix run -e` under the shared mix lock, `mix run --no-start` + explicit
   Repo start per the incident's operational law — never against a live
   request-serving tree).
4. Guard test: reaped-epoch runs must not be silently re-leased or
   double-swept after disposition (follow `missed_epoch_receipt_test.exs`
   patterns).
5. Receipt: ids + dispositions + before/after counts + exit codes.

## Key Invariant(s)

- No raw SQL UPDATE on ultracode tables — only admitted Ash actions.
- Disposition must itself leave receipts where the domain requires
  (missed-epoch path already seals `:blocked` receipts — keep that property).

## Relationship to Existing Work

- `ep1-observer.md` anomaly 4 (the graveyard); `ep1-driver.md` Finding C
  (300s timeout reaping — related but fixed per-run by P2's 3600s admission).
- Prerequisite hygiene for `p2-lease-cycle-redispatch.md`.

## Falsifiers / What Would Defeat This

- A "cleaned" run reappears as `:running` after restart (state lie).
- Disposition bypasses the state machine (direct DB write).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | xaas @ 6ff1a32 | survey evidence in ep1-observer.md | decision memo → disposition → guard test |
