# W946c — Register Sweep 6 (w859 typed-gap register)

Lane W946c, 2026-10-07, xaas v26.10.6, `/Users/sac/xaas` @ `feat/playwright-surface`.
Subject: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` (the only file written).
Not committed, per lane contract. No build root.

## Method

Concurrent-edit protocol honored: read the CURRENT disk state of the register
first (114 lines, sweeps 1-5 state incl. W943b/W943c rows), kept other lanes'
versions intact, then reconciled only this sweep's deltas.

Repair-receipt checks (`ls` / `test -f` against
`docs/sjira/v26.10.6/plans/`):

- `w925-slot-release.md` — **PRESENT** (landed since W943b's sweep-4 absent
  re-check). Receipt re-read in full: real court runs, 15 passed ×2
  determinism, mock gate `[]`; `@active_statuses [:registered, :attended]`
  filter confirmed on tree at `lib/xaas/conference/registration.ex:172-189`
  (grep-verified).
- `w928-gymact-hygiene.md` — absent at sweep open AND re-checked absent at
  sweep close → W674-GAP-2 stays OPEN.
- `w945b-batch4-repairs.md` — absent at sweep open AND re-checked absent at
  final end-of-sweep check → no batch-4 flips.
- w907/w860-adjacent rows (W880 bare-fun, W836 health timeout): already
  REPAIRED since W944's append — no change.
- `w945-ocel-group-verify.md` scanned for disclosed gaps: none (composition
  evidence only).

## Flips (dual-cited)

1. **W893 GAP(CancelDoesNotReleaseSlot): OPEN → REPAIRED**
   `w893-enrollment-journey.md` (disclosure) + `w925-slot-release.md`
   (repair: active-status filter on the EnforceSessionCapacity count,
   statuses read from W795's forward-only transition set; slot-release
   regression court replaces the old-behavior pin; 15 passed ×2; mutation
   = dropping the filter reverts the count to all rows and the re-register
   raises `~r/at capacity \(1\/1 taken\)/`; mock gate `[]`).

## Appended row

- **W893 GAP(NoServerActionForCancel)** — cancel is a bare `:update`, no
  dedicated server action for the cancel transition. Disclosed in w925's
  Typed-gaps section at closure ("remains open — out of W925 scope").
  Status OPEN, disclosing/status receipt `w925-slot-release.md`.

## Merged final state (grep-verified)

49 rows = **31 OPEN + 16 REPAIRED + 2 TYPED-OPEN**
(awk field-5 count: `31 OPEN / 16 REPAIRED / 2 TYPED-OPEN`, total 49).

Sweeps history in the register footer: sweeps 1-5 (w915, w923, w943,
w943b, w943c) preserved verbatim; sweep 6 entry appended.

## Commands / exits

```
ls -la w925-slot-release.md w928-gymact-hygiene.md w945b-batch4-repairs.md
# w925 present (4579 bytes, Oct 7 06:59); other two: No such file or directory
grep -n active_statuses lib/xaas/conference/registration.ex   # 172/174/189
awk -F'|' 'NR>18 && NF>5 {print $5}' w859-typed-gap-register.md | sort | uniq -c
# 31 OPEN / 16 REPAIRED / 2 TYPED-OPEN ; total rows 49
```

## Standing

ALIVE (this lane, exact subject — register edits on disk, totals
grep-verified from the file itself). Editorial work only; no code
touched, no test runs claimed beyond w925's own receipted runs.

## Typed gaps

None new from this lane. Net register delta: −1 OPEN (flip) +1 OPEN
(new row) = OPEN count unchanged at 31; REPAIRED 15→16; total 48→49.
