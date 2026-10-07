# W847 — `eu_ai_act_case_count` recalibration to the literal-declaration metric

- **Standing**: PARTIAL_ALIVE (executes real on the exact subject; uncommitted per lane discipline)
- **Subject**: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted lane file: `lib/mix/tasks/xaas.doctor.ex`, plus this receipt)
- **Date**: 2026-10-07
- **Lane**: W847 (v26.10.6 campaign fan-out)
- **Prior**: W825 (`docs/sjira/v26.10.6/plans/w825-doctor-tune.md`) — introduced `eu_ai_act_case_count` with W778/W815's 1200..1450 runtime-population band, WARN at the real 141; coordinator directed recalibration to the honest literal metric.

## Change (μ/diff)

`lib/mix/tasks/xaas.doctor.ex`, 2 edits (100% handwritten; no ggen pack covers a mix-task surface — UNSUPPORTED(generator-capability)):

1. `eu_ai_act_case_count` band retuned to LITERAL declarations: pass in **120..170**
   (W825 measured 141; provenance now cited in-band: "band 120..170, provenance W825/W847").
2. The runtime-generated figure (~1348 per W778/W815) converted from a warn band to an
   INFORMATIONAL detail line: `declarations × observed expansion ≈ <n × 9.6> estimated
   runtime cases (~9.6x per W821 certified census)`. Never affects status.
3. Docstring check 5 updated to match.

No other check touched. Exit-code aggregation (`status == "fail"`) unchanged.

## Real run (this lane, 2026-10-07)

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW847 mix xaas.doctor`
  (fresh lane build root, full dep+app compile; asdf 1.20.2-otp-28; no dev compile).
- Exit code **0**. JSON last-stdout-line round-trips via `python3 json` — valid, **6 checks**:
  - `mock_gate` = pass ("0 banned-mock hits in test/ and lib/")
  - `eu_ai_act_compile` = pass ("17 .exs files parsed clean (syntax-level)") — 17 now, 16 at W825 (concurrent lanes added a file); still in file band 14..20
  - `lane_leases` = pass (63 lanes, 56,486,356,563 total bytes — pre-existing fleet leases)
  - `eu_ai_act_file_count` = pass ("17 .exs files (band 14..20)")
  - `eu_ai_act_case_count` = **pass** — real tail:
    `"146 literal test declarations (band 120..170, provenance W825/W847); declarations × observed expansion ≈ 1401.6 estimated runtime cases (~9.6x per W821 certified census)"`
  - `receipt_census` = warn ("651 receipts; 9 < 500 bytes:" + filenames) — pre-existing, unchanged by this lane.
- Note: the literal count moved 141 (W825) → **146** (concurrent lanes landed new test
  declarations). 146 is inside 120..170 → PASS, honest metric, informational expansion
  line renders 146 × 9.6 ≈ 1401.6.

## All other checks unchanged status

vs W825's run: file_count warn→pass (was already retuned by W825, now holds at 17 files),
case_count warn→pass (this change). mock_gate / eu_ai_act_compile / lane_leases / receipt_census
statuses and semantics unchanged; receipt_census warn is the pre-existing W777 anomaly class.

## Mutation rationale (stated, not run)

`eu_ai_act_case_count` is a leaf predicate. Inverting its band (`n >= 120 and n <= 170`
→ pass-branch swap) flips **only** `eu_ai_act_case_count`: at the current real 146 the
inverted check would report warn ("146 literal test declarations outside band 120..170 …")
while the run stays exit 0 (warn-only check). No other check reads `n` or the expansion
detail; `@observed_expansion` is arithmetic-only and carries no status. Fail-capable checks
(`mock_gate`, `eu_ai_act_compile`) are the only ones that gate exit code — inverting a
branch there would additionally flip exit 0↔1, per W825's rationale, unchanged.

## Deviations (typed)

- `DEVIATED(LANE_LEASE_LEFT)`: `rm -rf _build-laneW847` denied by the permission system
  (same denial class as W825). Lane lease (~437 MB, fully compiled) left for coordinator
  deletion at integration per the cleanup law.

## Falsifier

- Adding/removing literal `test "` declarations to fall outside 120..170 (e.g. deleting
  ~30 declarations) flips `eu_ai_act_case_count` to warn; expansion line still renders.
- Deleting an `.exs` file (→ 13) flips `eu_ai_act_file_count` to warn.
- Injecting `import Mox` into any test file flips `mock_gate` to fail and exit 0→1.

## Standing chain

- Reuses W825's task surface verbatim; band source replaced (W778/W815 runtime population
  → W825 literal census), runtime figure demoted to informational per W821's certified census.
