# W984en — Unclaimed-family probe: Xaas.Chicago family

Date: 2026-10-07 · Lane: W984en · Branch: feat/playwright-surface · NO COMMIT (lane contract)

Subject: `/Users/sac/xaas` @ working tree (branch `feat/playwright-surface`, HEAD 32b72c4f + in-flight tree)

## Family census — lib/xaas/chicago/*.ex (7 modules)

| module | test-tree evidence | disposition |
|---|---|---|
| `Xaas.Chicago.Case` | `consumer/chicago_load_test.exs` (fetch/unknown/request_from_case) | covered |
| `Xaas.Chicago.Court` | `consumer/chicago_court_test.exs` (23 tests; all 9 refusal atoms asserted exercised) | covered |
| `Xaas.Chicago.Layer` | `layer_deepening_test.exs` (W984dq8, in-flight sibling lane — untouched, disjoint) | covered (sibling lane) |
| `Xaas.Chicago.Projection` | `consumer/chicago_load_test.exs` covers most identity laws; **missing-key and shape-clause branches were unexercised** | partially covered → courted here |
| `Xaas.Chicago.RenderTask` | `consumer/chicago_render_task_test.exs` (absent pack, no manifest, fail/unstable/invalid render, stable copy) | covered |
| `Xaas.Chicago.Subject` | positive `matches?` only; **negative branches unexercised** | partially covered → courted here |
| `Xaas.Chicago.View` | `consumer/chicago_view_test.exs` + `drill_down_live_test.exs` | covered |

## Court landed

`test/xaas/chicago/family_court_w984en_test.exs` — 12 tests, zero mocks, real loader
over real mutated files (single-field mutation of the committed machine fixture = the
mutation falsifier per test):

- Projection missing-key refusals: `:subject_missing`, `:projection_type_missing`,
  `:generator_identity_missing`, `:source_digests_missing`
- Shape clauses: `:not_object`, `{:root_goal_invalid, :absent}`,
  `{:layer_set_invalid, :empty}`, `{:layer_set_invalid, :not_array}`,
  `{:case_set_invalid, :not_array}`, `{:layer_invalid, id}` (numeric status)
- Subject negative branches: `matches?/1` with `nil`, integer, drifted literal;
  `literal/0` identity pin

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984en \
  mix test test/xaas/chicago/family_court_w984en_test.exs
→ 12 passed, 0 failures, exit 0
```

Mock gate: `scan_mock_usage(["test", "lib"])` → `[]` (expect met).

## Disjointness

Only new file: the court. In-flight sibling `test/xaas/chicago/layer_deepening_test.exs`
(W984dq8) untouched; no lib/ changes made.

## Cleanup

`rm -rf _build-laneW984en` — DENIED (permission system refused the rm). The lane
build root remains on disk at `/Users/sac/xaas/_build-laneW984en` and must be
reclaimed by the coordinator (fanout cleanup law).
