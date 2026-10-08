# W984lg — evidence-claims-index refresh probe receipt

- Lane W984lg, 2026-10-08, canonical checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface` (never switched; docs-only; no commit; no
  build root created).
- Subject: refresh `docs/cro/artifacts/evidence-claims-index.md` from
  `43265cb1` (W984fp's last row) to HEAD `52ce8236` — batches #9–#11
  plus the kb/kc landing receipts. Rows 77–92 appended; no prior row
  rewritten.

## Commit enumeration (real output)

`git log --oneline 43265cb1..HEAD` → 16 commits (landing order, newest
first):

```
52ce8236 86c69061 caf91669 9a00385c 7d9968d0 4a308950 b6fad269 f446d9c5
127dc790 79581cf6 ef2e8714 ad159c18 145b5659 663786f5 c58a8cea 6fbfb47a
```

## Per-row SHA verification (real `grep -rl <sha> docs/sjira/v26.10.{6,7}`)

| Row | SHA | Receipt citing/carrying it (test -f verified) |
|---|---|---|
| 77 | 6fbfb47a | docs/sjira/v26.10.7/plans/w984il-commit.md |
| 78 | c58a8cea | docs/sjira/v26.10.7/plans/w984il-commit.md (also w984kf-commit.md) |
| 79 | 663786f5 | docs/sjira/v26.10.7/plans/w984il-commit.md |
| 80 | 145b5659 | docs/sjira/v26.10.7/plans/w984il-commit.md (carrier; cited by w984jm-commit.md, w984kb-push.md, w984km-wave-receipt.md) |
| 81 | ad159c18 | docs/sjira/v26.10.7/plans/w984jm-commit.md |
| 82 | ef2e8714 | docs/sjira/v26.10.7/plans/w984jm-commit.md |
| 83 | 79581cf6 | docs/sjira/v26.10.7/plans/w984jm-commit.md |
| 84 | 127dc790 | docs/sjira/v26.10.7/plans/w984jm-commit.md |
| 85 | f446d9c5 | docs/sjira/v26.10.7/plans/w984jm-commit.md (carrier; push state confirmed by w984kb-push.md) |
| 86 | b6fad269 | docs/sjira/v26.10.7/plans/w984kb-push.md |
| 87 | 4a308950 | docs/sjira/v26.10.7/plans/w984kc-commit.md (full SHA `4a3089500bc35b0a…` in receipt) |
| 88 | 7d9968d0 | docs/sjira/v26.10.7/plans/w984kc-commit.md (push block appended by this commit; cited by w984kf-commit.md, w984kv/ky/lf probes) |
| 89 | 9a00385c | docs/sjira/v26.10.7/plans/w984kf-commit.md |
| 90 | caf91669 | docs/sjira/v26.10.7/plans/w984kf-commit.md |
| 91 | 86c69061 | docs/sjira/v26.10.7/plans/w984kf-commit.md |
| 92 | 52ce8236 | docs/sjira/v26.10.7/plans/w984kf-commit.md (carrier — `git show --stat 52ce8236` = exactly this file, +61); independently cited as HEAD by docs/sjira/v26.10.6/plans/w984lf-probe.md |

Result: 16/16 SHAs have an on-disk receipt citing or carrying them; zero
receipt-absent commits in this range.

## Receipts read in full

w984il-commit.md, w984jm-commit.md, w984kb-push.md, w984kc-commit.md,
w984kf-commit.md. Court numbers (53/53 batch #9; 160/0 batch #10; 19
passed + audit-zero w984kc; 99 passed/0 failed/6 excluded + 6 passed
eu_ai_act re-run = 105/0 batch #11) re-read from the receipts, not
commit subjects.

## Spot checks (real outputs)

- `git show --stat 52ce8236` → 1 file changed: `w984kf-commit.md` +61
  (receipt-carrier confirmed).
- `git show --stat 7d9968d0` → 1 file changed: `w984kc-commit.md` +7
  (push block; "origin == HEAD == 4a308950 verified" per its message).
- `grep -n "52ce8236" docs/sjira/v26.10.6/plans/w984lf-probe.md` → lines
  6, 18, 19 (HEAD subject + batch #11 mapping + merge-base Blocker 1
  exit 1 against origin/main) — recorded in the index DRIFT note.
- Row 76 residue: nothing on disk newly cites `43265cb1` as a tested
  subject (grep in this range only surfaced receipt-carriers and
  later probes); its annotation stands unchanged.

## Standing

ALIVE (docs-only transition): every row's SHA receipt-verified by real
grep; every receipt's recorded court output transcribed as-is; totals
updated 76 → 92; H1 + header refresh-stamp updated. No test execution
by design (no code claims made). Falsifier: any SHA in the table
without a receipt on disk, or any court number diverging from its
receipt text.

## Cleanup

None required (no build root, no commits, no tree changes outside
`docs/cro/artifacts/evidence-claims-index.md` and this probe file).
