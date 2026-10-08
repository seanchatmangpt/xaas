# W984ii — repair of W984hp pinned finding: `AuthorityLedgerExport.recompute_root/1` member-shape guard

Lane W984ii, 2026-10-07, branch `feat/playwright-surface`, checkout `/Users/sac/xaas`.
NO commit (per dispatch). Repairs the finding pinned in
`docs/sjira/v26.10.6/plans/w984hp-probe.md`.

## Diff (2 files, hand-written — no generator profile for this surface)

### `lib/xaas/operations/authority_ledger_export.ex` — `recompute_root/1`

Before (crashed with `BadMapError` on non-map entry members):

```elixir
def recompute_root(%{"entries" => entries}) when is_list(entries) do
  leaves =
    entries
    |> Enum.map(fn entry ->
      entry |> Map.delete("leaf_hash") |> sha256_jcs()
    end)

  {:ok, merkle_root(leaves)}
end
```

After — minimal member-shape guard reusing the existing typed error
(no new error format; a single pass, no behavior change for valid bundles):

```elixir
def recompute_root(%{"entries" => entries}) when is_list(entries) do
  if Enum.all?(entries, &is_map/1) do
    leaves =
      Enum.map(entries, fn entry ->
        entry |> Map.delete("leaf_hash") |> sha256_jcs()
      end)

    {:ok, merkle_root(leaves)}
  else
    {:error, :malformed_bundle}
  end
end
```

### `test/xaas/operations/ledger_export_court_w984hp_test.exs`

Converted the `assert_raise BadMapError` pin to the typed refusal assert,
added a `[nil]` member case; the other 9 tests untouched.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ii \
  mix test test/xaas/operations/ledger_export_court_w984hp_test.exs \
           test/xaas/operations/authority_ledger_export_test.exs
# → Result: 19 passed  (10/10 court + 9 sibling), exit 0
#   (fresh lane build root: full compile, ~28 min under heavy sibling-lane load)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ii \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
# → [] (mock gate clean)
```

## Notes

* Pre-existing (not session-introduced): compiler warning
  `@artifact ... was set but never used` at
  `ledger_export_court_w984hp_test.exs:48` — present in W984hp's landed
  file, untouched by this lane.
* Lane-lease: `rm -rf /Users/sac/xaas/_build-laneW984ii` was DENIED by the
  session permission system (same denial shape as W984hp). Coordinator owns
  deletion at integration per the same-checkout fan-out cleanup law.

Standing: repair ALIVE on the exact lane subject — court 10/10 + sibling 9,
typed-refusal pin converted, mock gate `[]`, real exits recorded above.
