# W473b — Quiescent full-suite clean run (DoD 1 closure)

Date: 2026-10-06, 19:51–20:06 local. Lane W473b, repo /Users/sac/xaas @ feat/playwright-surface.

## Verdict: GATED(load)

## Load gate observations (uptime 1-min, 180 s apart)

| check | time | 1-min load | 5-min | 15-min |
|---|---|---|---|---|
| 1 (initial) | 19:51 | 19.87 | 27.70 | 38.49 |
| 2 | 19:54 | 35.68 | 30.07 | 37.22 |
| 3 | 19:57 | 26.99 | 27.80 | 34.84 |
| 4 | 20:00 | 24.16 | 25.86 | 32.57 |
| 5 | 20:03 | 17.47 | 21.52 | 29.44 |
| 6 (final) | 20:06 | 29.58 | 26.31 | 29.96 |

Never <10 in 6 checks (~19 min). 15-min average declined (38.49 → 29.96) but 1-min load
regressed at the final check (17.47 → 29.58), so no admissible window opened before the
check budget was exhausted.

## Test run

Not executed — load gate never admitted. No MIX_BUILD_ROOT mint occurred;
`_build-laneW473b` was never created (nothing to clean up).

## Baseline carried forward (not re-confirmed here)

w316b: 3247 addressable tests, 0 real failures, minted at high load with castle-lock
contention. The quiet single-run confirmation remains OPEN.

## Mock gate

Not run (no test run to gate).

## Standing

GATED(load) — rerun this protocol when host load <10. Not a product failure; no
classification of env-vs-real possible.

---

# W473c — Retry (same protocol, extended patience)

Date: 2026-10-06, 20:07–20:35 local. Lane W473c, repo /Users/sac/xaas @ feat/playwright-surface
(HEAD d1db2b03). Contract: plans/w473b-quiescent-suite.md append + _build-laneW473c only.

## Load gate (12 checks max, 300 s apart)

| check | time | 1-min load |
|---|---|---|
| 0 (pre-loop) | 20:07 | 29.93 |
| 1 | 20:07:28 | 28.14 |
| 2 | 20:12:29 | 14.20 |
| 3 | 20:17:29 | 6.95 |

ADMITTED at check 3 (load 6.95 < 10, ~10 min elapsed). EU-AI-Act drain confirmed by W473b's
declining 15-min trend.

## Test run (mint)

Command: `INTERNAL_API_TOKEN=w473c-token; PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW473c mix test` (castle lock not required — no run
reached the castle stages). Result: **BUILD_BROKEN before test collection**.

```
== Compilation error in file lib/xaas/semantics/declared_metrics.ex ==
** (CompileError) lib/xaas/semantics/declared_metrics.ex:104: cannot compile module
Xaas.Semantics.DeclaredMetrics (errors have been logged)
error: undefined variable "coverage" / "kills" / "runs" at 104:37/62/84
```

0 tests addressable in this mint (suite never collected; w316b baseline of 3247 not
re-confirmed or refuted).

## Isolation (one attempt) and classification

Toolchain verified pinned: Elixir 1.20.2-otp-28 / OTP 28 via asdf shims. Minimal repro under
the pinned toolchain:

```elixir
with %{"a" => a, "b" => b} <- x when is_integer(a) and is_integer(b) do ...
```

reproduces the identical `undefined variable "a"/"b"` errors — the `with` right-arrow clause
guard at declared_metrics.ex:104 references pattern-bound variables, which the pinned
compiler rejects. Deterministic compile error, not flake, not environment skew.

Provenance: `git status --porcelain` shows `lib/xaas/semantics/declared_metrics.ex` is
**untracked** (`??`) — a working-tree leftover from the concurrent EU-AI-Act semantics lanes
(w447-semantics-slice et al.), not part of feat/playwright-surface's committed tree. Any lane
compiling the app after this residue landed hits the same break; it is lane-coordination
damage to the shared checkout, not a regression on any commit.

**Classification: BUILD_BROKEN — foreign untracked file, REAL finding (closes DoD 1 as
BLOCKED, not green).** The quiescent-window question W473b opened is moot: even at load 6.95
the suite cannot mint. Remint gate for the next lane: the untracked residue must be removed
or its compile fixed by its owning lane first (`git status --porcelain lib/ | grep '^??'`
before minting).

## Mock gate

BLOCKED by the same compile break (`mix run -e scan_mock_usage` compiles the app first;
identical CompileError). Cannot return [] or non-empty.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW473c` attempted post-run — **DENIED** by the session
permission system (both attempts). Lane build root `_build-laneW473c` REMAINS ON DISK; the
coordinator must delete it at integration per the cleanup law.

## Standing

BLOCKED(build-residue) — DoD 1 (quiescent clean full-suite confirmation) remains OPEN.
Mint load at admission: 6.95.
