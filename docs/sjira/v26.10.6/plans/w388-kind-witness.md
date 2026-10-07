# W388 — DoD 1 opt-in evidence: `:kind` class witness (v26.10.6)

## Machinery census (real output, 2026-10-06 17:07 PDT)

- `kind` present: v0.30.0 go1.25.0 darwin/arm64 (`/opt/homebrew/bin/kind`)
- `kubectl` present: v1.35.2 (`/opt/homebrew/bin/kubectl`)
- `colima` present but NOT running: `colima status` → `level=fatal msg="colima is not running"`
- Cluster: `kubectl` during run → `error: context "kind-xaas" does not exist` — no cluster up.

So: machinery binaries present, cluster machinery offline. Expected verdict class:
typed machinery-absent per w155 convention — but note these tests do NOT skip;
they attempt and fail on the missing cluster.

## Test files (grep `@.*tag.*:kind`)

- test/e2e/kind_deployment_test.exs
- test/e2e/kind_chaos_pod_recovery_test.exs
- test/e2e/kind_chaos_postgres_pod_recovery_test.exs
- test/xaas_web/controllers/prometheus_query_controller_test.exs

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW388 \
  mix test --include kind test/e2e/kind_deployment_test.exs \
  test/e2e/kind_chaos_pod_recovery_test.exs \
  test/e2e/kind_chaos_postgres_pod_recovery_test.exs \
  test/xaas_web/controllers/prometheus_query_controller_test.exs
```

(First run ~10 min full-compile of fresh lane build root; test phase itself 21.1s.
Run twice; second/third runs warm.)

## Real tail

```
  1) test killing the live postgres pod: data survives recreation because a real PVC backs it (Xaas.E2E.KindChaosPostgresPodRecoveryTest)
  2) test real /api create with a real malformed JSON:API body (wrong attribute type) is really rejected (Xaas.E2E.KindChaosPodRecoveryTest)
  3) test deleting the live xaas pod triggers real Deployment self-healing to a new Running/Ready pod (Xaas.E2E.KindChaosPodRecoveryTest)
  4) test GET /internal-api/prometheus/query proxies a real query to a real live Prometheus (XaasWeb.PrometheusQueryControllerTest)
  4) Xaas.E2E.KindDeploymentTest: failure on setup_all callback, all tests have been invalidated
     ** (RuntimeError) Could not reach the real live xaas pod at http://localhost:4001/ after starting
     `kubectl port-forward`. Confirm `kind-xaas` is up (`kind get clusters`)
     and the `xaas Deployment is Running
     (`kubectl --context kind-xaas get pods -n default`).
Result: 4/8 passed, 5 invalid
Failed: 4 tests
```

Prometheus failure detail (verbatim):

```
** (RuntimeError) expected response with status 200, got: 502, with body:
  "{\"error\":\"prometheus_unreachable\",\"detail\":\"could not reach Prometheus at http://localhost:9090: :econnrefused\"}"
```

## Verdict: KIND-CLASS-TYPED (machinery present but offline — real failures, zero silent passes)

- 4/8 passed; 5 tests invalidated by `Xaas.E2E.KindDeploymentTest` `setup_all`
  (port-forward to `kind-xaas` refused — no cluster running).
- 4 real failures, all machinery-caused:
  1. `KindChaosPostgresPodRecoveryTest` (PVC survival)
  2. `KindChaosPodRecoveryTest` malformed JSON:API over real /api
  3. `KindChaosPodRecoveryTest` pod self-healing
  4. `PrometheusQueryControllerTest` — 502 `prometheus_unreachable` (:econnrefused localhost:9090)
- No typed skip reasons emitted — the `:kind` tests fail loudly on missing
  cluster rather than skip with `@tag skip`. Typed-reason skips (w155 shape)
  would require skip guards; that is the gap this witness surfaces.

## Cleanup

`rm -rf _build-laneW388` — **DENIED** by permission system; build root remains on disk
(356M+ at last observation). Coordinator should remove at integration.
