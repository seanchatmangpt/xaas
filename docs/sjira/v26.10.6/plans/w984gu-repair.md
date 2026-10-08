# W984gu — typed-defect repair: IMDS instance-id status guard (fixes W984fy quirk)

Lane: W984gu · repo /Users/sac/xaas · branch feat/playwright-surface · NO commit.
Repairs the defect W984fy disclosed: Req returns `{:ok, resp}` for any status;
the adapter never checked `resp.status`, so a 500 on the instance-id read
returned `{:ok, "boom"}`.

## Diff (2 files)

`lib/xaas/aws_repo_adapters/aws_adapter.ex` — `get_self_instance_id/0`:

```elixir
# before
{:ok, %Req.Response{body: body}} <- Req.get(url, headers: [...]) do {:ok, body}
# after
{:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
  Req.get(url, headers: [...]) do
  {:ok, body}
else
  {:ok, %Req.Response{status: status}} ->
    {:error, "Failed to retrieve self instance id, error: unexpected_status_#{status}"}
  ...
end
```

Error shape follows the adapter's existing wrapped-string channel (same as the
connection-refused branch) — no new format invented. Note: `get_aws_token/0`
still lacks a status guard (out of this order's scope; disclosed).

`test/xaas/aws_repo_adapters/aws_adapter_local_harness_court_w984fy_test.exs` —
the `{:ok, "boom"}` quirk test converted to assert
`{:error, "Failed to retrieve self instance id, error: unexpected_status_500"}`;
real Plug/Cowboy harness and all other 6 tests untouched. (Req retries the 500
3x internally before returning — observed in real output, result unchanged.)

## Gates (real output, this session, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
MIX_BUILD_ROOT=_build-laneW984gu — lane build seeded by cp -R from
`_build-laneW984fy/` which still existed on disk, avoiding a 20-min cold build)

- Court: `mix test test/xaas/aws_repo_adapters/aws_adapter_local_harness_court_w984fy_test.exs`
  → `Result: 7 passed` (exit 0), incl. the converted 500-typed-error test.
- Mock gate: `mix run -e 'IO.inspect(...scan_mock_usage(["test", "lib"]))'` → `[]`.
- Sibling regression: `mix test test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs`
  → `Result: 7 passed`.

## Standing

W984fy's IMDS quirk falsifier: closed on the local harness (real 500 over real
transport now yields typed error). Live-EC2 IMDS surface remains BLOCKED
(no-ec2-harness), unchanged.

## Cleanup lease

`rm -rf _build-laneW984gu` — SUCCEEDED post-gates (no permission denial this
time, unlike W984fy).
