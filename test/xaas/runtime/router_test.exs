defmodule Xaas.Runtime.RouterTest do
  use ExUnit.Case, async: false
  alias Xaas.Runtime.{ProviderRegistry, Router}

  defmodule Bad do
    @behaviour Xaas.Runtime.Provider
    def capabilities, do: [:plan]
    def health(_), do: :healthy
    def execute(_, _, _), do: {:error, :offline}
  end

  defmodule Good do
    @behaviour Xaas.Runtime.Provider
    def capabilities, do: [:plan]
    def health(_), do: :healthy
    def execute(:plan, x, _), do: {:ok, {:planned, x}}
  end

  setup do
    start_supervised!({ProviderRegistry, failure_threshold: 1, cooldown_ms: 60_000})
    :ok = ProviderRegistry.register(Bad, priority: 1)
    :ok = ProviderRegistry.register(Good, priority: 2)
    :ok
  end

  test "routes around failed edge once" do
    assert {:ok, {:planned, :job}, receipt} = Router.execute(:plan, :job)
    assert receipt.selected == Good
    assert Enum.map(receipt.attempts, & &1.provider) == [Bad, Good]
  end

  test "circuit removes failed provider from next route" do
    assert {:ok, _, _} = Router.execute(:plan, :first)
    assert [%{provider: Good}] = ProviderRegistry.candidates(:plan)
  end

  test "unsupported capability has explicit exhaustion receipt" do
    assert {:error, :no_provider, %{attempts: []}} = Router.execute(:unknown, :job)
  end
end
