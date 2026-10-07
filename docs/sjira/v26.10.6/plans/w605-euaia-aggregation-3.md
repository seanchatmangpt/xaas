# W605 — EU-AI-Act post-flip aggregation (final gate + census)

Lane W605 · repo `/Users/sac/xaas` @ `feat/playwright-surface` ·
build root `_build-laneW605` (lease; coordinator deletes at integration) ·
asdf pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH` → elixir 1.20.2-otp-28).
No lib/test edits; this receipt is the only file written.

## Gate poll

- `w547-gap-flips.md` — present at first check (mtime 21:06). Final verdict:
  1048 passed / 24 excluded (green); census 1048/1072, **24 open gaps**
  (37 → 24, target ≤25 met). 13 flips (12 → EVIDENCED, 1 → NOT_APPLICABLE).
- `w546-os18-fix.md` — present at first check (mtime 21:24). Verdict in file:
  fix live, witness flipped + mutant KILLED, 7/7 on
  `test/xaas/actuation_refusal_negative_test.exs` (exit 0). Its
  "Corpus results" section was still a placeholder `(placeholder — replaced
  with the actual run record)` through 5 polls ending 21:4x — the fix, flip,
  and mutant-kill verdicts are complete; the corpus run-log block had not
  been filled at budget. Note: W546's new corpus test lives in `test/xaas/`
  (tagged differently from `test/eu_ai_act/`), so it does NOT change the
  eu_ai_act counts below — matches the task brief's note.

No 40-min wait needed: both files existed on first poll.

## Final aggregation run (fresh root `_build-laneW605`, both directions)

(a) Green gate:
`MIX_BUILD_ROOT=_build-laneW605 MIX_ENV=test mix test test/eu_ai_act
--include eu_ai_act --exclude eu_ai_act_open_gap`

```
Result: 1068 passed, 19 excluded
exit 0
```

GREEN. 1068 ≥ 1048 (+20 further tests landed by other lanes this wave;
W546's corpus test is under `test/xaas/`, not counted here, per brief).

(b) Honest census (no exclude):
`MIX_BUILD_ROOT=_build-laneW605 MIX_ENV=test mix test test/eu_ai_act
--include eu_ai_act --include eu_ai_act_open_gap`

```
Result: 1068/1087 passed
Failed: 19 tests
```

Typed open-gap count = **19** (≤24 target met; below W547's 24 — further
flips landed between W547's run and this aggregation). The 19 failures in
(b) exactly equal the 19 `eu_ai_act_open_gap`-tagged exclusions in (a):
every failure is a tagged OPEN_GAP, zero untagged failures. Suite is
honest: green gate green, census failures are all deliberate open gaps.

## Terminal verdict

- **EVERY-LINE-TESTED** — corpus census direction executed; remaining
  uncovered lines are exactly the 19 tagged OPEN_GAP corpus entries.
- **SUITE-GREEN** — gate direction: 1068 passed, 0 failed, exit 0.

## Counts (aggregated)

| direction | result |
|---|---|
| gate (open gaps excluded) | 1068 passed, 19 excluded, exit 0 |
| census (open gaps included) | 1068/1087, 19 failed = 19 typed OPEN_GAPs |

Standing: the EU-AI-Act compliance corpus on this subject passes its green
gate and its honest census shows 19 remaining open gaps (down from 24 at
W547, 37 before W547). W546's OS-18 refusal is live and mutant-killed;
its corpus-test receipt block was still pending at aggregation time
(flagged to coordinator).
