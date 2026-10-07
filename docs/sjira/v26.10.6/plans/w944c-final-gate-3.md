# W944c — Final Gate 3 Receipt (post-W900/W925/W897 landing)

- **Subject**: /Users/sac/xaas @ `fab56ae19051c6bc2b501e4a1d6c91312344e2c3` (feat/playwright-surface; includes SPEC-16/17 commit fab56ae1 and W902 checkout fixes present in working tree)
- **Lane**: W944c, v26.10.6 campaign
- **Toolchain**: asdf elixir via `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW944c`
- **Env noise (benign, disclosed)**: PromEx/Grafana dashboard-uploader warnings (nxdomain — no local Grafana). Test-only, did not affect results or exit codes.

## Gate 1 — Library + Conference + Governance + Graphlaw + Subscription

Command (aggregate run, seeds 453038 and 0 — both identical result):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW944c \
  mix test test/xaas/library/checkout_policy_deepening_test.exs \
           test/xaas/conference/enrollment_journey_court_test.exs \
           test/xaas/governance/export_token_deepening_test.exs \
           test/xaas/graphlaw_deepening_test.exs \
           test/xaas/billing/subscription_test.exs
```

Tail (aggregate):

```
Running ExUnit with seed: 453038, max_cases: 32
................................................................
Finished in 3.6 seconds (1.1s async, 2.5s sync)
Result: 64 passed
[exited with code 0]
```

**Result: 64 passed, 0 failures, 0 skipped (exit 0)**

Per-file counts (each file run individually, seed 0, same build root):

| File | Result |
|---|---|
| `test/xaas/library/checkout_policy_deepening_test.exs` | 13 passed |
| `test/xaas/conference/enrollment_journey_court_test.exs` | 1 passed |
| `test/xaas/governance/export_token_deepening_test.exs` | 21 passed |
| `test/xaas/graphlaw_deepening_test.exs` | 18 passed |
| `test/xaas/billing/subscription_test.exs` | 11 passed |
| **Total** | **64 passed** |

## Gate 2 — EU AI Act suite, exact counts (W665 bare-atom refusal / art50 pin flip check)

Command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW944c \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

Tail (real):

```
Running ExUnit with seed: 0 (max_cases: 32), max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act_open_gap]
...................................................................
Finished in 23.8 seconds (23.2s async, 0.6s sync)

Result: 1352 passed, 1 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[exited with code 0]
```

**Result: 1352 passed, 1 excluded (eu_ai_act_open_gap), 0 failures (exit 0)**

Note on the art50 pin: `test/eu_ai_act/art50_deepening_test.exs` ran inside this suite with zero failures — the W665 bare-atom refusal landing did not shift counts negatively; no art50 pin is currently failing or excluded beyond the single `eu_ai_act_open_gap` exclusion above.

## Gate 3 — Failure classification (x2)

**Zero failures across both gates.** Nothing to classify. No sibling compile breaks were hit; no retry was needed.

- Suite 1 (64 tests): 0 failures
- Suite 2 (1352 tests): 0 failures
- Failures ×2 re-run: N/A (vacuously stable)

## Standing

| Surface | Standing |
|---|---|
| Library checkout_policy | ALIVE (13/13) |
| Conference enrollment_journey court | ALIVE (1/1) |
| Governance export_token deepening | ALIVE (21/21) |
| Graphlaw deepening | ALIVE (18/18) |
| Billing subscription (striped) | ALIVE (11/11) |
| EU AI Act full suite | ALIVE (1352 passed, 1 excluded by explicit tag) |

## Replay

```
cd /Users/sac/xaas
git checkout fab56ae19051c6bc2b501e4a1d6c91312344e2c3   # or current HEAD of feat/playwright-surface
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w944c-replay \
  mix test test/xaas/library/checkout_policy_deepening_test.exs \
           test/xaas/conference/enrollment_journey_court_test.exs \
           test/xaas/governance/export_token_deepening_test.exs \
           test/xaas/graphlaw_deepening_test.exs \
           test/xaas/billing/subscription_test.exs
# → 64 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w944c-replay \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
# → 1352 passed, 1 excluded
```

## Cleanup

- No commits made (per lane instruction).
- Lane build root `_build-laneW944c` LEFT IN PLACE for coordinator: the lane's `rm -rf` of it was denied by the permission layer (2026-10-07). Coordinator should delete `_build-laneW944c` at integration per the lane-lease cleanup law.
- No files modified other than this receipt.
