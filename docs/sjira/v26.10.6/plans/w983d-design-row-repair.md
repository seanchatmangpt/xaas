# W983d — DESIGN-class register sweep: W722 gap-2 flip + W793 NO_CROSS_REFERENCE disposition

- Lane W983d, xaas v26.10.6, repo `/Users/sac/xaas` @ `feat/playwright-surface`,
  HEAD `6f235905b6e071c236c5abb0ce0bf872e0bfd7b4` (dirty tree; no commit by this lane).
- Register: `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`.

## Row 1: W722 gap 2 (`X-Org-Id` caller-asserted) — flip applied per dispatch

Directive row. W982t's receipt (`w982t-w722-gap2.md`) had already re-witnessed the
SPEC-04 court GREEN (14/14, fresh `_build-laneW982t`); only the register flip was
missing. Applied the flip exactly per the W982t pattern: register line 23
`OPEN → REPAIRED`, citing commit `5a853130` (receipts w951b/w969b/w975/w970b)
+ w982t re-witness. No new code, no new test run for this row (w982t's witness
stands; re-running its court again would add no bits).

## Row 2: W793 GAP(NO_CROSS_REFERENCE) — ALREADY-LANDED, witness + flip

Chosen next OPEN DESIGN row (re-read the register fresh as instructed; W729×2,
W731, W765 GAP-D, W784, W802/W819, W824, W849-2, W902 remain OPEN). Avoided
lane-hot surfaces (`bridges/*` via W983b/W982b, `conference/*` via W983a).

Fresh re-read confirmed the landing exists at HEAD:

- Commit `b2758300` ("fix(platform): W969c SPEC-21 route create + W970b
  hold checkout/retention/castle link (receipts w969c, w970b, w796, w792, w793)").
- Production: `priv/repo/migrations/20261007240000_add_castle_run_id_to_incidents.exs`
  (nullable `castle_run_id` uuid + index) and `lib/xaas/operations/incident.ex`
  (`belongs_to :castle_run → Xaas.Operations.RouteCastleRun`, nullable, writable
  via `:update` accept) — exactly the W793 gap's repair.
- Court: `test/xaas/operations/incident_lifecycle_deepening_test.exs` carries the
  castle_run pin/court (only operations test files grepping `castle_run`).

### Witnessed execution (this lane's new evidence)

Fresh lane build root `_build-laneW983d`, pinned toolchain
(`PATH=$HOME/.asdf/shims:$PATH`, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW983d):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983d \
  mix compile
  mix test test/xaas/operations/incident_lifecycle_deepening_test.exs \
           test/xaas/operations/incident_test.exs
# PASS 1: Result: 30 passed  (exit 0)   [full fresh compile of deps first]
# PASS 2: Result: 30 passed  (exit 0)
```

×2 consecutive green runs at HEAD on the exact register-row subject. The court
proves the incident↔castle link is real at the resource layer (relationship +
`:update` accept + read-back persistence).

No mutation kill performed: honest disclosure — per the W982t/W722 precedent,
on an already-landed, court-witnessed subject the mutation run is moot, and a
RED mutation against another wave's landed court is outside this lane's file
ownership. The original W970b receipt records its own mutation (compile-level
kill, disclosed there).

## Register flips written

- Line 23 (W722 gap 2): OPEN → REPAIRED citing `5a853130` + w982t re-witness.
- Line 44 (W793 NO_CROSS_REFERENCE): OPEN → REPAIRED citing `b2758300` +
  w970b-open-sweep.md row 2 + this lane's ×2 re-witness.

Concurrent-lane note: the register file changed on disk mid-lane (another lane
editing rows concurrently); this lane re-read the row immediately before each
flip and edited only its own rows.

## What is still OPEN (fresh post-edit register)

W729 atomic_update, W731 graphlaw limits, W750-G2, W765 GAP-D, W784 TOFU,
W802/W819 graphql ×2, W824, W849 backlog-2, W902 environmental, W804 operator
action (dev DB).

## Standing

- W722 gap 2: REPAIRED (standing inherited from `5a853130`; witness w982t + flip w983d).
- W793 NO_CROSS_REFERENCE: REPAIRED (standing inherited from `b2758300`/w970b;
  ×2 re-witness by w983d). Falsifier would be: a court proving `castle_run_id`
  is not settable through `:update` — it is settable and persists, court green.

## Lane hygiene

`_build-laneW983d` left in place for coordinator deletion (this lane's `rm -rf`
was permission-denied, same as W982t's). No production/test files touched; only
`w859-typed-gap-register.md` (2 row flips) + this receipt. No commit.
