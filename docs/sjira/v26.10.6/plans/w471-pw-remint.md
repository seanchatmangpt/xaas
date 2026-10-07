# W471 — PW suite re-mint #1 (queued per w470 admissibility classification)

## Load gate

- Pre-mint `uptime`: `18:34 up 1 day, 6:24, 3 users, load averages: 9.30 34.68 54.76`
- 1-min load 9.30 < 10 → gate OPEN on first check, no sleep loop needed.
- Load at mint: **9.30** (1-min; admissible per W461 rule <10).

## Command

```
export INTERNAL_API_TOKEN=w471-token
PATH=$HOME/.asdf/shims:$PATH PW_PORT=4103 INTERNAL_API_TOKEN=w471-token npx playwright test
```

## Real tail

```
  ✓  97 e2e/next-read-ml.spec.cjs:147:3 › Next Read Qvest Deck Experience & Dual-Persona Interface › switches between split, student-only, and librarian-only view modes (2.0s)

  2 skipped
  96 passed (33.6s)
```

## Result

**96 passed / 0 failed / 2 typed stripe skips (33.6s)** — exactly the expected w438/w449/w460 lineage target.

## Comparison

| mint | passed | failed | skipped | note |
|---|---|---|---|---|
| w317 (pre-fix baseline) | 96 | 0 | 2 | baseline at admissible load |
| w438 (pre-fix) | 94 | 2 | 2 | ash-admin pair failing pre-fix |
| w460 (post-fix, inadmissible load) | 96 | 0 | 2 | settle-wait closed ash-admin pair; receipt gated on load |
| **w471 (this mint)** | **96** | **0** | **2** | post-fix, admissible load 9.30 |

No failure to isolate; no divergence vs w460.

## Verdict

**Browser rung single-receipt CLOSED at final tree.** The post-fix full tokened PW suite is minted at admissible load, reproducing the w317 96/0/2 baseline with the ash-admin settle-wait fix in place (w460's result confirmed at admissible load).
