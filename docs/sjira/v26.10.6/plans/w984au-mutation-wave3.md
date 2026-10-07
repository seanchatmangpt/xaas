# W984au — Mutation-hardening wave 3 (non-graphql REPAIRED rows)

Lane: W984au, xaas v26.10.6 campaign, 2026-10-07. Subject: branch
`feat/playwright-surface`, working tree (uncommitted), HEAD `5f7f70d9`.
Pattern: W981p (open-gap mutation hardening). W984x's wave-2 receipt is NOT on
disk (checked) — no overlap check possible against it; the three rows below are
the task-named non-graphql candidates. No court files edited; no register rows
edited (in-lane scope = receipt only).

Method: per-row minimal production mutation via /tmp file-swap (snapshots to
`/tmp/w984au/`, never `git stash`), court must go RED (kill) else typed
VACUOUS-GUARD; restore, md5-verified byte-identical against the pre-mutation
working-tree snapshot. Pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH`),
`MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW984au`.

Baseline (pre-mutation, all three courts together): **25 passed**. Restored
(post-mutations, same three files): **25 passed**. All 4 target mutations
KILLED — no VACUOUS-GUARD findings.

## Row × mutation verdict table

| Register row | Court (file) | Mutation (minimal production edit) | Mutated run | Restored run | Verdict |
|---|---|---|---|---|---|
| Transfer `:reverse` sufficiency (w983j repair, adverse court) | `test/xaas/ledger/transfer_reverse_adverse_court_test.exs` | `run_sufficiency/2` neutralized: `case Xaas.Ledger.Validations.TransferSourceSufficiency.validate(changeset, [], [])` → `case (changeset && :ok)` (sufficiency no longer enforced on the swapped compensating source — pre-W983j dead-code behavior) | **5/7, 2 RED** — exactly the two sufficiency legs: "w983j follow-up: sufficiency on :reverse is live, not dead code" and "attack 1: … refuses with the sufficiency error" | 7/7 (in 25-passed restored run) | **KILL** |
| OCEL determinism (w984h fix 1, court 5) | `test/xaas/ocel/w983e_ocel_log_courts_test.exs` | removed the `{occurred_at, id}` total-order `Enum.sort_by/2` in `lib/xaas/ocel/case_view.ex` `derive_for_object/2` (pre-W984h order) | **8/9, 1 RED** — exactly "court 5 (W984h): equal-timestamp ties derive deterministically" | 9/9 (in 25-passed restored run) | **KILL** |
| OCEL destroy floor (w984h fix 2, court 6) | same file | `defaults([:read])` → `defaults([:read, :destroy])` in `lib/xaas/ocel/event.ex` (pre-W984h destroy default re-added) | **8/9, 1 RED** — exactly "court 6 (W984h): event log is not deletable" | 9/9 (in 25-passed restored run) | **KILL** |
| SPEC-27 reversal guard (w968c) | `test/xaas/ledger/reversal_deepening_test.exs` | `already_reversed?/1` stubbed to `defp already_reversed?(_), do: false` in `lib/xaas/ledger/changes/reverse_transfer.ex` (reversal-aware guard dead, only sufficiency would refuse double-reverse) | **8/9, 1 RED** — exactly "W968c SPEC-27 :reverse action double-reverse is refused reversal-aware, even when the org has fresh funds" | 9/9 (in 25-passed restored run) | **KILL** |

(The task named 3 rows; w984h's receipt carries two distinct fixes with two
distinct courts, both mutation-run — hence 4 mutation legs over 3 rows.)

## Executed (real tails)

```
# baseline
MIX_BUILD_ROOT=_build-laneW984au mix test transfer_reverse_adverse_court_test.exs w983e_ocel_log_courts_test.exs reversal_deepening_test.exs
  # 25 passed, exit 0 (fresh lane root, full recompile)
# mutation 1 (reverse sufficiency): 5/7, 2 RED (the two sufficiency legs)
# mutation 2a (ocel determinism):   8/9, 1 RED (court 5)
# mutation 2b (ocel destroy floor): 8/9, 1 RED (court 6)
# mutation 3 (SPEC-27 guard):       8/9, 1 RED (SPEC-27 double-reverse leg)
# restored (all three files):        25 passed, exit 0
```

Each mutation ran its court ×1 mutated + the shared restored run ×1; failing
test names captured from real output above. Restores md5-verified:

```
MD5 (reverse_transfer.ex) = 917ccb60f0bc65674fb3755cdf65d086  # matches pre-mutation snapshot
MD5 (case_view.ex)        = 7266b68f8b31d54591b5ad84d012d00a  # matches
MD5 (event.ex)            = 97586301181dfd556bc86de54b5ef2f4  # matches
```

## Standing

- All 3 rows: **KILL verified** — w983j (ALIVE), w984h fixes 1+2 (ALIVE),
  w968c SPEC-27 guard (ALIVE) — REPAIRED verdicts are non-vacuous. No
  VACUOUS-GUARD re-openings; no register edits made in-lane.
- Lane build root `_build-laneW984au`: `rm -rf` **permission-denied** in this
  session (W983j/W984h class) — LEFT ON DISK for coordinator deletion at
  integration (lane-lease cleanup law).
- Working-tree note: all three mutated files were already
  working-tree-modified (the uncommitted lane repairs being tested); snapshots
  and md5s are against that working-tree state, which is the exact subject the
  cited receipts stand on.
- `/tmp/w984au/` snapshots retained for coordinator replay.
