# W984fo restoration receipt — W984fe lost court file restored

Lane: W984fo, canonical checkout /Users/sac/xaas, branch feat/playwright-surface.
No commit made (per dispatch). Build root: `_build-laneW984fo` (MIX_ENV=test).

## 1. Loss and finding

W984fe disclosed a lost court file:
`test/xaas/compat/otp29_map_update_court_test.exs`.

Found on disk, untracked (`git status` → `??`), never committed: W984ee's
work survived on disk but was never staged/committed, so it reads as "lost"
from git's view (`git log -- <path>` empty — no history). The sibling
`test/xaas/otp29_map_update_court_test.exs` (RunValidation site pin) is a
different, older file — not this court.

The file on disk already matched the W984ee receipt spec exactly: 7 tests —
5 guard-semantics pins (update/4 on both absent-key baselines + equivalence
vs raw `Map.update/4`, append/3, increment/2) + 2 census tests (real
`File.read!` scan of `lib/**/*.ex` asserting >400 files and zero raw
`Map.update(` call sites, `Map.update!` exempt).

## 2. Reconstruction

No content reconstruction was needed — the on-disk file was verified
line-by-line against `docs/sjira/v26.10.6/plans/w984ee-probe.md` §3 spec.
Work performed was verification + non-vacuity proof under lane discipline.

## 3. Non-vacuity proof (witnessed 2026-10-07)

Target: `lib/xaas/application.ex` (untouched by any lane, snapshotted first
via `cp` to /tmp; sha256 `98b8551f22025165a81dc55c65501227b9cc548a7f5c05cff6f91d927172cdf1`).

- Injected one comment line containing `Map.update(` at line 2. (Comment form
  chosen because the first attempt appending an `@doc` after `defmodule … end`
  failed to compile — the census matches comments/docs, as the W984ee probe
  itself witnessed on the guard's own moduledoc.)
- Court result: **6/7 — 1 failure**, the census test "zero raw Map.update/4
  call sites in lib/**.ex".
- Restored via the /tmp snapshot; sha256 after restore byte-identical
  (`98b8551f…cdf1`).
- Clean rerun: 7/7.

## 4. Real outputs (lane build `_build-laneW984fo`)

All runs: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fo`.

| gate | command | result |
|---|---|---|
| court | `mix test test/xaas/compat/otp29_map_update_court_test.exs` | **7/7 passed**, 0 fail, exit 0 |
| eu_ai_act census | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **1388 passed, 1 excluded**, 0 failures (≥1352 floor held; higher than W984ee's 1355 — concurrent lanes landed more) |
| mock gate | `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` | `[]` |

## 5. Standing

OS-20 xaas leg court file is NOT lost — it exists, passes 7/7, and its census
is non-vacuous (kills injected offenders, including in comments). It remains
untracked until the coordinator stages/commits it:
`git add test/xaas/compat/otp29_map_update_court_test.exs`.

## 6. Cleanup

`rm -rf _build-laneW984fo` attempted 2026-10-07: **SUCCEEDED** — build root
deleted, directory gone from disk. No lease residue (unlike W984ee, whose
`_build-laneW984ee` was left for the coordinator after permission-layer denial).
