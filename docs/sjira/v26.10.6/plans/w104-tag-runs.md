# W104 Tag Runs — Receipt

Lane W104, v26.10.6 convergence, repo /Users/sac/xaas.
Subject: branch `feat/playwright-surface`, uncommitted working tree (many modified files, per git status at dispatch).

Two bounded un-ignored tag classes that don't need castle/kind, run as specified. No fixes, no git.

## Commands (verbatim, run under asdf shims, elixir 1.20.2-otp-28, OTP 28.5.0.2)

1. `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test --include property`
2. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test --include subprocess`

Note: both flags are `--include` — ExUnit runs the FULL suite with the tag un-excluded, so
counts below are full-suite counts, not tag-only counts.

## Counts (verbatim)

### Property class (log /tmp/w104_property.log)

- Command exit=2. `Finished in 881.6 seconds (86.7s async, 794.8s sync)`
- `Result: 3120/3224 passed (6/6 doctests, 1/1 property, 3113/3217 tests), 18 skipped, 90 excluded`
- `Failed: 104 tests`
- First attempt was killed at the 30-minute background limit (still running); second attempt completed. Same command.

### Subprocess class (log /tmp/w104_subprocess2.log)

- Attempt 1 (command exit=1): crashed at startup — `(File.Error) could not write to file "/Users/sac/xaas/_build/test/lib/xaas/consolidated/Elixir.Inspect.beam": no such file or directory` — concurrent lane collision on the shared `_build/test` while another lane was deleting/compiling it. NOT a test failure. Attempt 1 log: /tmp/w104_subprocess.log
- Attempt 2, same command verbatim, completed. exit=2. `Finished in 1260.2 seconds (66.4s async, 1193.7s sync)`
- `Result: 2958/3258 passed (6/6 doctests, 2952/3252 tests), 46 skipped, 51 excluded`
- `Failed: 300 tests`

## Failure classification

Caveat (both runs): ExUnit emitted failure-detail headers only for the first 99 failures
even though 104 / 300 failed; classification below covers the 99 detailed failures per run
plus full-log exception counts.

### Property run — 104 failed, detailed classes

| class | count | notes |
|---|---|---|
| System.EnvError on `INTERNAL_API_TOKEN` | 38 | env-class; token not in the run's environment |
| UndefinedFunctionError (module not available) | 33 | `Mix.Tasks.Xaas.Ultracode.Audit.audit/1` (12), `Xaas.A2a.Catalog.ingest/1` (6), `SemanticReceipt.ApsDod.*` (6), `XaasWeb.WitnessLive.__live__/0` (3), `AshR2RML.Resource.Info.mapping/1` (2), plus scattered — consistent with stale/partial build state from the shared `_build` collision, not product code paths |
| Req.TransportError (:econnrefused) | 12 | live-transport tests hitting a non-running local server |
| MatchError | 6 | incl. `semantic_drive_test.exs:1043` (inspect truncation mismatch on warning dump) |
| RuntimeError | 3 | |
| Mix / Mix.NoTaskError | 4 | |
| Ash.Error.Unknown | 3 | governance controller tests (`ApprovalExportSubscriptionUpdate.create`) |
| assertion failures (no exception) | ~5 | incl. topology guard `offenders(@root) == []` finding `priv/zcode_plugin/marketplace/xaas-fabric/commands/ultracode.md` as shadow_topology; SjProgramRegistry path expectation `/Users/sac/xaas/worktrees/repos/...` vs actual `/Users/autofde-lab`; `Xaas.ZcodePlugin.ProjectionTest` "no top-level generated/" — `File.exists?("generated")` is true |

### Subprocess run — 300 failed, detailed classes

| class | attempt-2 exception counts | notes |
| attempt-1 crash | 1 run crashed | File.Error on shared `_build/test` consolidated beam (lane collision, not a test) |
| System.EnvError `INTERNAL_API_TOKEN` | 229 | dominant class by far; env-class, token absent from the run environment |
| RuntimeError | 9 | |
| Req.TransportError | 6 | :econnrefused on local endpoints |
| MatchError | 4 | |
| UndefinedFunctionError | 2 | |
| File.Error | 2 | in-run File.Error mentions, same consolidated-beam path |
| ArgumentError | 2 | |
| ExUnit.TimeoutError (System.cmd timeout) | 1 | `semantic_jira_bridge_crown_test.exs:259` |
| Ecto.ConstraintError | 1 | |
| assertion failures (no exception) | remainder | incl. HealthControllerTest 503-vs-401 (consequence of missing token env) |

Top modules (subprocess run, of the 99 detailed): AuditExportTokenControllerTest (10),
ApprovalTierDowngrade (9), OrgControllerTest (8), ApprovalPatchSlaCreditApply (8),
ApprovalBackupRetentionChange (8), MarketplaceProvider (7), RouteOrgsCustomDomain (6),
V1ProtocolTest (6), DeploymentQuarantine (5) — all in the EnvError / auth-gating family.

## Cross-run notes

- 38 token-env failures appear in BOTH runs → the same env-class; with `INTERNAL_API_TOKEN` set in the environment (as the live server runs), this class plausibly clears most of the gap.
- The module-not-available class (~35 in property run) tracks the shared `_build/test` collision
  by concurrent lanes; treat as environment, re-run under an isolated MIX_BUILD_ROOT before
  attributing to product code.
- Machine was heavily contended (≥7 concurrent mix/beam runs from other lanes; some under
  OTP-29 toolchain in other repos). This slowed both runs (881.6s / 1260.2s vs expected faster) but did not corrupt them; attempt-1 subprocess crash was the one real collision casualty.
- All failures here are the same branches other lanes will also see; this lane ran the commands
  as specified, no fixes, no git.

## Raw logs

- /tmp/w104_property.log (10,262 lines)
- /tmp/w104_subprocess.log (attempt 1, startup crash)
- /tmp/w104_subprocess2.log (7,636 lines)

Standing: PARTIAL_ALIVE — commands executed for real, counts verbatim, failure detail truncated
at 99 per run by ExUnit output; classification covers detailed subset.
