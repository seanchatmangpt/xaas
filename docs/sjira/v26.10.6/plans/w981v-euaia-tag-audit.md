# W981v — eu_ai_act pre-census tag audit

Date: 2026-10-07 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface @ 6f235905
Method: read-only audit + git history vs fab56ae1. No source files modified; no commit made.

## Verdict

**0 open violations.** All 17 `.exs` test files under `test/eu_ai_act/` carry the
`@moduletag :eu_ai_act` (or, for the three gap-modules and the per-line generator in
title_iv_v, the documented open-gap-only tagging design). The 2 files W962b flagged as
missing the moduletag — `airo_grounding_test.exs` and `counterfactual_test.exs` — were
already fixed at HEAD in commit **ba9703fb** (W907 hardening commit, "W962b tag reconcile"
comments present in both files). No fix required by this lane.

## Per-file tag table

| file | moduletag | other tags (non-exclusionary) |
|---|---|---|
| airo_grounding_test.exs | :eu_ai_act | — |
| art15_deepening_test.exs | :eu_ai_act | — |
| art50_deepening_test.exs | :eu_ai_act | — |
| art73_chain_deepening_test.exs | :eu_ai_act | — |
| art86_rights_deepening_test.exs | :eu_ai_act | — |
| art99_enforcement_deepening_test.exs | :eu_ai_act | — |
| counterfactual_deepening_test.exs | :eu_ai_act | — |
| counterfactual_test.exs | :eu_ai_act | — |
| eyerun_wire_deepening_test.exs | :eu_ai_act | @tag :w706_admitted / :w706_refused_field / :w706_malformed / :w706_exit_discipline (additive, per-test) |
| not_applicable_completeness_test.exs | :eu_ai_act | — |
| smoke_test.exs | :eu_ai_act | — |
| title_i_test.exs | :eu_ai_act (+ :eu_ai_act_open_gap gap-module, deliberate) | — |
| title_ii_deepening_test.exs | :eu_ai_act | — |
| title_ii_test.exs | :eu_ai_act | per-test :eu_ai_act_not_applicable on one test (additive) |
| title_iii_test.exs | :eu_ai_act (+ gap-module carrying ONLY :eu_ai_act_open_gap, deliberate: ExUnit includes-over-excludes would resurrect gap tests) | — |
| title_iv_v_test.exs | no moduletag — per-test `@tag :eu_ai_act` / `:eu_ai_act_open_gap` from the verdict comprehension (deliberate; documented at lines 229-232) | — |
| title_vi_xiii_test.exs | :eu_ai_act (+ open_gap gap-module, deliberate) | — |

(`support/corpus_loader.ex` is a helper, not a test module — no tag required.)

## Census invariant (1): expected-pass count model

Static grep of `^\s*test "` yields only **146 literal blocks**; the certified 1352 comes
predominantly from `for ... do test ... end` comprehensions (per line_id in the title
suites), so static counting cannot certify the run total. Preferred method used instead —
**git history since fab56ae1**:

- Exactly one commit touched `test/eu_ai_act/` since fab56ae1: **ba9703fb**, +11 lines
  across 2 files, consisting solely of comments + the two `@moduletag :eu_ai_act` lines.
  **Zero test blocks added or removed since the census.**
- Therefore per-file test-block counts are unchanged since fab56ae1.
- Projected census delta for `--only eu_ai_act`: **+33 tests** newly runnable
  (airo_grounding 7 + counterfactual 26), matching W962b's "33 misattributed" finding.
  These now count toward the ≥1352 gate; run total should be 1352 + 33 = **≥1385 expected**,
  not merely ≥1352 — or 1352 already included them in a prior ungated census run. Verify
  against the actual run before assuming headroom.

## Census invariant (2): exclusion-tag enumeration

- **Only documented exclusion tag present: `:eu_ai_act_open_gap`** (module-level in the
  title_i/title_iii/title_vi_xiii gap modules and per-test in title_iv_v), excluded under
  `--only eu_ai_act` (ExUnit `--only` excludes all other configured excludes).
- **Zero `@tag :skip`** anywhere in test/eu_ai_act/.
- test_helper.exs exclude list ends with `:eu_ai_act` (excluded by default; included via
  `--only eu_ai_act`). No stray exclusion tags found; the only non-eu_ai_act tags in the
  tree are additive (:w706_*, :eu_ai_act_not_applicable) and do not exclude anything.

## Commands / exits

- `git log --oneline fab56ae1..HEAD -- test/eu_ai_act/` → ba9703fb only, exit 0
- `git diff fab56ae1..HEAD --stat -- test/eu_ai_act/` → 2 files, +11, exit 0
- per-file moduletag/@tag greps, exit 0
- `grep -cE '^\s*test "'` block counts, exit 0

Standing: PARTIAL_ALIVE — static/structural audit only; the ≥1352 gate itself is confirmed
only by the actual `--only eu_ai_act` census run (this lane did not run it, no build root
used).
