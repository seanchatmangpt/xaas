defmodule Xaas.Ontology.Ex4pmStalenessTest do
  @moduledoc """
  Real, non-mocked exercise of the full precondition chain in
  `Xaas.Ontology.Ex4pmStaleness.check/0` against whatever ex4pm checkout
  (or absence of one) actually exists on this machine.

  Tagged `:external` and excluded by default (see test/test_helper.exs) so
  the default `mix test` never depends on the sibling ex4pm repo being
  present. Run explicitly with `mix test --include external`.

  Both `:match` and `:skipped` count as a passing test -- only a real
  `{:error, _}` (ex4pm present and reachable but genuinely broken/stale)
  fails this test.
  """
  use ExUnit.Case, async: true

  @moduletag :external

  alias Xaas.Ontology.Ex4pmStaleness

  test "check/0 either matches, skips gracefully, or reports a real named failure" do
    case Ex4pmStaleness.check() do
      {:ok, :match} ->
        assert true

      {:ok, :skipped, reason} ->
        assert is_tuple(reason)

      {:error, reason} ->
        flunk("ex4pm ontology staleness check failed for real: #{inspect(reason)}")
    end
  end
end
