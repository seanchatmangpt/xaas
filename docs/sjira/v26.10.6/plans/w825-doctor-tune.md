# W825 — `mix xaas.doctor` band retune + case-count check + receipt-census detail

- **Standing**: PARTIAL_ALIVE (task executes with real output on the exact subject; uncommitted per lane discipline)
- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane file: `lib/mix/tasks/xaas.doctor.ex`, plus this receipt)
- **Date**: 2026-10-07
- **Lane**: W825 (v26.10.6 campaign fan-out)
- **Prior**: W791 (`docs/sjira/v26.10.6/plans/w791-doctor-task.md`) — `eu_ai_act_file_count` band 1080..1320 was written against test CASES (~1200), so the real 16-file population warned forever.

## Change (μ/diff)

`lib/mix/tasks/xaas.doctor.ex`, 3 edits (100% handwritten; no ggen pack covers a mix-task surface — UNSUPPORTED(generator-capability)):

1. `eu_ai_act_file_count` band retuned to FILES: pass in [14, 20] (real population 16).
2. NEW check `eu_ai_act_case_count` — regex `~r/^\s*test "/m` scanned across every
   `test/eu_ai_act/**/*.exs`, WARN outside [1200, 1450] per W778/W815. Detail names the
   band's provenance (runtime-generated cases, not declarations).
3. `receipt_census` empty-receipt warning now lists up to 10 offending filenames with
   byte sizes + `(+N more)` instead of a count only.

Docstring updated to 6 checks. No other checks touched.

## Real measured numbers (this lane, 2026-10-07)

- `test/eu_ai_act/` = **16** `.exs` files (in new band 14..20 → pass).
- Literal `test "` declarations = **141** across those files. This is NOT ~1348:
  W778/W815's ~1348 was the RUNTIME-generated case population (property/comprehension
  expansion), not declaration lines. As directed, the check keeps the 1200..1450 band and
  reports WARN with the real number until the band is recalibrated to declarations
  (recalibration is coordinator work — it changes W778/W815's contract, not just this file).

## Verification ladder (real output)

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW825 mix xaas.doctor`
  (fresh lane build root, full dep + app compile from scratch, ~25 min; no dev compile, asdf 1.20.2-otp-28).
- Exit code **0**. JSON (last stdout line) round-tripped via python3 `json.load` — valid,
  **6 checks**:
  - `mock_gate` = pass ("0 banned-mock hits in test/ and lib/")
  - `eu_ai_act_compile` = pass ("16 .exs files parsed clean (syntax-level)")
  - `lane_leases` = pass (49 lanes, 42,777,675,403 total bytes — pre-existing fleet leases, not introduced here)
  - `eu_ai_act_file_count` = **pass** ("16 .exs files (band 14..20)") — previously WARN
  - `eu_ai_act_case_count` = **warn** ("141 literal test declarations outside band 1200..1450 …")
  - `receipt_census` = warn ("622 receipts; 9 < 500 bytes:" + 9 filenames listed, ≤10 cap untriggered)
- Expected-shape check: exactly as directed — file band passes, case count warns with the
  real 141 in detail, receipt census lists names.

## Mutation rationale (stated, not run)

Inverting `eu_ai_act_case_count`'s predicate (`n < 1200 or n > 1450` → pass-branch) flips
**only** `eu_ai_act_case_count` itself: pass→warn at the real 141 (and vice versa). It is a
leaf predicate; no other check reads its value, and it is warn-only so exit code does not
change. Inverting `eu_ai_act_file_count`'s band likewise flips only itself (16 ↔ outside
14..20). Fail-capable checks (`mock_gate`, `eu_ai_act_compile`) are guarded by exit-code
aggregation over `status == "fail"` — inverting a pass/fail branch there would additionally
flip exit code 0↔1.

## Deviations (typed)

- `DEVIATED(LANE_LEASE_LEFT)`: `rm -rf _build-laneW825` was denied by the permission system.
  The lane lease (~912 MB, fully compiled) is left for coordinator deletion at integration
  per the cleanup law. Total fleet lease load at run time: 49 lanes / ~42.8 GB.
- No cross-lane compile blockers observed this run (unlike W791).

## Falsifier

- `mix xaas.doctor` exits nonzero with machine-checkable JSON when `eu_ai_act_compile` or
  `mock_gate` fails (injectable: `import Mox` in any test file).
- Band checks: adding/removing an `.exs` file outside 14..20 flips `eu_ai_act_file_count`
  to warn; deleting test declarations flips `eu_ai_act_case_count` (already warn at 141).

## Standing chain

- Reuses W791's task surface; no re-implementation. W778/W815 case-population figure now
  explicitly attributed in the check detail instead of silently mis-banding files.
