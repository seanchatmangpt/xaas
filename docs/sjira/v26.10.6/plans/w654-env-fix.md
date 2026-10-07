# W654 — Application-env pollution flake fix (counterfactual Art 11 test)

Lane W654, EU-AI-Act wave, repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Contract files: `test/eu_ai_act/counterfactual_test.exs` (Art 11 test only) + this doc.

## Defect (W645's finding)

`test/eu_ai_act/counterfactual_test.exs` Art 11 test ("factual declare() reads
real receipts; do(receipt source removed) refuses ...") mutated GLOBAL
Application env in-process inside an `async: true` module:

* `Application.delete_env(:xaas, :declared_metrics_root)` (pre-arm)
* `Application.put_env(:xaas, :declared_metrics_root, empty_root)` (intervention arm)
* `on_exit` delete_env — not concurrency-safe: the env stays perturbed for the
  whole test body window while other async tests' admission paths sample
  `:declared_metrics_root` (read by `Xaas.Semantics.DeclaredMetrics.read/1`,
  `lib/xaas/semantics/declared_metrics.ex:66`).

## Chosen mechanism (disclosure)

**Option (b) — subprocess isolation, zero global mutation.** `declare/0` has no
root-injection parameter (root comes only from app env, defaulting to
`File.cwd!()`), and option (a) (`async: false`) is INSUFFICIENT: an
`async: false` module still runs concurrently with every other `async: true`
module in the same invocation, so the perturbation window would still exist.
So the counterfactual arm now runs in an isolated `mix run --no-start -e`
subprocess (own BEAM, own Application env) with the empty metrics root passed
via an OS env var (`W654_EMPTY_ROOT`); the parent node's env is never touched.
Determinism is still asserted x2 (r1 == r2, both REFUSED) inside the child.
The subprocess reuses the current run's build root
(`MIX_ENV=test`, `MIX_BUILD_ROOT` inherited from the parent's env or `_build`)
so there is no recompile storm. The pre-arm `Application.delete_env` was also
removed (unnecessary: no config file sets the key; default is `File.cwd!()`).

## Diff summary

`test/eu_ai_act/counterfactual_test.exs`, Art 11 test only:

* REMOVED: `Application.delete_env(:xaas, :declared_metrics_root)` (pre-arm)
* REMOVED: `Application.put_env(:xaas, :declared_metrics_root, empty_root)`
* REMOVED: in-process `r1 = ...; r2 = ...` refusal assertions + on_exit env delete
* ADDED: `probe` snippet run via `System.cmd(mix, ["run", "--no-start", "-e", probe])`
  that sets the env IN THE CHILD, calls `declare/0` twice, prints
  `W654_REFUSED_DETERMINISTIC` iff both are `{:error, :REFUSED_METRICS_SOURCE_MISSING}`,
  halts 1 otherwise; parent asserts exit 0 + marker + no `W654_UNEXPECTED`
* ADDED: private `mix_bin/0`, `build_root/0` helpers
* KEPT: empty fixture root creation + `File.ls!(empty_root) == []` side-effect assert

## Verification (receipt — real output)

Build root: `_build-laneW654` (leased lane root), `MIX_ENV=test`, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims:$PATH`).

Note: `eu_ai_act_admission_test.exs` does not exist under that exact name in
this tree; the admission-surface counterpart is
`test/xaas_web/eu_ai_act_admission_integration_test.exs` (the only admission
test file; it exercises `EuAiActAdmission` over real HTTP) — used as the
concurrent counterpart, disclosed.

| run | command (prefix: `PATH=... MIX_BUILD_ROOT=_build-laneW654 MIX_ENV=test mix test`) | result |
|---|---|---|
| seed default | `test/eu_ai_act/counterfactual_test.exs` | `Result: 25 passed` (exit 0) |
| seed 0 | same file | `Result: 25 passed` |
| seed 123 | same file | `Result: 25 passed` |
| concurrent x1 | `test/eu_ai_act/counterfactual_test.exs test/xaas_web/eu_ai_act_admission_integration_test.exs` | `Result: 29 passed` |
| concurrent x2 | same two files, `--seed 5150` | `Result: 29 passed` |

The Art 11 subprocess test asserts internally on the child marker
(`W654_REFUSED_DETERMINISTIC`, exit 0), so each green run above is also direct
evidence the isolated `declare/0` x2 returned `{:error,
:REFUSED_METRICS_SOURCE_MISSING}` deterministically. No
`Application.put_env/delete_env(:xaas, :declared_metrics_root, ...)` call
remains in the file (verified: the only occurrences of the key are in the
subprocess probe string, evaluated in the child BEAM only).
