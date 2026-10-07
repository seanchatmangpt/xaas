# W635 — EU-AI-Act wave aggregation rerun (6th)

Lane: W635. Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout; build root `_build-laneW635`).

## 1. Green gate

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW635 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
```

- Exit 0. **Result: 1105 passed, 5 excluded** (random seed; first run, 3.2s).
- Seed-0 rerun: `Result: 1106/1107 passed, 5 excluded` — 1 failure, NOT an open-gap test:
  `Xaas.EuAiAct.CounterfactualTest` "Art 14(4)(a) positive: full attributions yield
  counterfactual_available true..." (`test/eu_ai_act/counterfactual_test.exs:854`).

## 2. Honest census (no --exclude)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW635 \
  mix test --include eu_ai_act test/eu_ai_act/
```

- `Result: 1106/1112 passed` — 6 failures.
- Typed open-gap failures (5, all tagged `eu_ai_act_open_gap`, all in
  `Xaas.EUAIAct.TitleIIIOpenGapsTest` except the first):
  1. Art 4.1 — OPEN_GAP (`TitleIOpenGapsTest`)
  2. Art 8.1 — OPEN_GAP (`TitleIIIOpenGapsTest`)
  3. Art 27.1.b — OPEN_GAP
  4. Art 27.1.e — OPEN_GAP
  5. Art 27.1.f — OPEN_GAP
- Sixth failure is NOT an open gap: `Xaas.EuAiAct.CounterfactualTest` Art 14(4)(a) positive
  (`counterfactual_test.exs:854`, assertion at :880). Order-dependent (passes under random
  seed, fails under `--seed 0`). Assertion shape defect: `assert %{name: :consent_ok,
  verdict: :pass, shapley: 0.0} in briefing.per_check_causes` — elements in
  `per_check_causes` carry an extra `refusal: nil` key, so map equality under `in` fails
  when the case list includes `scope_ok`; latent test-side brittleness, not a new open gap.

## 3. Census history

- W605 baseline: 19 open gaps; W547 (overlap): 24; W607 flipped 5; W623 title_iii
  deepening, W624 extension, W531 loop landed since.
- Current real count: **5 typed open gaps** (down from 19 at W605).

## 4. Verdict

- Green gate: **GREEN** on the mandated command (exit 0, 1105 passed / 5 excluded).
- Census: 6 total failures; **5 real typed open gaps** (Art 4.1, 8.1, 27.1.b/e/f — Title III
  FUI/registration-content cluster) + 1 seed-order-dependent test-shape flake in
  `counterfactual_test.exs` (not an open gap; flagged for the owning lane, no write made —
  contract limits this lane to this file).
- Standing: PARTIAL_ALIVE — green with open gaps excluded; the 5 Title III open gaps remain
  the live frontier.
