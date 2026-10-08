# W984kd — typed-gap register footer re-tally receipt (2026-10-08)

Subject: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` @ branch
`feat/playwright-surface` (uncommitted working-tree state, mtime Oct 7 23:33).
Docs-only lane; no commit, no build root.

## Per-status grep counts (real output)

```
$ awk -F'|' '/^\|/ && $5 ~ /(REPAIRED|OPEN|TYPED-OPEN|OUT-OF-SCOPE)/ {print $5}' \
    docs/sjira/v26.10.6/plans/w859-typed-gap-register.md \
  | sed 's/^ *//;s/ *$//' | sort | uniq -c

    46 REPAIRED
     1 OPEN
     2 TYPED-OPEN
     2 OUT-OF-SCOPE(removed-by-operator, 2026-10-07)
    ----
    51 rows
```

Footer on disk (W984ff) still reads **44 REPAIRED / 3 OPEN / 2 TYPED-OPEN /
2 OUT-OF-SCOPE** — stale by 2 (the W784 and W902 flips).

## Findings

1. **W784 flip already reflected as a row update** (line 44:
   `REPAIRED`), receipt `w984fv-w784.md` exists on disk. Footer not updated.
2. **W902 flip already reflected as a row update** (line 69:
   `REPAIRED`), receipt `w984fs-w902.md` exists on disk. Footer not updated.
3. Footer's prose ("W784 TOFU 0 lib/ hits, stays OPEN; W902 ... stays OPEN")
   contradicts the rows above it in the same file — the footer was written
   against a pre-flip tree state.
4. **Remaining OPEN row is W729 UNSUPPORTED(atomic_update)** (line 29, the
   only literal `OPEN` marker in the status column). Its marker is itself
   stale: `w983p-register-flips.md` records `FLIPPED → REPAIRED (w984cc)`,
   receipt `w984cc-spec08-execute.md` documents 3 true conversions + court
   green ×2 + mutation killed, and `w984fr-atomic-site1.md` re-witnessed the
   landing ("ALREADY-LANDED"). The row's named blocker
   (BLOCKED(billing-tree-hot), w984az/w984bd) is superseded, not live.
   Per dispatch ("do not rewrite rows") the marker was left as OPEN;
   fully-applied tally would be 47 REPAIRED / 0 OPEN.
5. TYPED-OPEN ×2 (W811 test-scope; 49.3 EU-AI-Act deployer-registration
   OPEN_GAP) and OUT-OF-SCOPE ×2 unchanged.

## Action taken

Dated addendum appended to `w859-typed-gap-register.md`
(2026-10-08, lane W984kd) with corrected tally 46/1/2/2 and delta rows only
(W784, W902 flips + W729 marker-lag disclosure). No rows rewritten, no
commit.
