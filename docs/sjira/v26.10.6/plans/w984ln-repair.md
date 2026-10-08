# W984ln — repair of W984kt pinned typed-contract finding (W984bo family)

Lane: W984ln · branch `feat/playwright-surface` · 2026-10-08 · NO COMMIT (lane
contract — coordinator owns commits).

## Subject

Repairs the KNOWN DEFECT pinned by W984kt (`docs/sjira/v26.10.6/plans/w984kt-probe.md`,
court leg 4): `Xaas.Marketplace.Catalog.readiness_string/1` mapped any non-map,
non-binary readiness (nil, integer, list, ...) to `""`, which the Pack resource's
required `readiness` attribute refuses — so `Catalog.ingest/1` raised a raw
`Ash.Error.Invalid` out of `upsert_pack!/1`, violating the moduledoc contract
("Malformed input produces a typed `{:error, %Xaas.Marketplace.Catalog.Error{}}`,
never an exception crossing the boundary"). Same defect family as the W984bo
omitted-readiness finding (`w984bo-marketplace-depth.md`), which this repair also
closes (absent readiness key → nil → same fallthrough).

## Diff (hand-written, 2 files)

### `lib/xaas/marketplace/catalog.ex` — `validate_packs/1`

Added a readiness-shape leg to the existing pack-validation conjunction, BEFORE
any upsert runs (so one bad pack can no longer poison the batch mid-ingest):

```elixir
readiness = Map.get(pack, "readiness")

cond do
  missing != [] or not is_binary(pack["name"]) ->
    {:halt, {:error, %Error{reason: :invalid_pack, detail: {i, missing, pack["name"]}}}}

  # W984bo-family repair: readiness that is neither a map nor a binary
  # (nil, integer, list, ...) used to fall through readiness_string/1 to
  # "" and raise a raw Ash.Error.Invalid out of the upsert. Refuse it
  # typed, per the moduledoc contract.
  not (is_map(readiness) or is_binary(readiness)) ->
    {:halt,
     {:error, %Error{reason: :invalid_pack, detail: {i, [:invalid_readiness], readiness}}}}

  true ->
    {:cont, :ok}
end
```

The pre-existing missing-fields/non-binary-name detail shape `{i, missing, name}`
is unchanged, so existing courts' detail assertions stay valid. `readiness_string/1`
itself is untouched (map/binary legs remain the normalization surface; the `""`
fallthrough is now unreachable from `ingest/1`).

### `test/xaas/marketplace/catalog_court_w984kt_test.exs` — leg 4 converted

`assert_raise Ash.Error.Invalid` (defect pin) → typed-refusal assertion:

```elixir
assert {:error, %Catalog.Error{reason: :invalid_pack, detail: {0, [:invalid_readiness], 7}}} =
         Catalog.ingest(catalog([pack("readiness-int", %{"readiness" => 7})]))

assert {:error, %Catalog.Error{reason: :invalid_pack, detail: {0, [:invalid_readiness], nil}}} =
         Catalog.ingest(catalog([pack("readiness-null", %{"readiness" => nil})]))

assert Catalog.list_packs() == []
```

The other 6 legs are byte-identical to W984kt's landed version.

## Gates (all executed, real output)

Env for all: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ln`
(fresh build root; full compile under pinned asdf toolchain, elixir 1.20.2-otp-28).

1. W984kt court, before state (pinned defect, pre-repair): W984kt receipt's
   `7 passed` on the `assert_raise` version.
2. W984kt court, after repair:
   `mix test test/xaas/marketplace/catalog_court_w984kt_test.exs` →
   `Result: 7 passed`, **exit 0**.
3. Sibling marketplace courts (whole dir, incl. catalog_test, W984dg depth court,
   W984bo pack_catalog_depth, W984hu remainder):
   `mix test test/xaas/marketplace/` → `57 passed, 3 excluded` (excluded =
   `@tag :real_marketplace_catalog` legs, excluded by default as before), **exit 0**.
4. Mock gate: `scan_mock_usage(["test", "lib"])` → `[]`.

## Standing

- Repair: ALIVE (court 7/7 exit 0 on exact working tree, real Postgres sandbox).
- W984bo omitted-readiness defect: same repair closes it (nil → typed
  `:invalid_pack`); its court's in-source defect comment in
  `pack_catalog_depth_test.exs` now describes a repaired defect — noted for
  coordinator triage, not edited by this lane (file owned by W984bo).
- No commit made; both edited files left in the working tree for integration.
