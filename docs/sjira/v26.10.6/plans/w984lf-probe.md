# W984lf — Closure-receipt truthing probe (v26.10.7)

- Lane: W984lf, 2026-10-08. Docs-only: regenerated
  `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` to current truth. No commit,
  no build root, no lib/test edits.
- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `52ce8236`.

## Per-section verification (real greps/git at write time)

| claim in receipt | command / read | result |
|---|---|---|
| Census 1394/0/1 @ b6fad269 | `sed -n 1,40p docs/sjira/v26.10.7/plans/w984ko-census-witness.md` | "Result: 1394 passed, 1 excluded", "[exited with code 0]", HEAD SHA `b6fad269e9b9...` verbatim in receipt |
| Wave receipt exists | `ls docs/sjira/v26.10.7/plans/ | grep w984km` | `w984km-wave-receipt.md` present; head read: 178 lane receipts, 144 with green runs, 2334 cited passes, batches #1–#10 table |
| Burn-down exists | read `w984kw-burndown.md` §1–2 | register tally **47/0/2/2 across 51 rows** (w859, W984kh addendum, awk re-derived); coverage curve incl. 747/812 = 92.0% (W984it addendum) |
| Register 47/0/2/2 fully applied | `grep w984kh-w729.md` + burndown table | W729 flip row: "47 / 0 / 2 / 2" citing court `atomic_retrofit_court_test.exs` 3 passed exit 0; "fully applied" wording in receipt line 59 |
| Coverage 65 / 92.0% | `grep -n '1394\|65 uncovered\|92.0' docs/sjira/v26.10.6/plans/w984it-recensus.md` | "Uncovered 93 → 65 (−28)"; "92.0% covered, up from 88.5%"; table row 831/747/65/19 |
| Audit-zero COMMITTED | `git show --stat 4a308950` | commit `4a308950` "W984gv release_audit ref_resolves?/1 glob-class widening + audit-zero repair (W984kc)"; landing receipt commit `7d9968d0` in `git log` |
| Manifest staged + batch #11 | `sed -n 1,20p docs/sjira/v26.10.6/plans/w984iz-manifest.md` (63 commits, range 5e03acf5..3961c4ab, 70/12/121 path counts) + `git log` | batch #11 = `9a00385c`/`caf91669`/`86c69061`, lane receipt commit `52ce8236` (HEAD) |
| Blocker 1 (merge) | `git merge-base --is-ancestor 56325fa5 origin/main; echo $?` | exit **1** — seal NOT reachable from origin/main; HEAD `52ce8236` |
| Blocker 2 (ash_pplan) | `git -C ~/ash_pplan log --oneline -1` | `847f487 fix(release): align version companions with 26.10.7 bump (W650j)` — unchanged, operator item open |
| Items 2/3/13/14 closures | register rows re-read; `e49d7033`, `2f2748b3`, `a5f81439`, `8a5f7ea7` cited from prior receipts (W984ge/W984gr/W650h23) | all closed rows retained with their original evidence pointers |

## Falsifier

Any row above re-run at a later subject returning a different result (e.g.
merge lands → item 11 ancestor check exits 0) supersedes this probe; the
receipt's DRAFT scope is defined as exactly items 11 + 12 as of this probe's
git read.
