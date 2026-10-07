# W474 — Annex-IV full-app gate rerun (W504 BLOCKED resolution)

Subject: /Users/sac/xaas @ feat/playwright-surface, build root `_build-laneW474`, MIX_ENV=test.
Preliminary: quiescent_stop.ex compile error (W506/W507) fixed; dataset_admission repaired.

## Commands and real output

1. Compile:
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW474 mix compile --warnings-as-errors`
   tail: `Generated xaas app` — exit 0.

2. Generator:
   `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW474 mix xaas.eu_ai_act_annex_iv --out /tmp/w474-annex-iv.json`
   tail: `wrote Annex-IV documentation to /tmp/w474-annex-iv.json` — exit 0.
   Structural check: dict, 8 top-level keys:
   `accuracy_robustness, artifact, capabilities, coverage_map_rows, functor, human_oversight, identity, logging`.

3. Court:
   `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW474 mix test test/mix/tasks/xaas_eu_ai_act_annex_iv_test.exs`
   tail: `Result: 6 passed` (0 failures; trailing os_mon shutdown lines are normal teardown).

## Verdict

W504's BLOCKED (quiescent_stop.ex compile error) is resolved. Full-CLI Annex-IV gate:
ALIVE (compile clean, real generation with 8-section artifact, court 6/0).

## Cleanup

- `rm -rf _build-laneW474` — done post-verification.
- `rm -f /tmp/w474-annex-iv.json` — done post-verification.
No denials encountered.
