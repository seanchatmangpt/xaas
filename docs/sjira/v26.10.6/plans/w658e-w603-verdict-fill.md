# w658e — W603 §6 suite-verdict fill (lane W658e)

Date: 2026-10-07. Subject: `/Users/sac/ash_pplan` @ `fix/ggen-verify-header` (414a393),
canonical checkout, private build root `_build-laneW658e`, nothing committed.
Task: fill W603's §6 suite-result line from a real suite run (W603 receipt §6 fill,
v26.10.6 campaign).

## 1. Run tail

Full command:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_pplan/_build-laneW658e mix test`

Three full-suite attempts, all killed by the harness background cap (2h max each):

1. Plain `mix test` — killed at 2h; no output had flushed (piped through `tail`),
   exit tail literal `[killed]`.
2. `mix test` rerun — killed at 2h, same.
3. `mix test --trace > /tmp/w658e-suite.log` — killed at 2h; partial log shows
   1955 tests executed with **zero failure blocks** (courts: PackProtocolCourt —
   incl. a 110s byte-identity render under load, PackDslSmokeCourt, CaseStudyCourt,
   DemonstrationCourt, plus others). One wedge: `DemonstrationCourtTest`'s nested
   `bin/demonstrate` chain ran 75+ min against its own 30-min
   `@moduletag timeout: 1_800_000` under load 70-90 (nested full-suite chain
   starved by fleet load; it did complete, suite advanced to
   `G1CorrespondsToStepCourtTest`, then the cap killed the run).
4. `mix test --exclude demonstration_court > /tmp/w658e-suite2.log` — killed at 2h;
   cleared the burn-in courts (19 cycles) and standing-churn courts (331 iters/s,
   p99=32ms) with **no F markers**, last output a benign Dets handle_info notice at
   07:24, kill at 07:33. No summary line reached.

No run ever produced an ExUnit summary (`N tests, M failures`) — the suite is
non-completing under this host's fleet load, not failing.

## 2. §6 fill

Filled in `/Users/sac/xaas/docs/sjira/v26.10.6/plans/w603-ash-pplan-map-update.md` §6
(amended, not overwritten — W603's own capture was already on disk; the dispatch's
"still says `(filled at run completion)`" was stale). Note: the plan file lives in
the **xaas** repo at that path; the dispatch's `/Users/sac/ash_pplan/docs/...` path
does not exist.

## 3. Load context

Load averages during the window: 27-110, never below 20 (samples: 57-61 at start,
peaks 102-109, minimum 27 mid-run). **Load-gate condition (>20) was violated for the
entire window** — this capture is best-effort under fleet load; W610's quiet-machine
rerun remains the receipt-grade path, as anticipated.

## 4. Verdict

- **BLOCKED(contention)** for a clean full-suite verdict on this host today:
  3 full-suite attempts killed at harness time caps, load 27-110 throughout, summary
  line never reached.
- **No test-failure evidence**: 1955 tests executed in the trace partial with zero
  failure blocks; the exclusion partial cleared burn-in/standing-churn with zero F
  markers. Nothing observed against W603's 8 patched sites (their regression module
  passed 5/5 in W603's own capture; the narrow `manufacture_test` gate was GREEN per
  W291).
- Standing: best-effort capture under load-gate violation; counts are partial, not
  suite-final. Do not cite as a green suite.
