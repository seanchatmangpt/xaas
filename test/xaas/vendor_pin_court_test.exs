defmodule Xaas.VendorPinCourtTest do
  @moduledoc """
  W894 — vendored-pin doctrine court (gap found by the W894 coverage grep).

  The airo.ttl pin is courted by `Xaas.Semantics.AiroVendoredPinTest`, but
  `priv/vendor/ex4pm/ocel.ex` had NO default-included byte-pin: the only
  coverage was `Xaas.Ontology.Ex4pmStalenessTest`, which is `:external`-tagged
  (excluded by default) and exercises synthetic repos, never the real vendored
  bytes. This court pins the real vendored file against the W702-verified
  pin (`config/config.exs:79`, `pinned_sha ade25ed1...`), whose blob sha256
  was re-derived fresh this wave:

      git -C ~/ex4pm show ade25ed12e93f89e7a2e1490698f99ae4947d702:lib/ex4pm/ocel.ex | shasum -a 256

  Chicago-style: real file, real sha256, no mocks.
  """

  use ExUnit.Case, async: false

  @ocel_relpath "priv/vendor/ex4pm/ocel.ex"

  # W702 evidence receipt row 19, freshly re-derived this wave from the
  # ex4pm checkout at the config-pinned SHA.
  @expected_sha256 "ec075eb1c75d5235647498fd880eb23322721618c1328624689a86ddee0a9287"
  @pinned_upstream_sha "ade25ed12e93f89e7a2e1490698f99ae4947d702"

  @repo_root Path.expand("../..", __DIR__)
  @ocel_path Path.join(@repo_root, @ocel_relpath)

  test "vendored ex4pm ocel.ex exists" do
    assert File.exists?(@ocel_path), "missing #{@ocel_relpath}"
  end

  test "vendored ex4pm ocel.ex is byte-pinned to the W702 upstream derivation" do
    assert File.exists?(@ocel_path), "missing #{@ocel_relpath}"

    actual =
      @ocel_path
      |> File.read!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    if actual != @expected_sha256 do
      flunk("""
      VENDOR_PIN_DRIFT: #{@ocel_relpath} sha256 #{actual}
        != pinned #{@expected_sha256}
        (upstream ex4pm@#{@pinned_upstream_sha}:lib/ex4pm/ocel.ex)
      Re-vendor with:
        git -C ~/ex4pm show #{@pinned_upstream_sha}:lib/ex4pm/ocel.ex > priv/vendor/ex4pm/ocel.ex
      then update this pin + config/config.exs :ex4pm_ontology_check together.
      """)
    end
  end

  @tag :external
  test "upstream ex4pm blob at the pinned SHA still hashes to the pin (requires ~/ex4pm)" do
    repo = System.get_env("EX4PM_REPO_PATH") || Path.expand("~/ex4pm")

    if File.dir?(repo) do
      {out, 0} =
        System.cmd("git", ["show", "#{@pinned_upstream_sha}:lib/ex4pm/ocel.ex"], cd: repo)

      upstream = :crypto.hash(:sha256, out) |> Base.encode16(case: :lower)
      assert upstream == @expected_sha256
    else
      flunk("ex4pm repo absent at #{repo}; cannot re-derive the pinned upstream blob")
    end
  end
end
