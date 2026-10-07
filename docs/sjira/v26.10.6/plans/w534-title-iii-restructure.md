# W534 — Title III suite restructure (W525 two-module pattern)

Lane: W534 (EU-AI-Act wave) · Repo: `/Users/sac/xaas` @ `feat/playwright-surface` · Date: 2026-10-06

## Defect (W525's observed shape)

W523's single-module `test/eu_ai_act/title_iii_test.exs` tagged OPEN_GAP tests
per-test with `@tag :eu_ai_act_open_gap` while the module carried
`@moduletag :eu_ai_act`. ExUnit resolves includes OVER excludes, so under the
green-gate command `--include eu_ai_act --exclude eu_ai_act_open_gap` the 91
gap tests were resurrected and flunked (91/391 failing, observed 2026-10-06).

## Change (structure only)

Restructured to W525's solved shape (mirrors `title_vi_xiii_test.exs`):

- `Xaas.EUAIAct.TitleIII.Lines` — compile-time substrate: corpus load +
  verdict mapping (`evidenced/0`, `not_applicable/0`, `open_gaps/0`,
  `reclass_evidenced/0`), shared by both test modules.
- `Xaas.EUAIAct.TitleIIITest` — EVIDENCED + NOT_APPLICABLE tests,
  `@moduletag :eu_ai_act`.
- `Xaas.EUAIAct.TitleIIIOpenGapsTest` — OPEN_GAP tests (flunk by design),
  carrying ONLY `@moduletag :eu_ai_act_open_gap` (deliberately no
  `:eu_ai_act`), so the exclude actually holds.

Every test keeps W523's `EUAI-ACT <line_id>` id and verdict logic; only the
module structure changed.

## Concurrency note (mid-flight merge)

While this lane ran, W532/W535 classification extensions (evidence additions,
`not_applicable_map`, `reclass_map`, `reclass_evidenced`) landed in the same
file on top of the restructure. Two residues were reconciled without touching
their verdict semantics:

- The new `not_applicable_map` values were written as 1-tuples
  (`{"reason"}`); a 1-tuple is not valid AST and broke compilation at
  `unquote(detail)`. Fixed by unwrapping at the single consumption point
  (`elem(na, 0)` in `Lines.compute/0`).
- Green/honest counts therefore moved from W523's 300/391 to the current
  376/391 (reclassifications shrink the gap inventory to 15).

## Verification (real runs, `_build-laneW534`)

| direction | command | result |
|---|---|---|
| green gate | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW534 mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/title_iii_test.exs` | `Result: 376 passed, 15 excluded` |
| honest run | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW534 mix test --include eu_ai_act test/eu_ai_act/title_iii_test.exs` | `Result: 376/391 passed` — `Failed: 15 tests` (all `OPEN_GAP`, Arts 8.1/26/27) |

Note: the bare `mix test` default excludes `:eu_ai_act` (W526 wiring in
`config/test.exs`), so the honest direction is `--include eu_ai_act` without
the gap exclude; the exclusion list was confirmed from the run header
(`Excluding tags: [:stress, …, :eu_ai_act]`).

## Standing

ALIVE — restructure verified in both directions on the exact subject
(xaas @ feat/playwright-surface, worktree state 2026-10-06, `_build-laneW534`).
