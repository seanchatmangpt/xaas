# W981x — eu_ai_act census rerun (gate-number determination)

Date: 2026-10-07 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface @ 6f235905
Lane root: `_build-laneW981x` (fresh, full deps compile; left in place for coordinator).
No source files modified; no commit made.

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981x \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

## Run history

1. **Attempt 1 — BLOCKED(compile, other-lane), 0 tests executed.** Compile aborted in
   `lib/xaas/generated/regen_check.ex` (TokenMissingError, unclosed `defmodule` at line 236).
   That file was an untracked in-flight artifact of another lane (w982g), not billing
   (the parse_inline_idents billing repairs were not the blocker). Per compile-freeze SLA
   the file was left to its owner; after ~10 min the owner had completed it (file ends with
   proper `end end`). This is a compile-abort, not a failure count.
2. **Attempt 2 — ran clean.** Full tail:

```
Finished in 6.4 seconds (6.1s async, 0.2s sync)

Result: 1352 passed, 1 excluded
```
   Exit 0. Zero failures — no real-gap/flake classification required, no rerun needed.
   Full log preserved at `/tmp/w981x-run2.log`.

## Gate-number determination: **1352, not 1385**

W981v projected +33 newly visible tests (airo_grounding 7 + counterfactual 26) from the
ba9703fb moduletag fix, giving a projected 1385. The actual run yields **exactly
1352 passed / 1 excluded — identical to the certified fab56ae1 census (1352/1)**. Therefore:

- The certified 1352 already included the airo_grounding/counterfactual tests (they were
  counted in a prior ungated census; ba9703fb's tag fix made them *gated-visible* without
  changing the total), **or** the +33 projection itself was wrong.
- Distinguishing which requires the fab56ae1 per-file breakdown, which this lane does not
  have; either way the falsifier for "gate should read ≥1385" fired: **the gate stays at
  1352 and no gate update is needed.** W981v's projection is REFUTED as stated.

## Observations (non-blocking)

- `test/eu_ai_act/support/corpus_loader.ex` triggers a `:test_load_filters` warning
  (helper, not a test module — consistent with W981v's finding).
- Ambient PromEx/Grafana nxdomain warnings (no local Grafana; pre-existing, unrelated).

## Standing

- **ALIVE** — `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
  at HEAD 6f235905 on a fresh lane build: 1352 passed / 1 excluded, exit 0.
- Gate number for the eu_ai_act census: **≥1352** (unchanged from certified fab56ae1).
- Cancellation: `_build-laneW981x` left on disk (deletion denied per lane protocol);
  coordinator to delete at integration per cleanup law.
