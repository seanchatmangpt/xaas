# W984fu — Landing Batch #4 Commit Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, base `1ac2ad42`
- Lane build root: `_build-laneW984fu` (removed at close)
- Commits (pathspec-only staging, `-F` messages):
  1. `a9056f7b` test(courts): W984fj (6 passed) + W984fg (11 passed, mock gate []) + W984eq (5 passed) courts + probes (6 files, +776)
  2. `180d4606` test(eu_ai_act): W984fc art9x (7 passed) + W984fa art15x (8 passed) + W984ec art10_2e/26_4 (3 passed) deepenings + W984eu title_iii prose + probes (6 files, +960). title_iii included because W984fl has NOT landed (no commit found).
  3. `956b772a` test: W984ep flake-fix sweep — 6 files scope-only verified (subject/org/prefix/digest-scoped shared-table reads, zero lib/ changes) + w984ep-probe.md (+197/−31)
  4. `b5615c6d` docs(sjira): W984ff w859-typed-gap-register refresh + W984fp evidence-claims-index refresh + probes (4 files, +231/−11)
- Skips:
  - W984eo court (`test/xaas/sjira/family_court_w984eo_test.exs`) — already landed at `06fed7b2`.
- Gates (this lane):
  - Mock gate: `scan_mock_usage(["test","lib"])` → `[]`, exit 0
  - Batch gate: 13 candidate files, `--include eu_ai_act` → **473 passed, 5 skipped, 0 failed**, exit 0 (`_build-laneW984fu`, pinned asdf toolchain)
- Replay:
  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fu \
    mix test --include eu_ai_act test/xaas/operations/castle_verb_court_w984fj_test.exs \
    test/xaas/runtime/family_court_w984fg_test.exs \
    test/xaas_web/controllers/residue_court_w984eq_test.exs \
    test/eu_ai_act/art9x_risk_management_deepening_test.exs \
    test/eu_ai_act/art15x_robustness_deepening_test.exs \
    test/eu_ai_act/art10_2e_art26_4_dataset_purpose_deepening_test.exs \
    test/eu_ai_act/title_iii_test.exs test/mix/tasks/xaas_self_digest_test.exs \
    test/xaas/witness/catalog_durability_test.exs test/xaas/ultracode/semantic_drive_test.exs \
    test/xaas/ultracode/semantic_wave_trigger_test.exs test/xaas/billing/fibo_revenue_actuation_test.exs \
    test/xaas/operations/autofde_planner_connector_depth_test.exs
  ```
- Standing: ALIVE for the batch; post-push fast-forward confirmed below.
