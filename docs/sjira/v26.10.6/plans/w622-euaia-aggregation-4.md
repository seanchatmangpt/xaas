# W622 — EU-AI-Act Wave Aggregation Receipt (fresh, current tree)

Lane: W622 · Repo `/Users/sac/xaas` @ `feat/playwright-surface` · build root `_build-laneW622`
Run window: 2026-10-06 22:20–23:00 local. Canonical checkout shared with live sibling lanes (W607/W608 + surfaces) landing edits during measurement — see Blockers consumed.

## 1. Green gate (Step 1)

Command (exact):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW622 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
```

Tail:

```
Finished in 2.1 seconds (2.1s async, 0.00s sync)

Result: 1100 passed, 10 excluded
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
[os_mon] memory supervisor port (memsup): Erlang has closed
```

Exit 0. **SUITE-GREEN**.

## 2. Honest census (Step 2)

Command (same, without `--exclude`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW622 \
  mix test --include eu_ai_act test/eu_ai_am/   # (typo guard: actual path test/eu_ai_act/)
```

Tail:

```
Result: 1100/1110 passed
Failed: 10 tests
```

Exit 2 — the 10 failures are exactly the `eu_ai_act_open_gap`-tagged tests (10 excluded in run 1 = 10 failed in run 2; identities match by title).

**Typed open-gap count: 10** (W605 saw 19; net −9 at this tree — W607/W608 flips plus the Art 56 NOT_APPLICABLE landings moved 9 former gaps to tested/closed states).

## 3. Per-title attribution of the 10 open gaps

| # | Test | Module |
|---|------|--------|
| 1 | EUAI-ACT 4.1 — OPEN_GAP | Xaas.EUAIAct.TitleIOpenGapsTest |
| 2 | EUAI-ACT 8.1 — OPEN_GAP | Xaas.EUAIAct.TitleIIIOpenGapsTest |
| 3 | EUAI-ACT 27.1.b — OPEN_GAP | Xaas.EUAIAct.TitleIIIOpenGapsTest |
| 4 | residual 27.1.e — OPEN_GAP | Xaas.EUAIAct.TitleIIIOpenGapsTest |
| 5 | EUAI-ACT 27.1.f — OPEN_GAP | Xaas.EUAIAct.TitleIIIOpenGapsTest |
| 6 | EUAI-ACT 74.12 — OPEN_GAP | Xaas.EUAIAct.TitleVIXIIIOpenGapsTest |
| 7 | EUAI-ACT 74.13.a — OPEN_GAP | Xaat.EUAIAct.TitleVIXIIIOpenGapsTest |
| 8 | EUAI-ACT 74.13.b — OPEN_GAP | Xaas.EUAIAct.TitleVIXIIIOpenGapsTest |
| 9 | EUAI-ACT 86.2 — OPEN_GAP | Xaas.EUAIAct.TitleVIXIIIOpenGapsTest |
| 10 | EUAI-ACT 86.3 — OPEN_GAP | Xaas.EUAIAct.TitleVIXIIIOpenGapsTest |

(Note: rows are the literal test titles; module column reproduces the census log verbatim — row 7's `Xaat.` is a typo in this receipt, the real module is `Xaas.EUAIAct.TitleVIXIIIOpenGapsTest`.)

## 4. Blockers consumed (transient sibling breakage, contract retry allowance)

Sibling lanes' mid-edit states broke compile between attempts; each resolved without my intervention:

1. `lib/xaas/semantics/airo_risk_mapping.ex:201` — SyntaxError (stray `\"`); lane rewrote the line.
2. `test/eu_ai_act/title_vi_xiii_test.exs:601` — stray `end`; lane repaired (hash 653f8a19 → 83cee13c…, later 056a4aba…).
3. `test/eu_ai_act/counterfactual_test.exs` — undefined `art72_drift_decision/2`; lane landed the function.
4. `lib/mix/tasks/xaas.release_audit.ex:351` — MismatchedDelimiterError (duplicated fragment after `end`, ~6 min at rest); owning lane repaired (c528713f → df5718a2).

Intermediate results: 49 failures → 1 failure (`title_vi_xiii_test.exs:749`, Art 99.9 NOT_APPLICABLE typed-reason assert) → GREEN, as lanes landed.

## 5. Verdict

- **SUITE-GREEN** (gate, `eu_ai_act_open_gap` excluded): 1100/1100 passed, exit 0, at tree hash of `test/eu_ai_act/` as of run — `title_vi_xiii_test.exs` @ 056a4aba705bbc61d9fdd26542f7471e45fc26ce.
- **EVERY-LINE-TESTED**: subject to the 10 typed open gaps enumerated above; full suite runs 1110 tests, 1100 pass, 10 fail tagged `eu_ai_act_open_gap` only.
- Typed open-gap census: **10** (was 19 at W605).
