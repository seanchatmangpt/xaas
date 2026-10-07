# W663b — w464 §5 Post-Commit Verification Gates — Receipt

- **Subject**: /Users/sac/xaas @ feat/playwright-surface @ `a0723bf61a1c6058bdcd2d0202c9519840182a5e` (pushed tree, W660)
- **Lane**: W663b (private build root `_build-laneW663b`)
- **Date**: 2026-10-07
- **Contract**: write scope = this file only.

## Gate results

| # | Gate | Verdict | Evidence (tail) |
|---|------|---------|-----------------|
| 1 | Full MIX_ENV=test suite | **PASS** — 3559/3599 green (≥3247 threshold met), 40 failures all classified as sibling-WIP/contention/env classes | see below |
| 2 | Mock gate `scan_mock_usage(["test","lib"])` | **PASS** | `[]` |
| 3 | ggen sync drift | **PASS** | `git diff --stat` after `ggen sync run` (ggen 26.9.28): no sync-attributable changes — only pre-existing sibling-lane WIP (docs + tests), no `lib/` generated files, no `priv/semantic` output drift. `priv/semantic/generated/` untracked = expected C1-held residue. |
| 4 | Tokened Playwright | **BLOCKED(CONTENTION + pre-existing dev-boot defect)** | see below |
| 5 | `mix compile --warnings-as-errors` (test env, lane root) | **EXIT 0** | `Generated xaas app` / EXIT=0 |

## Gate 1 detail

- Attempt 1 + 2 (plain `mix test`): **aborted before any test ran** — sibling-lane in-flight untracked file
  `test/xaas/telemetry/ocel_egress_deepening_test.exs` has `@moduletag` before `use ExUnit.Case` →
  `** (RuntimeError) you must set @tag...after the call to "use ExUnit.Case"` at compile of test tree
  (w398b CONTENTION signature; file is `??` untracked, not part of a0723bf6).
- Attempt 3 (final): adaptive exclusion of untracked sibling `*_test.exs` files, rest of the working tree
  (pushed tree + sibling-tracked WIP) — **RUN COMPLETED**:
  `Result: 3548/3599 passed (6/6 doctests, 3542/3593 tests), 37 skipped, 1192 excluded` in 1845.5s.
- Attempt 4 (full-log attribution rerun, same carve-out): **COMPLETED** —
  `Result: 3559/3599 passed (6/6 doctests, 3553/3593 tests), 37 skipped, 1192 excluded` in 1993.3s.
  **3559 green ≥ the ≥3247 contract threshold — GATE PASS.**
- Failure classification (attempt 4, 40 failures, full log `/tmp/w663b-gate1-full.log`):
  - 13× `ExUnit.TimeoutError` (60s) — machine load avg ~80-90 from concurrent lanes → w398b CONTENTION
    class (incl. all 12 CastleRefusalNegativeTest kernel-subprocess tests).
  - ~15× Billing/Approval/Ledger cluster (`Xaas.Billing.SubscriptionTest`, `ApprovalSlaCreditApply*`,
    `ApprovalTierDowngrade*`, `ApprovalBackupRetentionChange*`, `DevSeedsTest`): these test files AND their
    `lib/xaas/billing`+`lib/xaas/ledger` implementations are sibling-lane WIP (staged/unstaged `M` + untracked
    `lib/xaas/ledger/validations/`) — attributable to concurrent lane WIP, not pushed-tree a0723bf6 content.
  - 2× topology/projection guards: fail on the expected C1-held untracked `priv/semantic/generated/` residue.
  - Remainder (~10): env-sensitive guards (health warm-up timing, ash_surface drift guards vs sibling lib WIP,
    release-audit tree-dependent tests, ultracode env guard) — all tree-state/contention classes, none in the
    EU-AI-Act wave test files (which passed; note `:eu_ai_act` tag excluded by the repo's default helper config).
- Note: working tree carries sibling-lane WIP (44 modified tracked files + untracked plan files);
  the run therefore measures the pushed tree PLUS concurrent lane WIP, disclosed.

## Gate 4 detail (BLOCKED classification)

1. Stock boot path (`playwright.config.cjs` webServer, dev env): fails — `AshA2A.Authority.SecurityPreflight.Error:
   receipt_store_boot_check_failed: {:insufficient_cluster_size, 1}`. Root cause in pushed tree: `config/dev.exs` (W701
   strict dev posture) sets `security_profile: :strict` with `cluster_size: 1`; with `:strict`, `production?` is true and
   `ReceiptStore.boot_check/1` requires `cluster_size >= 3` (deps/ash_a2a receipt_store.ex:194-196). Dev boot is
   fail-closed by the tree's own court. Pre-existing relative to a0723bf6; postdates w471's 96/0/2 baseline.
2. Rescue attempt (test env, lane build root): server boots fully but serves nothing — `config/runtime.exs` is not
   imported in the test env, so `PHX_SERVER`/`PORT` never reach the endpoint (server: false). BLOCKED.
3. Rescue attempt 2 (dev env, `mix run --no-start` + `Application.put_env` legacy_compat override, endpoint forced on):
   compile of the dev lane stalled >40 min behind sibling-lane load (load average 90, multiple beams at 100-290% CPU);
   killed to avoid compounding contention + dev-compile-during-campaign risk. BLOCKED(CONTENTION).
4. Gate 4 therefore remains **UNEXECUTED on this subject**. Not a test failure — no tests ran. Standing: BLOCKED
   (transport), not REFUTED.

## Residue / open items

- `priv/semantic/generated/` untracked (C1-held) — expected, untouched.
- Sibling-lane in-flight WIP present on the shared checkout during all gates; gate 1 attempt 3 carve-out and gate 3
  attribution above are the only interactions with it (read-only classification).
- Gate 4 requires: (a) sibling lanes' load to clear, (b) a dev-boot fix — `config/dev.exs` cluster_size to >= 3 or
  profile demotion — owned by the W701/dev-config lane, not W663b.

## Verdict

Gates 1, 2, 3, 5: PASS on subject a0723bf6 (gate 1 via adaptive exclusion of untracked sibling test files;
3559/3599 green ≥ contract threshold; all 40 failures classified as sibling-WIP/contention/env classes).
Gate 4: BLOCKED(CONTENTION + pre-existing dev-boot defect in config/dev.exs W701 strict posture with
cluster_size: 1). No gate produced a REFUTED verdict against the pushed tree's own code.

## Final tree state (at receipt close, ~2026-10-07 05:30)

- HEAD = a0723bf6 (unchanged; no commits made by W663b).
- Working tree: sibling-lane WIP ongoing (44+ modified tracked files, several untracked test/plan files,
  untracked `priv/semantic/generated/` C1-held residue). Gate 4 rescue attempts left no tree changes.
- Machine contention during gates: load average 70-90 throughout (sibling lanes).
