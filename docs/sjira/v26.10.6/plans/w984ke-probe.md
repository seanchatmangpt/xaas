# W984ke — stale-comment repair: Title III CorpusLoader contract note

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` @ HEAD `b6fad269` (no commit; dirty tree with sibling lanes)
- **Fixes**: W984jo probe finding — `test/eu_ai_act/title_iii_test.exs:9` claimed
  `Xaas.EUAIAct.CorpusLoader` expects a flat `{"lines": [...]}` shape. False:
  `test/eu_ai_act/support/corpus_loader.ex` decodes `{"titles": [...]}`,
  flattening titles -> articles -> lines (`titles["articles"] -> article["lines"]`).
- **Diff**: prose-only edit to the `@moduledoc` of
  `test/eu_ai_act/title_iii_test.exs` (the stale `{"lines"}` sentence replaced
  with current truth, lane-attributed W984ke). No assertion/logic change; file
  was sibling-modified — only that comment touched.
- **Gates**:
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ke mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act`
    → `Result: 391 passed`, exit 0 (matches W984eu's 391; count unchanged).
  - Mock gate `scan_mock_usage(["test", "lib"])` → `[]`.
- **Replay**: same two commands above in the canonical checkout.
- **Standing**: ALIVE (comment now matches loader behavior on disk; suite passes).
- **Cleanup**: `rm -rf _build-laneW984ke` DENIED by permission gate; build root
  `_build-laneW984ke` left on disk — coordinator to clean per fanout cleanup law.
- NO COMMIT (coordinator owns transitions).
