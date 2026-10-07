# W626 — semantics-dir convergence receipt

Repo: /Users/sac/xaas @ feat/playwright-surface. Build root: `_build-laneW626` (MIX_ENV=test).

## Command
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW626 mix test test/xaas/semantics/
```

## Tail (verbatim)
```
Finished in 1.9 seconds (1.9s async, 0.00s sync)

Result: 197/203 passed, 2 excluded
Failed: 6 tests
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

## Verdict: FINDINGS — not green-at-convergence (single cause, isolated)

197 pass, 2 excluded, 6 fail. All 6 failures are in one module:
`Xaas.Semantics.AiroVendoredPinTest` (`test/xaas/semantics/airo_vendored_pin_test.exs`,
untracked, W621b per its own moduledoc). Every other W500/W600 semantics module
(dataset_admission 6, eu_ai_act_admission 24, vulnerability_lifecycle 15, robust_margin 10,
counterfactual 9, declared_metrics 5, incident_report 6, automation_bias 8,
oversight_governance 14, admission_attribution 8, master_equation 9, ash_r2rml, etc.)
passes.

## Root cause (isolated once)
Path-resolution defect in the test module itself. From `test/xaas/semantics/`, repo root is
**three** levels up, not two:

```elixir
@repo_root Path.expand("../..", __DIR__)   # -> /Users/sac/xaas/test  (WRONG)
```

so the tests look for `/Users/sac/xaas/test/priv/semantic/airo/airo.ttl` (missing) while the
real files exist and hash correctly:

```
/Users/sac/xaas/priv/semantic/airo/airo.ttl
sha256 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469
```

— exactly the W600 verified vendor pin the test expects (`@expected_sha256` matches byte for
byte). The vendored assets are correct; only the test's `@repo_root` anchor is wrong.
Fix is one line: `Path.expand("../../..", __DIR__)`.

## Per-failure attribution
| # | Test | Attribution |
|---|---|---|
| 1-6 | `Xaas.Semantics.AiroVendoredPinTest` (exists / sha256 / classes / properties / README, x2 path variants) | **Lane W621b** — new test-module path bug, not a convergence break between landed modules. No sibling module affected. |

## Cleanup note
`_build-laneW626/` is a lane lease — coordinator to delete at integration.
