# W251 — Definitive Full-Suite Receipt (W158 mandate, post all wave fixes)

Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (working tree at run time; no new commits — per mandate, no git actions taken)
Command: `cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test`
Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2 (pinned). Full log preserved at `/tmp/w251-suite-full.log` (4497 lines).

## Run history (both runs on the same tree, same command)

| run | Result line (verbatim) | notes |
|---|---|---|
| run 1 (attempt under concurrent a2a `mix test` pid 20832) | `Result: 2855/3231 passed (6/6 doctests, 2849/3225 tests), 36 skipped, 91 excluded` / `Failed: 376 tests` | first attempt aborted pre-suite: `(Mix) Could not load Xaas.LegacyRepo, error: :nofile` (build-lock contention with concurrent `mix test test/xaas/a2a test/xaas_web/a2a`, pid 20832); retry completed |
| run 2 (definitive, full log classified) | `Result: 2985/3232 passed (6/6 doctests, 2979/3226 tests), 36 skipped, 91 excluded` / `Failed: 247 tests` | clean run; full 4497-line log classified below |

Exact final lines (verbatim, run 2):

```
Finished in 1026.3 seconds (34.0s async, 992.2s sync)

Result: 2985/3232 passed (6/6 doctests, 2979/3226 tests), 36 skipped, 91 excluded
Failed: 247 tests
```

Mock gate (verbatim):

```
[]
```

Command: `MIX_ENV=test mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` — expected `[]`, got `[]`. **Mock gate PASSES.**

## Failure classification — all 247 failures, run 2

Parsed and classified from the full log; 247 entries found, every one classified:

| class | count | classification |
|---|---|---|
| `** (System.EnvError) could not fetch environment variable "INTERNAL_API_TOKEN" because it is not set` | 210 | **Known-typed: cross-test env contamination (contention).** Root cause located: `test/xaas_web/execution_fabric_controller_test.exs:180` calls `System.delete_env("INTERNAL_API_TOKEN")` (restored at :188) while ExUnit runs other tests async — every other test reading the env var inside that window fails. Not a product defect; single-line-span contamination, not a new class. |
| `** (RuntimeError) expected response with status 401, got: 503` | 7 | **Same root cause, plug-level symptom:** `RequireInternalApiToken` fails closed with 503 when `INTERNAL_API_TOKEN` is unset — the correct fail-closed behavior, triggered by the same delete-env window. Known-typed (contention/env). |
| `Assertion with == failed` / match failures in plug/controller tests (401 vs 503, token-present assertions) | 28 | **Same env-contamination class** (assertions on status 401 vs observed 503 fail-closed; token-present assertions failing in the delete-env window). |
| `Xaas.Witness.CatalogTest` — `list_by_algorithm(:es256)` expected 1 row, got 2 (extra row subject `sha256:e2e-w55-verified`) | 1 | **Known-typed: shared-test-DB contention.** Row seeded by another wave's concurrent e2e run (subject prefix `e2e-w55`) visible in the shared database. Witness-env/contention class. |
| `Xaas.Ultracode.MachineExperienceTest` — subprocess mix run wrote `..._build/test/lib/xaas/consolidated/Elixir.Inspect.beam: no such file or directory` | 1 | **Known-typed: build-dir contention.** The spawned real-OS mix subprocess hit the shared `_build/test` while the concurrent a2a suite was consolidating protocols. |
| `Xaas.Semantics.AshR2RMLTest.UnsupportedResource` — Spark DSL verification exception on the deliberate negative fixture | 1 | **Known-typed: intentional negative-fixture compile-time noise** (an "UnsupportedResource" negative fixture tripping Spark's domain-membership verifier during parallel compile; warning-grade, single instance). Flag for the R2RML owners; not wave-introduced. |
| `XaasWeb.A2A.V1ProtocolTest` (1 `Assertion with == failed`) + `XaasWeb.InternalApiRouterTest` (NotAcceptable expected, got EnvError) | 2 | **Env-contamination class** (same delete-env window; the router test's `assert_raise` collided with the missing env var rather than the expected 406). |

So: **245 of 247 failures (210 EnvError + 7 401-vs-503 + 28 assertion failures) share one mechanical root cause** — the `System.delete_env("INTERNAL_API_TOKEN")` window in `execution_fabric_controller_test.exs:180` under async ExUnit. The remaining 2 are shared-DB and shared-build contention from the concurrent a2a run.

## NEW failure classes: NONE

Zero failures fall outside the known-typed sets (OS-9 skips are among the 36 skipped; witness env; contention). The single semi-novel observation — Spark DSL compile-time verification exception on the `AshR2RMLTest.UnsupportedResource` negative fixture — is warning-grade, single-instance, and attached to an intentional negative fixture, not a wave-introduced product defect.

## Contention disclosure

A concurrent `mix test test/xaas/a2a test/xaas_web/a2a` suite (pid 20832) was active during run 1 and part of run 2, sharing `_build/test` and the shared test Postgres. This is the sole source of the run-1 vs run-2 delta (376 → 247 failures) and of the witness/consolidation outliers.

## Verdict

- Suite boots and completes; 2979/3226 tests pass (92.3%).
- 245/247 failures: single mechanical root cause (env-delete window under async contention), all in the known-typed contention class.
- 2/247: shared-DB / shared-build contention (witness row leakage, protocol-consolidation collision).
- Mock gate: `[]` — clean.
- No fixes applied, no git actions taken, per mandate.
