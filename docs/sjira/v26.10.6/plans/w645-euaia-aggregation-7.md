# W645 — EU AI Act Aggregation Rerun at the Fully-Deepened Tree (lane W645)

- **Subject**: /Users/sac/xaas @ feat/playwright-surface (ONE canonical checkout), private build root `_build-laneW645`
- **Date**: 2026-10-06
- **Scope**: aggregation rerun after W616 (Title I+II deepening), W623 (Title III deepening), W626c (Titles IV–XIII deepening + Art-56/Art-73 additions) all landed.

## 1. Green gate (open gaps excluded)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW645 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
```

**Result: GREEN — 1112 passed, 5 excluded, exit 0.**

## 2. Honest census (open gaps included)

Same command without `--exclude eu_ai_act_open_gap`. Run three times; the stable failure set is the 5 typed open gaps, plus a rotating flake population:

| run | total | failed | stable open-gap | flake extras |
|---|---|---|---|---|
| A (census) | 1117 | 5 | 5 | 0 |
| B (census) | 1117 | 10 | 5 | 5 |
| C (2-min retry) | 1118 | 6 | 5 | 1 |

(Total moved 1117 → 1118 between runs B and C: a sibling lane landed one test on the shared tree mid-session.)

### 2.1 Stable typed open-gap set — 5 (deterministic, tagged `eu_ai_act_open_gap`)

| title | article | location | typed reason |
|---|---|---|---|
| title_i | Art 4.1 (AI literacy) | test/eu_ai_act/title_i_test.exs:604 | GAP(NO_AI_LITERACY_SURFACE) |
| title_iii | Art 8.1 | test/eu_ai_act/title_iii_test.exs:1060 | no implemented seam |
| title_iii | Art 27.1.b | test/eu_ai_act/title_iii_test.exs:1060 | deployer-side duty, no seam |
| title_iii | Art 27.1.e | test/eu_ai_act/title_iii_test.exs:1060 | deployer-side duty, no seam |
| title_iii | Art 27.1.f | test/eu_ai_act/title_iii_test.exs:1060 | deployer-side duty, no seam |

**Per-title open-gap attribution: title_i = 1, title_iii = 4, title_ii / title_iv_v / title_vi_xiii / counterfactual / smoke = 0.**
(The earlier ≤24 expectation was stale; count real = 5.)

### 2.2 Flake population (session finding, NOT fixed — write contract limits this lane to this file)

Six distinct tests failed nondeterministically across runs; failure shape identical every time: expected `{:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}`-class refusal, got `{:ok, :admitted}`:

- title_iv_v: EUAI-ACT 50.5 (run B), 55.1.d (run C) — via the shared EVIDENCED harness at `test/eu_ai_act/title_iv_v_test.exs:422` (`Xaas.EUAIAct.TitleIVV.Deepenings.deepening(id)` spliced call)
- title_ii: 5.1.e ×2 (`title_ii_test.exs:73`, `:357`) — run B
- title_i: 3.39 (`title_i_test.exs:526`) — run B
- counterfactual: Art 5(1)(e) workplace refusal (`counterfactual_test.exs:161`) — run B

### 2.3 Flake mechanism (diagnosed, not repaired)

`test/eu_ai_act/counterfactual_test.exs:498` runs `Application.put_env(:xaas, :declared_metrics_root, empty_root)` inside an **async** ExUnit suite. Async tests run concurrently on one BEAM and share Application env; the `on_exit` restore is not concurrency-safe. Any admission test in flight while the env is perturbed observes the degraded state and admits where it should refuse. Each census run samples the race window, which explains the rotating failure set (A: 0 extras — the window was missed; B: 5; C: 1).

**Recommended fix (for the owning lane, not W645):** run the `declared_metrics_root` intervention test with `async: false`, or move the env swap behind a global-mode lock / `ExUnit` `:global` group so the window cannot overlap admission tests.

## 3. Verdict

- **SUITE-GREEN at the deepened tree**: yes — gate (open gaps excluded) is fully green: 1112 passed, 5 excluded, exit 0.
- **EVERY-LINE-TESTED**: yes for every non-open-gap corpus line, with one qualification: the 6-test emotion/cybersecurity-refusal population is **order-dependent flaky** (mechanism above). They passed in the gate run but must not be claimed deterministic until the async-env race is fixed.
- **Open gaps: 5 typed** (title_i 1, title_iii 4) — all honest, deterministic, `flunk("OPEN_GAP: …")` with typed reasons.

## 4. Receipt fields

- **Exact subject**: feat/playwright-surface working tree, checkout /Users/sac/xaas (no SHA pinned — shared tree, sibling lanes landing concurrently; census totals 1117→1118 mid-session evidence this).
- **Commands/exits**: gate exit 0 (1112 passed / 5 excluded); census exit 2 on every inclusive run (expected — typed open gaps present).
- **Verification ladder**: narrow (this suite) — no broader run; MIX_BUILD_ROOT=_build-laneW645 private build root throughout.
- **Transport failures**: none (no compile/toolchain failures; the run-1 foreground timeout was duration only — the run completed in background).
- **Session-introduced**: nothing; W645 wrote only this receipt file. The flake (2.2/2.3) is pre-existing, first witnessed this session.
- **Standing**: SUITE-GREEN (gate) / PARTIAL (census — 5 typed open gaps are the honest state; flake population diagnosed, repair owned elsewhere).
- **Falsifier for the flake fix**: a census run of 3+ consecutive green inclusive runs (0 flake extras) after the env-swap is serialized.
