defmodule Xaas.Runtime.Reconciler do
  use GenServer
  alias Xaas.Runtime.ProviderRegistry
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(opts) do
    state = %{
      interval_ms: Keyword.get(opts, :interval_ms, 5_000),
      context: Keyword.get(opts, :context, %{})
    }

    Process.send_after(self(), :reconcile, state.interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:reconcile, state) do
    ProviderRegistry.snapshot() |> Map.keys() |> Enum.each(&probe(&1, state.context))
    Process.send_after(self(), :reconcile, state.interval_ms)
    {:noreply, state}
  end

  defp probe(provider, context) do
    result =
      try do
        provider.health(context)
      catch
        kind, reason -> {:unavailable, {kind, reason}}
      end

    case result do
      :healthy -> ProviderRegistry.report(provider, :ok)
      :degraded -> ProviderRegistry.report(provider, {:error, :degraded})
      {:unavailable, reason} -> ProviderRegistry.report(provider, {:error, reason})
      other -> ProviderRegistry.report(provider, {:error, {:invalid_health, other}})
    end
  end
end
