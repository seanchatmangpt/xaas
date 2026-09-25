# P3 Unattended Epoch with ZCode — Oban cron alone advances a Run end-to-end

## Summary

DESIGN.md phase P3 falsifier: one full Epoch completed with zcode as the
executor, advanced by the Oban `* * * * *` tick ALONE — zero manual
`Reactor.run` calls, zero hand-bridged state transitions. Everything proven
so far is either DAG correctness under test sandboxes or (post-P2) a
hand-driven provider cycle; P3 removes the hands.

## Status

BLOCKED — on `p2-lease-cycle-redispatch.md` (P2 first: same seam, hands-on).

## Scope

1. After P2, admit a fresh Run (same admission path, real subject,
   `epoch_timeout_seconds: 3600`).
2. Executor presence, not executor hands: the provider worker (zcode session
   with the installed plugin, or an equivalent dispatch through the lease
   seam) claims/heartbeats/closes — but NO ONE touches Run/Epoch state
   directly and no `Reactor.run` is invoked outside the Oban tick.
3. Watch unattended: per-minute tick correlation in the server log;
   epoch `:expected → :running → :completed`; NextEpoch or Run completion at
   `max_cycles`; receipts sealed by the loop itself.
4. Independent observer protocol (same as ep1-observer: read-only DB/log,
   verdicts, no interference).
5. Falsifier: epoch completes + receipts land with the observer confirming
   zero manual transitions (log shows no out-of-tick state machinery).

## Key Invariant(s)

- If the provider dies, the epoch must reap to `:missed` by timeout with a
   sealed receipt — failure is observed, never patched around.
- The admission (Run :create/:start) is the only hand-touch allowed in the
   whole cycle.

## Relationship to Existing Work

- `DESIGN.md` P3; `wave1-01-domain.md` (tick chain proven in tests);
  `PROGRESS.md` (unattended Run→completed already proven WITHOUT a provider —
  P3 adds the provider leg); the plugin installed by
  `zcode-connection-P0P1.md`.

## Falsifiers / What Would Defeat This

- Any state transition with no corresponding tick in the log window.
- Provider completion requiring manual epoch advancement (hands leaked back
  in).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | xaas @ 6ff1a32 + plugin 26.8.21 | unattended no-provider completion proven twice (PROGRESS.md); provider leg unproven | P2 → fresh Run → hands-off cycle + observer |
