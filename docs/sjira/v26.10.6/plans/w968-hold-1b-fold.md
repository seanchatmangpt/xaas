# W968 — Hold 1b fold into W955 push-gate spec

Lane W968, xaas v26.10.6 campaign. Subject: `/Users/sac/xaas` working tree at fab56ae1
(branch `feat/playwright-surface`). Docs-only change; no commit made, no build root created.

## Task

Update W955's push-gate spec §1b hold: w963-fleet-pin-remaining6 landed 6/6 GREEN,
completing w958's 5/5 — fleet pin matrix 11/11 GREEN at exact W937 SHAs. Rewrite §1b from
UNKNOWN/pending-w939 to LANDED with the two receipt citations and the 5+6 split; remove 1b
from §5 active holds.

## Pre-check (O)

- `docs/sjira/v26.10.6/plans/w955-push-gate-spec.md` — §1b row (line 26): receipts
  `w939 (in flight)`, status `UNKNOWN — receipt not on disk`. §5 hold item 2 = 1b unmet.
- `docs/sjira/v26.10.6/plans/w963-fleet-pin-remaining6.md` — EXISTS. Spot-checked tails:
  - beam4pm (row 6): **GREEN**, `Result: 19 passed` (16.0s), SHA 560202484f5f…
  - ferroplan (row 11, xaas-side pin suite): **GREEN**, `Result: 8 passed` (0.4s), SHA e2c48d339cb0…
  - Totals: 6 GREEN / 0 RED / 0 BLOCKED; "Fleet matrix (W958 + W963): 11/11 GREEN".
- `docs/sjira/v26.10.6/plans/w958-fleet-pin-hold-verify.md` — EXISTS, 5 GREEN rows
  (ggen-marketplace, ggen, ash_surface, gymact, zcode-cli), totals "5 GREEN / 0 RED".

## Change (μ/diff)

`docs/sjira/v26.10.6/plans/w955-push-gate-spec.md` only.

1. §1b row (before):
   `| 1b | Fleet postcommit pin suites green ×11 | all 11 fleet repos' AIRo pin suites pass on the w937 commit SHAs | w939 (in flight) | UNKNOWN — receipt not on disk |`
   (after):
   `| 1b | Fleet postcommit pin suites green ×11 | all 11 fleet repos' AIRo pin suites pass on the w937 commit SHAs | w958 (5/5 GREEN: ggen-marketplace, ggen, ash_surface, gymact, zcode-cli) + w963 (6/6 GREEN: beam4pm, autofde-lab, wasm4pm, ex4pm, ash_pplan, ferroplan) | **LANDED** — fleet pin matrix 11/11 GREEN at exact W937 SHAs |`
2. §5 hold item 2 (before): active hold — "1b unmet: if any of the 11 fleet pin suites
   fails (w939), hold that repo's push; …".
   (after): struck through and marked `CLEARED (w968): w958 5/5 + w963 6/6 = 11/11 GREEN
   at exact W937 SHAs — 1b no longer an active hold.` (struck-through rather than deleted
   to preserve the hold's provenance; it is removed from the active-hold set).

## Verification

- Re-read of the edited §1 table confirms the LANDED row renders with both citations.
- Re-read of §5 confirms item 2 is struck through with the CLEARED marker; items 1, 3, 4
  untouched.
- w963 receipt existence + beam4pm/ferroplan tail spot-check: real grep output above.

## Standing

- Fleet pin matrix 11/11: **ALIVE** at exact W937 subjects (w958 + w963 receipts).
- W955 §1b hold: **CLEARED**.
- Remaining W955 holds: 1a (NOT YET — integration commit), 1c (half-held: w821 ALIVE,
  w926 UNKNOWN), 1d (OPEN — coordinator adjudication).

## Commands / replay

```
grep -n "1b" docs/sjira/v26.10.6/plans/w955-push-gate-spec.md
sed -n '6,32p' docs/sjira/v26.10.6/plans/w963-fleet-pin-remaining6.md
```

All exits 0. Falsifier for this lane: a §1b row still reading UNKNOWN/w939-in-flight, or
§5 item 2 still listed as an unstruck active hold.
