# W962b — Open-Gap Tag Reconciliation (Executed)

- Date: 2026-10-07
- Lane: W962b, xaas v26.10.6 campaign, branch `feat/playwright-surface`, canonical checkout `/Users/sac/xaas`
- Executes the reconciliation W962 was dispatched for (W962 verdict was UNKNOWN — its lane never landed).
- Scope: writes only `test/eu_ai_act/` (2 tag fixes) + this receipt. No commit (coordinator owns commits).

## 1. Tag-site census (static, on-disk reads)

| site | kind | tests generated today |
|---|---|---|
| `test/eu_ai_act/title_i_test.exs:577` (`TitleIOpenGapsTest`) | module-level `@moduletag :eu_ai_act_open_gap` | **0** — `@gap_details` map is empty (4.1 flipped EVIDENCED by W648b); `gap_ids = []` |
| `test/eu_ai_act/title_iii_test.exs:1133` (`TitleIIIOpenGapsTest`) | module-level | **0** — `Lines.open_gaps() == []` (8.1 closed; all Title III lines evidenced/not_applicable) |
| `test/eu_ai_act/title_vi_xiii_test.exs:803` (`TitleVIXIIIOpenGapsTest`) | module-level | **0** — `Lines.open_gaps() == []` (27.1.b/e/f, 73.x, 99.4.e all closed/reclassified) |
| `test/eu_ai_act/title_iv_v_test.exs:451` | per-test `@tag :eu_ai_act_open_gap` | **1** — EUAI-ACT 49.3, `flunk("OPEN_GAP: ...")` by design |

Every generated open-gap test in the suite is a `flunk("OPEN_GAP: ...")` marker. Zero tests carry an
accidental open-gap tag on a passing unrelated assertion → **no tag removals** in that class.

## 2. The 1-vs-34 anomaly, resolved (W935b's flagged discrepancy)

Root cause is ExUnit filter semantics, not tags:

- `test/test_helper.exs` default-excludes `:eu_ai_act` (and NOT `:eu_ai_act_open_gap`).
- The census invocation W821/W935b used, `mix test test/eu_ai_act --include eu_ai_act_open_gap`,
  still runs **untagged** tests. 33 tests in two modules that lacked `@moduletag :eu_ai_act`
  (`counterfactual_test.exs` → `Xaas.EuAiAct.CounterfactualTest`, and `airo_grounding_test.exs` →
  `Xaas.EuAiAct.AiroGroundingTest`) therefore ran in that invocation, producing "34 collected".
  The 33 were never open-gap-tagged; W935b's "34 open-gap-tagged" was a misattribution.
- The single real open-gap-tagged test is 49.3, and it is exactly the "1 intentional OPEN_GAP flunk"
  W935b reported (reproduced this lane: 33/34 passed, the 1 failure = 49.3 flunk).

## 3. DEFECT verdict and fix

DEFECT (missing-tag class, the inverse of the anticipated one): `counterfactual_test.exs` and
`airo_grounding_test.exs` are eu_ai_act census tests with no `:eu_ai_act` module tag — invisible to
the gated filter's tag logic and leaking into the open-gap census invocation's collected count.

Fix applied (this lane, no commit): added `@moduletag :eu_ai_act` (+ explanatory comment) after
`use ExUnit.Case, async: true` in both files. No other file touched.

## 4. After-counts (real runs, this lane)

All runs: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW962b`.

| run | command | result | exit |
|---|---|---|---|
| Before-fix census (old invocation) | `mix test test/eu_ai_act --include eu_ai_act_open_gap` | 33/34 passed, 1319 excluded, 1 failed (= 49.3 flunk) — reproduces W935b exactly | 1-flunk run (exit 1 pattern) |
| After-fix gated | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | **1352 passed, 1 excluded** | 0 |
| After-fix census | `mix test test/eu_ai_act --only eu_ai_act_open_gap` | **0/1 passed, 1352 excluded** (the 1 = 49.3 flunk-by-design; honest gap count = 1) | 0 |

Why gated stayed 1352: untagged tests run under any invocation, so the 33 were already inside the
gated 1352; the fix only changes their tag identity, not the count. Total suite = 1353 tests =
1319 `:eu_ai_act`-tagged + 33 newly tagged + 1 open-gap (49.3).

## 5. Resolved convention (closes the W935b/W969 flag; cite this in W935b's follow-up)

1. Open-gap tests carry ONLY `:eu_ai_act_open_gap` (module-level in the three OpenGaps modules,
   per-test in title_iv_v); all currently generate 0 tests except 49.3.
2. Honest gap count is obtained with `--only eu_ai_act_open_gap` (NOT `--include eu_ai_act_open_gap`,
   which also sweeps untagged tests). Today: **1** (Art. 49.3 deployer EU-database registration).
3. Gated/green run: `--include eu_ai_act --exclude eu_ai_act_open_gap` → 1352 passed, 1 excluded, exit 0.
4. Campaign-receipt citation: **1352 gated-pass + 1 open-gap-tagged = 1353 eu_ai_act tests.**
   W969's "34 open-gap-tagged" is retired as a counting artifact; W821's 1347/1348 remains stale.

## 6. Standing / residual

- W962b: **ALIVE** — real runs, exact counts, defect fixed in-tree (uncommitted).
- Census certification (w955 1c): the tag-convention caveat is closed; W926's receipt remains
  not-on-disk/UNKNOWN (unchanged, outside this lane).
- Transport note: first two mix runs this lane hit a compile error from a concurrent lane's
  in-flight untracked `lib/xaas/governance/checks/freeze_window_active.ex` (07:45 mtime, not this
  lane's file, untouched here); it compiled clean on retry and all recorded counts are from clean runs.
- Lane build root `_build-laneW962b` NOT deleted: `rm -rf` was denied by the permission system twice;
  left for coordinator cleanup per the fanout cleanup law.
- Known-stale doc fragment (not touched, out of scope): `test/eu_ai_act/README.md` line ~162 still
  names the historical gap list "4.1, 8.1, 27.1.b/e/f"; today's honest gap count is 1 (49.3).
