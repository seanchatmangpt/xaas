# W329 — DoD 1: un-ignored bounded suites, real run counts

Subject: /Users/sac/xaas @ feat/playwright-surface (uncommitted tree as of run, no commits by this lane).
Command pattern: `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW329 mix test <path>`.

| suite | path | expect | result (mix verbatim) | verdict |
|---|---|---|---|---|
| receipt dir (incl. r_projection) | `test/xaas/receipt/` | 9/9 r_projection, 0 skip | `Result: 27 passed` (0 failures, 0 skipped) | PASS |
| origin_authority | `test/xaas/ultracode/origin_authority_test.exs` | 10/10 | `Result: 10 passed` | PASS |
| ard_court | `test/xaas/sjira/ard_court_test.exs` | 51/0 | `Result: 51 passed` | PASS |
| yield | `test/xaas/sjira/yield_test.exs` | 8/8, 0 skip | `Result: 8 passed` | PASS |
| consistency | `test/xaas/receipt/r_projection_consistency_test.exs` | 18/18 | `Result: 18 passed` | PASS |
| successor | `test/xaas/sjira/successor_test.exs | 8/8 | `Result: 8 passed` | PASS |
| semantic_drive_anchor | `test/xa/xaas/ultracode/semantic_drive_anchor_test.exs` | 8/8 | `Result: 8 passed` | PASS |
| lineage (expected 24/24) | NO dedicated lineage suite exists. Closest: `test/xaas/causal_receipt/process_receipt_test.exs` (contains `describe "lineage/1"`); ran it: `Result: 16 passed`. Expected 24/24 NOT reproducible. | 24/24 | `Result: 16 passed` | MISMATCH — finding |

## Findings

1. **Silent-skip conversion NOT done**: `test/xaas/receipt/r_projection_test.exs:21-25` still gates
   `@needs_validator` via `if File.regular?(@validator)`, applied as `@tag skip:` at lines 65, 115, 128,
   146, 167, 206. No flunk/presence assert was added. At this run the validator exists on disk
   (`~/.claude/dfcm/validate_receipt.py`, 5376 bytes, mtime 2026-10-06 13:02), so 0 skips fired — the
   27/27 was real, but the silent-skip path remains live for environments without the validator.
2. **Lineage suite 24/24 not found**: `grep -rl 'defmodule' test/xaas | grep -E 'consisten|successor|lineage'`
   yields only successor_test.exs and r_projection_consistency_test.exs. The only "lineage" test surface is
   the `describe "lineage/1"` block (6 tests) inside `test/xaas/causal_receipt/process_receipt_test.exs`
   (file total 16 tests, all passing). DoD 1's 24/24 expectation has no referent on this tree.
3. All other suites green with **0 skipped** across the board (no "skipped" line appeared in any tail).
