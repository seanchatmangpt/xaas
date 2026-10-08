# W984ha — Mutation Non-Vacuity Audit #2 over Later Landed Courts

Lane: W984ha · Date: 2026-10-07 · Branch: feat/playwright-surface (no commits, no stash)
Method per `docs/sjira/v26.10.6/plans/w984ek-probe.md`: FILE-SWAP baseline only
(`git show HEAD:<file>` snapshot + `cp` back), one surgical lib mutation at a time,
targeted court run, `cmp`-verified byte-identical restore, post-restore green
confirmation. No `git stash` at any point.

Subjects: 06fed7b2 (sjira family + a2a courts), 1ac2ad42 (sa2a authority repair),
e49d7033 (compat/audit-chain/oversight/postmarket/operations/route/marketplace courts),
5855fd02 (security typed repair).

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ha`.
Fresh lane root compile: EXIT=0 ("Generated xaas app").
EU-AI-Act courts require `--include eu_ai_act` (tag-excluded by default in test_helper
exclusion list; run without it they report "0 tests, 3 excluded" — a green lie).

## Baselines (before any mutation)

| Court | Result |
|---|---|
| test/sa2a/changes/execute_deepening_test.exs | EXIT=0, 3 passed |
| test/xaas/security_parsing_robustness_court_w984ej_test.exs | EXIT=0, 11 passed |
| test/xaas/sjira/family_court_w984eo_test.exs | EXIT=0, 26 passed |
| test/eu_ai_act/art26x_postmarket_deepening_test.exs (--include eu_ai_act) | EXIT=0, 3 passed |
| test/xaas/marketplace/family_court_w984fi_test.exs | EXIT=0, 4 passed |
| test/eu_ai_act/art14x_oversight_deepening_test.exs (--include eu_ai_act) | EXIT=0, 3 passed |

## Mutation Matrix

| # | Court (subject) | Test file | Mutated lib file | Mutation | Before | During | After |
|---|---|---|---|---|---|---|---|
| M1 | sa2a authority repair (1ac2ad42) | test/sa2a/changes/execute_deepening_test.exs | lib/xaas/sa2a/changes/execute.ex | dropped `authority: authority(verdict, req)` from Bridge.execute opts (pre-repair mutant: DO call rides with no authority evidence) | EXIT=0, 3 passed | EXIT=2, 2/3 passed | EXIT=0, 3 passed |
| M2 | security typed repair (5855fd02) | test/xaas/security_parsing_robustness_court_w984ej_test.exs | lib/xaas/security.ex | removed `defp atomize(v) when not is_binary(v) and not is_nil(v), do: v` typed pass-through clause (wrong-JSON-type → FunctionClauseError again) | EXIT=0, 11 passed | EXIT=2, 10/11 passed | EXIT=0, 11 passed |
| M3 | sjira rate-limit clamp (06fed7b2) | test/xaas/sjira/family_court_w984eo_test.exs | lib/xaas/sjira/rate_limit.ex | (a) removed piped `\|> max(0)` in delay_ms; (b) removed inner `max(epoch*1000 - now_ms, 0)` clamp in reset_after_ms | EXIT=0, 26 passed | (a) EXIT=0, 26 passed — SURVIVED; (b) EXIT=0, 26 passed — SURVIVED | EXIT=0, 26 passed |
| M3c | sjira rate-limit clamp, compound | same | same | both clamps removed simultaneously (mutually-masking redundant pair) | — | EXIT=2, 25/26 passed ("past epoch clamps to zero delay" fails) | EXIT=0, 26 passed |
| M4 | postmarket truncation refusal (e49d7033) | test/eu_ai_act/art26x_postmarket_deepening_test.exs | lib/xaas/witness/audit_chain.ex | `check_truncation/2` guard `when length(chain) < n` → `when false` (truncation-blind verify) | EXIT=0, 3 passed | EXIT=2, 2/3 passed ("26.12 short serve typed-refused" fails) | EXIT=0, 3 passed |
| M5 | marketplace ActorOrgMatches fallthrough (e49d7033) | test/xaas/marketplace/family_court_w984fi_test.nonconforming-actor tests | lib/xaas/marketplace/checks/actor_org_matches.ex | catch-all `def match?(_actor, _context, _opts), do: false` → `do: true` (deny fallthrough → ambient allow) | EXIT=0, 4 passed | EXIT=2, 2/4 passed (both non-conforming-actor denial tests fail) | EXIT=0, 4 passed |
| M6 | oversight margin gate boundary (e49d7033) | test/eu_ai_act/art14x_oversight_deepening_test.exs | lib/xaas/semantics/robust_margin.ex | boundary `margin - penalty >= 0` → `> 0` (inclusive boundary → exclusive) | EXIT=0, 3 passed | EXIT=2, 2/3 passed (boundary admit-at-penalty assertion fails) | EXIT=0, 3 passed |

## Standing Verdicts

- M1 sa2a Execute authority hop: **NON-VACUOUS** (killed by exact typed assertion)
- M2 security atomize typed pass-through: **NON-VACUOUS** (killed; crash-instead-of-typed-refusal detected)
- M3 sjira clamp, single mutants: **SURVIVED ×2** — the two clamps are a mutually
  masking redundant pair; each is individually unobservable. Compound mutant M3c
  **KILLED** → the court's clamp invariant is real, but only the *pair* is load-bearing.
  First non-vacuity finding of the audit series: a single-clamp mutation is a green lie
  in this court.
- M4 audit_chain truncation refusal: **NON-VACUOUS**
- M5 ActorOrgMatches deny fallthrough: **NON-VACUOUS** (killed by both denial tests)
- M6 RobustMargin inclusive-boundary: **NON-VACUOUS** (killed at the exact measured boundary)

5/6 courts non-vacuous by single mutation; the 6th required a compound mutant to kill
(redundant-clamp pair, lib/xaas/sjira/rate_limit.ex lines 27+52). No crash-only kills:
every kill was an exact value/typed-atom assertion.

## Tree Cleanliness

All six mutation subjects absent from `git status --short lib/` after final restore;
every restore `cmp`-verified byte-identical to the pre-mutation on-disk state (which was
itself verified equal to `git show HEAD:` before each mutation — no other lane held
in-flight edits on any of the six subjects).

Cleanup: `rm -rf _build-laneW984ha` SUCCEEDED — lane build root removed (unlike W984ek,
no permission denial).

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ha
# baseline the six courts (eu_ai_act two with --include eu_ai_act)
# apply one mutation from the matrix, run the paired court, expect EXIT=2
# restore: git show HEAD:<file> > <file> (cmp-verified), court returns EXIT=0
```

Standing: ALIVE — non-vacuity observed on exact subjects at HEAD (06fed7b2, 1ac2ad42,
e49d7033, 5855fd02), this lane, this date.
