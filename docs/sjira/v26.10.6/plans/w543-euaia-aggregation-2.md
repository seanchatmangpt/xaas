# W543 — EU-AI-Act wave fresh suite aggregation (supersedes W526b)

Subject: /Users/sac/xaas @ feat/playwright-surface, private build root `_build-laneW543`
Date: 2026-10-06

## Commands (real, run under pinned asdf toolchain)

1. Green gate:
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW543 mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/`

```
Result: 1035 passed, 37 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

2. Honest census (same, without `--exclude`):

```
Result: 1035/1072 passed
Failed: 37 tests
```

All 37 failures carry `OPEN_GAP:` in the assertion message (spot-checked: 50.2 marking, 15.5.s3,
26.7 workplace deployer duty, 73.2 serious-incident reporting) — zero non-open-gap failures.

## Counts

- Green gate (open gaps excluded): **1035 passed, 0 failed, 37 excluded** — SUITE-GREEN: **YES**
- Full census: **1035/1072 passed, 37 typed OPEN_GAP failures** — typed open-gap count = **37**
- Note vs expectation: landed well below the ~67 prior estimate. Consistent with W533's marking
  flip (the 50.2 test now exists as an explicit OPEN_GAP assertion rather than absent) plus the
  Art 26/27 reclassifications and W533/W539/W540 surface landings converting former gaps to
  evidenced passes. The 50.2 marking seam is still an OPEN_GAP, not flipped — counted real.

## Per-title attribution

| Surface | Evidence |
|---|---|
| W533 synthetic marking | 50.2 OPEN_GAP assertion present in TitleIVVTest (marking seam still open) |
| W539/W540 surfaces | folded into 1035 passing evidence tests |
| Art 26/27 reclassifications | TitleIIIOpenGapsTest carries 26.7 as typed OPEN_GAP; siblings pass |

## Verdicts

- EVERY-CORPUS-LINE-TESTED: **YES** — every corpus line terminates in exactly one of:
  evidenced pass (1035), typed OPEN_GAP assertion (37), or NOT_APPLICABLE pass (within the 1035).
- SUITE-GREEN: **YES** (with `--exclude eu_ai_act_open_gap`).
