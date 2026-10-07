# W672 — Flake Adjudication: counterfactual_test.exs + title_vi_xiii_test.exs

- **Subject**: /Users/sac/xaas @ a0723bf6 (feat/playwright-surface), MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW672, pinned asdf toolchain.
- **Verdict**: **NON_REPRODUCED** for both findings, with an identified **external root cause** for the "full-dir only" pattern: concurrent lane mutation of the shared test tree aborts full-dir compilation before any test executes.
- **Standing**: PARTIAL_ALIVE (target files exonerated on this tree; full-dir adjudication BLOCKED by other lanes' in-flight files — not by the audited tests).
- **No edits made** to any test file. Lane build root `_build-laneW672` NOT deleted (rm denied; left for coordinator).

## Run matrix

### Phase 1 — untagged (default excludes active; `:eu_ai_act` tag is excluded by default per test_helper.exs)

| run | command | result |
|---|---|---|
| cf_iso_1..5 | `mix test test/eu_ai_act/counterfactual_test.exs` ×5 | 5/5 exit 0, `26 passed` each |
| tv_iso_1 | `mix test test/eu_ai_act/title_vi_xiii_test.exs` ×1 | exit 0, `0 tests, 476 excluded` (all tagged) |
| full_1..3 | `mix test test/eu_ai_act` ×3 | 3/3 exit 1 — **SyntaxError, `title_ii_deepening_test.exs:204:26`** (`{:ok, chain0 = [%r0], h0} =` — `%r0` invalid) — aborts compile before tests run |

### Phase 2 — tagged (`--include eu_ai_act`)

| run | command | result |
|---|—|---|
| cf_inc_1..5 | counterfactual isolated ×5 | 5/5 exit 0, `26 passed` each (seed 822081 + 4 more) |
| tv_inc_1..3 | title_vi_xiii isolated ×3 | 3/3 exit 0, `476 passed` each (seeds vary) |
| fullinc_1..3 | full dir ×3 | 3/3 exit 1 — **ArgumentError, `art86_rights_deepening_test.exs:66`** (`cannot inject attribute @checks ... cannot escape #Function<...>`) |
| fullinc_4 | full dir ×1 | exit 1 — same art86 ArgumentError |

Logs: /tmp/w672_cf_iso_{1-5}.log, /tmp/w672_tv_iso_1.log, /tmp/w672_cf_inc_{1-5}.log, /tmp/w672_tv_inc_{1-3}.log, /tmp/w672_full_{1-3}.log, /tmp/w672_fullinc_{1-4}.log

## Root cause analysis

1. **Both target files pass deterministically when they actually run.** counterfactual_test.exs: 10/10 green runs (5 untagged + 5 tagged, varying random seeds, max_cases 32 async). title_vi_xiii_test.exs: 3/3 tagged runs green (476 tests each). The specific tests named in W645c (~401/864/898, Art 14(4) refusal_anatomy) use fixed idempotency keys (`stop-key-w550`, `w624-bias-key`) with empty authority that fail closed at `REFUSED_STOP_AUTHORITY` before touching the ActuationIntent ledger (`Xaas.Actuation.QuiescentStop.execute` — lib/xaas/actuation/quiescent_stop.ex); no Application-env mutation in-process (the Art 11 counterfactual arm runs in an isolated `mix run` subprocess, the W654 fix), no ETS/:rand/seed coupling, SQL-sandbox DB state only.
2. **The "fails only under full-dir" signature is a moving-tree artifact.** During this lane's window (~00:55–01:55), sibling lanes were actively writing to test/eu_ai_act/: `title_ii_deepening_test.exs` (created 01:16 with a real syntax error at 204:26 — `%r0` is not valid Elixir; fixed by its lane at 01:35) and `art86_rights_deepening_test.exs` (created 01:32, still broken at last check: `@checks` attribute holding a function value → compile ArgumentError, exonerates nothing it was blamed for). `mix test test/eu_ai_act` compiles ALL matched files; one broken sibling aborts the whole run with exit 1 and no test executes — indistinguishable from "tests failed" to a census harness recording exit codes only. title_vi_xiii_test.exs itself was modified at 01:31, mid-window. Any census run B/C difference (W662) is fully explained by which in-flight sibling file versions happened to be on disk.
3. **Additional methodological hazard found**: the `:eu_ai_act` ExUnit tag is in the default exclude list (test/test_helper.exs exclude set `[:stress, :kind, ..., :eu_ai_act]`), so `mix test test/eu_ai_act` without `--include eu_ai_act` silently runs 0 of the 476 title_vi tests while exiting 0. Any prior census evidence gathered without the include flag tested nothing in this dir.

## Recommendation to coordinator

- Adjudicate full-dir claims only from runs on a quiescent tree (all lanes' files settled) AND with `--include eu_ai_act`; otherwise exit-code-only census data is confounded twice over.
- `art86_rights_deepening_test.exs:66` (@checks escape ArgumentError) is live-broken on the tree at receipt time and will block every full-dir run until its lane fixes it — routed here for owner visibility.
- No counterfactual_test.exs fix warranted: zero defect proven; both "deterministically"-named tests observed passing 10/10.

## Falsifier for this verdict

On a quiescent tree (no sibling lane writes during the run), `mix test test/eu_ai_act --include eu_ai_act` green 3/3 would confirm; a counterfactual/title_vi failure reproducing file-isolated with a fixed seed would refute.
