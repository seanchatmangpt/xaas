# W650h10 — Owner-Defect Repair: `process_receipt_depth_test.exs`

Lane: W650h10, xaas v26.10.6 campaign. Parent exclusion: W650h5
(`w650h5-commit.md`, OWNER-DEFECT class).
Subject: `test/xaas/causal_receipt/process_receipt_depth_test.exs` (untracked,
one canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`).
NOT committed — file left in working tree for coordinator integration.

## Before (real tail, this lane)

The court did not compile. Two real defects, both compile-class:

1. **Line 74** — `DateTime.shift!(~U[...], second: 0)` is not a real API;
   `DateTime` exports no `shift!/2`. Fixed to
   `DateTime.add(~U[2026-10-07 00:00:00Z], 0, :second)` — equal-instant
   DateTime struct canonicalizing to the same `episode_id` (the test's
   stated intent, json_safe/ISO8601 path).
2. **Lines 130–131** — garbage placeholder. Actual before-tail (this lane's
   fresh compile) is a hard `CompileError`:
   `error: undefined variable "v"` at line 131 (`... elem(stage =
   {:intent_placholder_guard}, 0) && v) or true`); `v` was only bound inside
   the anonymous fn on line 130, and `{:intent_placholder_guard, ...}` is
   meaningless. Replaced with real lineage invariants against
   `lib/xaas/causal_receipt/process_receipt.ex` read fresh this lane:
   planning and intent stages surface as `{stage, nil}` (honest-absence),
   `:do` reconstructs `"act-1"`, `:consequence` reconstructs `"cons-1"`,
   `:receipt` reconstructs `signed.receipt_hash`.
3. **Line 143** — `refute Map.has_key?(d, :receipt_hash)` contradicted
   diff/2's actual output: diff/2 iterates `@all_fields` (includes
   `:receipt_hash`), and two separately signed receipts differing in
   `consequence_identity` necessarily differ in `episode_id` and
   `receipt_hash`. Corrected to the actual field-exclusion shape: refute
   `:ontology_hash`, and assert the exact key set
   `[:consequence_identity, :episode_id, :receipt_hash]`.

Before run tail (fresh root `_build-laneW650h10`, this lane):

```
error: undefined variable "v"
 131 |     assert is_nil(v = elem(stage = {:intent_placholder_guard}, 0) && v) or true
== Compilation error in file test/xaas/causal_receipt/process_receipt_depth_test.exs ==
** (CompileError) ... (errors have been logged)
```

## After

Diff summary (3 hunks, 1 file): DateTime.add fix; placeholder → 6 real
lineage assertions; refute → exact diff key-set assertion. No lib/ changes;
module surface untouched.

## Verification (real tails)

Run 1 (fresh root `_build-laneW650h10`, after-state picked up — the
backgrounded compile finished after the edits landed):

```
Running ExUnit with seed: 270743, max_cases: 32
.....
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 5 passed
[exited with code 0]
```

Run 2 (fresh root `_build-laneW650h10b`, after-state, seed 147192):

```
Running ExUnit with seed: 147192, max_cases: 32
Finished in 0.09 seconds (0.09s async, 0.00s sync)
Result: 5 passed
exit=0
```

Note: this root was built across three wrapper launches (two hit the
10-minute background execution cap mid-compile and were killed; the third
resumed the same root incrementally to completion — no test result was
discarded, the final run compiled and executed from that root to green).

## Standing

ALIVE on subject `test/xaas/causal_receipt/process_receipt_depth_test.exs`
as present in the working tree (untracked): 5/5 tests pass on two
independent fresh build roots, before-state CompileError reproduced from
this lane. Court killed mutations named in its own comments remain the
module's falsifier surface.

## Notes

- W650h5's receipt described the before-state as "2 real failures
  (DateTime.shift! + refute receipt_hash) + garbage placeholder". This
  lane's measurement sharpens that: the placeholder made the file fail at
  COMPILE time (`undefined variable "v"`), so none of the 5 tests executed
  in the before-state — the refute at 143 and the shift! at 74 were both
  latent under the compile error.
- No mocking introduced (Chicago: real structs, real sha256 chaining).
- Lane leases NOT cleaned: deletion of `_build-laneW650h10` /
  `_build-laneW650h10b` was denied by the permission system in this lane's
  session — both roots (~850MB) are left for the coordinator to remove at
  integration, per the fallback in the dispatch contract.
