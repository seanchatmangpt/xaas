# W412 — cnv_deploy opt-in-class witness (DoD 1)

Lane: W412, repo /Users/sac/xaas @ feat/playwright-surface, canonical checkout, no commit.
Completes opt-in-class witness set: kind w388, stress w386, castle_kernel w380, **cnv_deploy w412**.

## Subject

- `test/xaas/operations/autofde_planner_candidate_test.exs` (tag `:requires_cnv_deploy`, line 4)
- `test/xaas/operations/autofde_planner_cross_product_test.exs` (tag `:requires_cnv_deploy`, line 10)

W374 census: 3 tests in 2 files — confirmed, exactly these 2 files.

## What cnv deploy requires

Real local cnv-deploy HTTP service on `127.0.0.1:8080` (`GET /healthz` → 200).
Each module has a module-level skip:

```elixir
@moduletag skip:
             (case Req.get("http://127.0.0.1:8080/healthz") do
                {:ok, %Req.Response{status: 200}} -> false
                _ -> "cnv-deploy not running locally on :8080 -- real integration test, no mock fallback."
              end)
```

No env-var alternative; no mock fallback (Chicago-style real collaborator). Tag excluded by
default in `test/test_helper.exs:59`; included only via `--include requires_cnv_deploy`.

## Receipt

Probe: `curl -m 2 http://127.0.0.1:8080/healthz` → HTTP `000` (connection failed — machinery absent).

Command (exit 0):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW412 \
mix test --include requires_cnv_deploy \
  test/xaas/operations/autofde_planner_candidate_test.exs \
  test/xaas/operations/autofde_planner_cross_product_test.exs
```

Real tail:

```
Result: 0 tests, 3 skipped
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

[exited with code 0]
```

## Verdict: TYPED

3/3 tests skipped with the machinery-absent reason ("cnv-deploy not running locally on :8080"),
exit 0, no loud failures, no green (machinery genuinely absent). This is the expected typed
machinery-absent outcome and completes the cnv_deploy opt-in-class witness.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW412` — **DENIED by the permission system** (two attempts,
both refused). Build root `/Users/sac/xaas/_build-laneW412` remains on disk; coordinator should
remove it at integration per the lane-lease cleanup law.
