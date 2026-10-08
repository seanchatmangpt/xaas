# W984hc — typed-defect repair: IMDS token-path status guard (closes W984gu residue)

Lane: W984hc · repo /Users/sac/xaas · branch feat/playwright-surface · NO commit.

Closes the residue W984gu disclosed in
`docs/sjira/v26.10.6/plans/w984gu-repair.md`: `get_aws_token/0` in
`lib/xaas/aws_repo_adapters/aws_adapter.ex` accepted any status (Req returns
`{:ok, resp}` for any status), so a 500 on the IMDSv2 token PUT flowed back as
`{:ok, <error-body>}`.

## Diff (2 files)

`lib/xaas/aws_repo_adapters/aws_adapter.ex` — `get_aws_token/0`, exact mirror
of W984gu's instance-id pattern:

```elixir
# before
{:ok, %Req.Response{body: body}} -> {:ok, body}
# after
{:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
  {:ok, body}

{:ok, %Req.Response{status: status}} ->
  {:error, "Failed to retrieve AWS token, error: unexpected_status_#{status}"}
```

`{:error, error}` branch unchanged (the W984fy connection-refused court
asserts its exact string, and it still passes).

`test/xaas/aws_repo_adapters/aws_adapter_token_guard_court_w984hc_test.exs` —
NEW file (copy-per-convention): the shared harness file
`aws_adapter_local_harness_court_w984fy_test.exs` was still untracked in
`git status` (W984gy landing batch possibly staging it), so per order this
court got its own real Plug/Cowboy harness. Two tests over real transport:

- 200 token → `{:ok, "i-0w984hcLOCAL"}` (happy path green).
- 500 token (Req retries 3x internally, observed in log) →
  `{:error, "Failed to retrieve self instance id, error: \"Failed to retrieve AWS token, error: unexpected_status_500\""}`.

## Gates (real output, this session, PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
MIX_BUILD_ROOT=_build-laneW984hc — seeded by cp -R from `_build-laneW984fy/`)

- `mix test aws_adapter_token_guard_court_w984hc_test.exs aws_adapter_local_harness_court_w984fy_test.exs`
  → `Result: 9 passed` (exit 0) — new court 2 tests + untouched harness 7 tests.
- Mock gate: `mix run -e 'IO.inspect(...scan_mock_usage(["test", "lib"]))'` → `[]`.
- Sibling regression: `mix test aws_repo_adapters_deepening_test.exs` → `Result: 7 passed`.

## Standing

W984gu's disclosed token-path residue: closed on the local harness (real 500
on the token path over real transport now yields the typed error; 200 happy
path verified green in the same run). Live-EC2 IMDS surface remains BLOCKED
(no-ec2-harness), unchanged from W984fy/W984gu.

## Cleanup lease

`rm -rf _build-laneW984hc` — DENIED by the permission system (harness refused
the Bash `rm -rf` in this session). Build root `_build-laneW984hc/` remains on
disk as an un-released lane lease; coordinator cleanup per
[[same-checkout-fanout]] integration law required.
