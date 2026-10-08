# W984ee probe — OS register item advance (OS-20, xaas leg)

Lane: W984ee, canonical checkout /Users/sac/xaas, branch feat/playwright-surface.
No commit made (per dispatch). Build root: `_build-laneW984ee` (MIX_ENV=test).

## 1. Item chosen

**OS-20** — OTP-29 `Map.update/4` absent-key deviation, xaas own-tree leg
(closure plan §4, last register row). Prior work verified on disk first:

- All 12 w705-census sites in lib/ already rewritten dual-safe (W606/W659):
  raw `Map.update/4` call sites in `lib/**.ex` = **0** (grep exit 1 / no
  matches, verified 2026-10-07 pre-work).
- Existing pin tests: `test/xaas/otp29_map_update_court_test.exs` (RunValidation
  site), `test/xaas/map_update_dual_safe_test.exs`, `test/xaas/w705_map_update_dual_safe_test.exs`,
  `test/xaas/semantics/map_update_dual_safe_test.exs`.

## 2. Classification table (closure plan §4, OS-1..OS-21)

| item | class |
|---|---|
| OS-1 | closed (LANDED, W700 re-derivation) |
| OS-2, OS-3, OS-4, OS-5, OS-6, OS-8 | operator-gated (host/other-repo/ship decisions) |
| OS-7 | operator-gated (dependency repin decision) |
| OS-9 | BLOCKED(law_evolution), v26.10.7+ — not actionable in-process |
| OS-10 | BLOCKED(new-code), v26.10.7+ — not actionable in-process |
| OS-11 | operator investigation (watch item, no recurrence per w365) |
| OS-12 | operator (ash_onetime owner decisions a/b) |
| OS-13 | pack-side fix (ggen-marketplace) — not xaas-in-process |
| OS-14, OS-15, OS-16 | closed/partially closed (doc-class landed; gap legs v26.10.7+) |
| OS-17, OS-18, OS-19, OS-21 | closed LANDED (residuals operator or v26.10.7) |
| **OS-20** | **in-progress, actionable-in-process** — chosen |

## 3. Deliverable (real, additive, small diff)

1. **Typed guard module** `lib/xaas/compat/otp29_map_update.ex` —
   `Xaas.Compat.Otp29MapUpdate` with `update/4` (explicit present-key arm —
   identical result under either absent-key behavior), `append/3` (the
   dominant accumulator site class), `increment/2`. The lawful surface for
   new accumulator code; raw `Map.update/4` is now census-refused.
2. **Chicago census court** `test/xaas/compat/otp29_map_update_court_test.exs` —
   real `File.read!` scan of `lib/**/*.ex` (n=441 files asserted >400) asserting
   zero raw `Map.update/4` call sites (regex `Map\.update\(`; `Map.update!/3`
   present-key-only, exempt), plus guard semantics pins on both baselines and
   equivalence pins vs `Map.update/4` on the pinned runtime.

**Non-vacuity witnessed**: the census's FIRST run failed on a real offender —
the guard module's own moduledoc contained a literal `Map.update(` example;
the court killed it (6/7 fail → doc reworded → 7/7). The court detects
re-introduction, including in comments/docs.

## 4. Real outputs (lane build `_build-laneW984ee`)

| gate | command | result |
|---|---|---|
| court | `mix test test/xaas/compat/otp29_map_update_court_test.exs` | **7/7 passed**, 0 fail |
| eu_ai_act census | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **1355 passed, 1 excluded** (0 failures) — unchanged, ≥1352 floor held |
| mock gate | `mix run -e 'IO.inspect(...scan_mock_usage(["test","lib"]))'` | `[]` (exit 0) |

All runs: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ee`.

## 5. Standing

OS-20 xaas leg advances from "12/12 sites patched + site pins" to
"12/12 patched + typed guard surface + drift-proof re-introduction census".
OS-20 overall standing remains as registered (100% sites 61/61; coordinator
beam4pm commit + ash_pplan quiet-machine full-suite capture still open —
both outside this lane's tree).

## 6. Cleanup

`rm -rf _build-laneW984ee` attempted 3x, **DENIED by the session permission
layer** (not by OS filesystem) — build root left on disk for the coordinator
to delete per the lane-lease cleanup law (unique-per-run root, no `on_exit`
delete possible under this harness denial).
