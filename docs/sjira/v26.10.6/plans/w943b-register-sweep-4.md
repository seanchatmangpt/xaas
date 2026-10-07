# W943b — Typed-Gap Register sweep 4 (receipt)

- **Lane**: W943b, v26.10.6 campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`
  (canonical checkout, no worktree, no commit — per lane contract). No build root created.
- **Subject files**: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` (sweep 4 edits),
  this receipt.
- **Standing**: PARTIAL_ALIVE — all `test -f` checks ran against the real plans directory;
  3 flips landed with dual citations; 2 new rows appended; totals grep-verified. One
  concurrent-write event observed and resolved by re-reading, not reverting (below).

## Receipt checks (real `test -f` outputs, 2026-10-07)

| Receipt | Exists? | Register effect |
|---|---|---|
| w902-batch3-repairs.md | EXISTS | drives all 3 flips |
| w925-slot-release.md | MISSING | W893 CancelDoesNotReleaseSlot stays OPEN |
| w920-obs-witness-tie.md | EXISTS | composition evidence only — no gap, no register change |
| w907-bare-fun-fix.md / w860-health-timeout.md | EXIST | already registered by W944 (no-op) |
| w928 (gymact court) | MISSING | W674-GAP-2 stays OPEN (w902: flips when W928 lands green) |

## Flips (OPEN → REPAIRED, dual citations)

1. **W793 4-gap row** (RESOLVED_AT_GUARD_ONLY_ON_UPDATE, NO_REOPEN_GUARD,
   NO_RESOLVED_AT_GUARD, NO_POSTMORTEM_STATUS_GUARD) → REPAIRED. Citations:
   w793-incident-lifecycle-deepening.md (disclosure) + w818-incident-guards.md (first 2,
   verified in-tree by W902) + w902-batch3-repairs.md (remaining 2: new
   `IncidentResolvedAtRequiresResolved` / `IncidentPostmortemFinalRequiresResolved`
   validations wired on `:update`; `sed` mutation → 16/18 with exactly the 2 new tests
   failing, restored byte-identical; final run 101/102 with the 1 failure proven
   pre-existing). W793 NO_CROSS_REFERENCE row (separate row) stays OPEN.
2. **W796-G1 borrow cap** → REPAIRED. Citations: w796-checkout-policy-deepening.md
   (disclosure) + w902-batch3-repairs.md (before_action `Ash.count!` guard,
   `@max_open_checkouts_per_student = 3`; mutation `>= 999_999` → 11/13 with exactly the
   cap tests failing, restored byte-identical).
3. **W849 backlog-1 sha256 pins** → REPAIRED. Citations: w849-generated-surface-census.md
   (disclosure) + w852-provenance-pins.md (10 surfaces incl. all 4 PROVENANCE-ONLY pinned)
   + w902-batch3-repairs.md (verify-first confirmation: registry drift guard green in the
   101/102 final run). Backlog-2 (CI/regen leg) and backlog-3 stay OPEN — w852 explicitly
   leaves the regen leg P2-2 open.

## Left OPEN (checked, not flipped)

- **W893 CancelDoesNotReleaseSlot** — w925-slot-release.md re-checked absent this sweep;
  annotation updated to record the sweep-4 check. Code-side status filter landed; row stays
  OPEN until the w925 receipt with its court run exists.
- **W674-GAP-2** — w928 receipt absent; w902 reports the repair staged but the owning court
  suite red; flips when W928 lands green.

## New rows appended

1. **W902 sandbox-escape contamination class** — OPEN (environmental): shared `xaas_test`
   DB stray committed rows from cross-lane sandbox escapes pollute `Ash.count!`-based
   assertions (w902 observation 3, `count == 6 != 2` at 12:14–12:22; recurrence expected
   under fan-out until coordinator hygiene pass or per-lane test DBs).
2. **W838-G1 harness direct-delivery quirk** — registered by this lane as TYPED-OPEN from
   w838-pubsub-publish-court.md typed gap 1 (unregistered before this sweep).

## Concurrent-write event (disclosed, not acted against)

Mid-sweep, sibling lane **W943c (sweep 5)** edited the same register concurrently:
W765 GAP-B and GAP-C flipped to REPAIRED (w935 + w940b, commit `fab56ae1`) and W838-G1 was
upgraded from my TYPED-OPEN draft to REPAIRED with strictly stronger citations
(w909-pubsub-g1-rootcause.md root cause + w918b-awaiter-hardening.md repair; both
`test -f`-verified by this lane after the event). W943c also reconciled the footer to the
merged table. This lane re-read the on-disk state and kept W943c's versions — no revert, no
second writer on the same cell. The sweep-4 bullet in the footer remains verbatim as this
lane wrote it; the sweep-5 bullet records the supersession of the W838-G1 disposition.

## Totals (grep-verified post-merge, `awk -F'|'` on the status cell)

- Table: **48 data rows = 31 OPEN + 15 REPAIRED + 2 TYPED-OPEN** (0 unclassified; separator
  row excluded). Matches the merged footer exactly.
- Delta from sweep 3 (46 rows = 35 OPEN + 9 REPAIRED + 2 TYPED-OPEN): +2 rows, −4 OPEN,
  +6 REPAIRED (3 from this lane: W793 4-gap, W796-G1, W849-1; 3 from W943c: W765 GAP-B/C,
  W838-G1).

## Verification commands

```
test -f docs/sjira/v26.10.6/plans/w902-batch3-repairs.md   # EXISTS
test -f docs/sjira/v26.10.6/plans/w925-slot-release.md     # MISSING (exit 1)
awk '/^## Register/,/^## Totals/' docs/sjira/v26.10.6/plans/w859-typed-gap-register.md \
  | grep '^| ' | grep -v 'Gap id' | grep -c '| OPEN |'        # 31
# same for '| REPAIRED |' -> 15, '| TYPED-OPEN |' -> 2; unclassified -> 0
```

## Replay / falsifier

Re-run the three greps above; a count other than 31/15/2 or a missing dual citation on the
three flipped rows falsifies this receipt. Register standing: PARTIAL_ALIVE — the register
reflects the merged post-sweep-5 table; next sweep's trigger is w925-slot-release.md or a
W928 receipt landing (W893 and W674-GAP-2 respectively).
