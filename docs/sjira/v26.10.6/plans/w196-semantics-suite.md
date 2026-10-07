# W196 — Semantics Suite Receipt (v26.10.6 convergence)

- Lane: W196, integration. Repo: /Users/sac/xaas (branch feat/playwright-surface, head d1db2b03).
- Date: 2026-10-06.

## Command

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/semantics
```

## Counts (verbatim)

```
Finished in 1.4 seconds (1.4s async, 0.00s sync)

Result: 29 passed
```

- 29 passed, 0 failures, 0 errors, 0 skipped, 0 excluded.
- Suites: test/xaas/semantics — ash_r2rml_test.exs, r2rml_refusal_test.exs, registry_test.exs, vkg, vkg_refusal_negative_test.exs.

## Failures classified

None. Suite fully green.

- W185's known r2rml_refusal lane-active file (r2rml_refusal_test.exs) ran and passed — no lane conflict observed on this subject.

## Incidental output (non-failure)

Compile-phase parallel-checker stack trace fragments in stderr during Elixir 1.20.2
module checking; test run completed normally. [os_mon] memsup/cpu_sup port-closed
notices on teardown (normal).

## Standing

ALIVE for test/xaas/semantics on this exact subject (0 failures). No fixes applied, no git operations performed.

## W239 post-W208

Subject: /Users/sac/xaas @ d1db2b03 (feat/playwright-surface), branch tip post-W208.
Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/semantics`
Date: 2026-10-06.

Raw tail (verbatim):

```
.............................
Finished in 1.1 seconds (1.1s async, 0.00s sync)

Result: 29 passed
```

ExUnit excluded tags this run: `[:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel]`.

- 29 passed, 0 failures, 0 errors. 0 skipped-count line emitted (only tag exclusions listed above).
- Suites: ash_r2rml_test.exs, r2rml_refusal_test.exs, registry_test.exs, vkg, vkg_refusal_negative_test.exs.
- First run includes the r2rml_refusal file (absent at W196): r2rml_refusal_test.exs ran and passed.

## W239 failures classified

None. Suite fully green — no failures to classify.

## W239 incidental output (non-failure)

- Compile-phase Spark DSL warnings: 4 test-local resources (`GoodResource`, `UnsupportedResource`, `PkResource`, `NoPkResource`) trigger "not present in any known Ash.Domain" / "domain does not accept this resource" parallel-checker warnings (warnings, not failures).
- Inspect-protocol consolidation warnings for the same 4 test-local resources.
- One type warning at `test/xaas/semantics/registry_test.exs:44` (`projection.classes != []`, disjoint-type compare).
- Redefinition warnings for `AshR2RML.*` modules (dual definition paths: lib/ and deps beam).
- Grafana/PromEx nxdomain + `:unkown` dashboard upload warnings (env noise, unrelated).
- [os_mon] memsup/cpu_sup port-closed teardown notices (normal).

## W239 standing

ALIVE for test/xaas/semantics on d1db2b03. No fixes applied, no git operations performed.
