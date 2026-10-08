# W984fy — AwsAdapter seam disposition: local protocol harness court

Lane: W984fy · repo /Users/sac/xaas · branch feat/playwright-surface · no commit
Disposition target: W984dy's disclosed untested `Xaas.AwsRepo.AwsAdapter` seam.

## Findings

1. **Dead config bug found and fixed.** `config/runtime.exs:33` has always set
   `config :xaas, Xaas.AwsRepo.AwsAdapter, base_url: "http://localhost:1338"`
   under the fixture profile, but the adapter read a compile-time
   `@base_url "http://169.254.169.254"` module attribute — the runtime config
   was never read (dead config). The adapter now reads `base_url` from app env
   at call time (`defp base_url/0`), IMDS default preserved. This converts the
   IMDS pub from no-seam to a real config-driven seam.
   File: `lib/xaas/aws_repo_adapters/aws_adapter.ex`
2. **CloudWatch pub had a seam all along.** `ExAws.request/1` resolves service
   config (`:exaws, :monitoring` host/port/scheme) at call time, so the
   GetMetricStatistics pub is locally harnessable without any source change.
3. **Real error surface established.** CloudWatch pub: `{:ok, float}` on 200,
   `{:ok, 0}` on empty datapoints, `{:error, reason}` on non-200 (ExAws maps
   400 to error tuple), **raises** (xmerl exit) on malformed 200 XML — an
   unhandled-crash branch, disclosed. IMDS pub: wrapped
   `{:error, "Failed to retrieve AWS token, error: ..."}` on connection
   refused; **quirk**: a non-200 instance-id read returns `{:ok, body}` because
   Req returns `{:ok, resp}` for any status and the adapter never checks
   status — asserted as-behaved, flagged for follow-up.
   "Bad credentials" is not observable locally (the local harness does not
   verify SigV4); signing failures would surface in the same `{:error, reason}`
   channel as non-200.

## What was built (Chicago: real collaborators, zero mocks)

`test/xaas/aws_repo_adapters/aws_adapter_local_harness_court_w984fy_test.exs`:

- Real Plug/Cowboy listener on an ephemeral port (`:ranch.get_port/1`),
  scenarios switched per-test via `:persistent_term`.
- CloudWatch pub: valid XML (2 datapoints → 15.0), empty datapoints (→ 0),
  400 ErrorResponse (→ `{:error, _}`), malformed XML (→ real parse exit).
- IMDS pub: token PUT + instance-id GET round-trip, connection refused via
  real closed port (listen(0) → close → connect), 500 instance-id quirk.
- ExAws/adapter pointed at the harness purely via `Application.put_env`
  (real app config, restored on_exit).

## Gates (real output, this session, MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fy)

- Court: `mix test test/xaas/aws_repo_adapters/aws_adapter_local_harness_court_w984fy_test.exs`
  → `Result: 7 passed` (exit 0). Cold lane build from scratch (full dep +
  app compile) required ~20 min; incremental reruns <1s.
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
  → `[]`.
- Sibling regression: `mix test test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs`
  → `Result: 7 passed`.

## Falsifier status

- Local harness court: ALIVE — 7/7 executed against real Plug/Cowboy
  transport on an ephemeral port (receipt above).
- IMDS-on-EC2 branch (169.254.169.254 reachability from a real EC2 host):
  remains BLOCKED(no-ec2-harness) — out of local scope, unchanged.

## Standing

PARTIAL_ALIVE → local protocol surface ALIVE via harness; live-EC2 surface
BLOCKED as before. Follow-up candidates: status-check on the IMDS instance-id
read (500→{:ok} quirk), and a permanent guard that `base_url` config is
actually read (the dead-config class).

## Cleanup lease note

`rm -rf _build-laneW984fy` was attempted post-gates and DENIED by the
permission system. The lane build root `_build-laneW984fy/` is therefore
still on disk — coordinator cleanup required per the lane-lease law.
