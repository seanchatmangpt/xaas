defmodule Xaas.Mix.Tasks.CapabilityCoverageTest do
  @moduledoc """
  Chicago-style qualification for the `mix xaas.capability_coverage` count
  helper: a real `Ash.count/2` against the real sandboxed Postgres, and a
  real raise from counting a non-resource -- asserting the rescue path
  surfaces machine-readable structure (`exception`/`message`), never a flat
  stringified `Exception.message/1`. No mocking.
  """

  use ExUnit.Case, async: true

  alias Mix.Tasks.Xaas.CapabilityCoverage

  describe "count_resource/1" do
    setup do
      Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
      :ok
    end

    test "returns a real integer count for a real Postgres-backed Ash resource" do
      assert count = CapabilityCoverage.count_resource(Xaas.Ledger.Account)
      assert is_integer(count)
      assert count >= 0
    end

    test "a raising count surfaces structured detail, not a stringified message" do
      assert {:error, error} = CapabilityCoverage.count_resource(XaasWeb.Endpoint)
      assert is_map(error)
      assert is_binary(error.exception) and error.exception != ""
      assert is_binary(error.message) and error.message != ""
    end
  end
end
