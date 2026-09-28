defmodule Xaas.Runtime.ProviderRegistry do
  use GenServer
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def register(provider, opts \\ []), do: GenServer.call(__MODULE__, {:register, provider, opts})
  def candidates(capability), do: GenServer.call(__MODULE__, {:candidates, capability})
  def report(provider, outcome), do: GenServer.cast(__MODULE__, {:report, provider, outcome})
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @impl true
  def init(opts), do: {:ok, %{providers: %{}, threshold: Keyword.get(opts, :failure_threshold, 3),
    cooldown_ms: Keyword.get(opts, :cooldown_ms, 30_000)}}

  @impl true
  def handle_call({:register, provider, opts}, _from, state) do
    entry = %{provider: provider, priority: Keyword.get(opts, :priority, 100),
      status: :ready, failures: 0, opened_at: nil}
    {:reply, :ok, put_in(state, [:providers, provider], entry)}
  end
  def handle_call(:snapshot, _from, state), do: {:reply, state.providers, state}
  def handle_call({:candidates, capability}, _from, state) do
    state = refresh_open(state)
    result = state.providers |> Map.values()
      |> Enum.filter(&(&1.status != :open and capability in &1.provider.capabilities()))
      |> Enum.sort_by(&{rank(&1.status), &1.priority, inspect(&1.provider)})
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:report, provider, :ok}, state),
    do: {:noreply, update(state, provider, &%{&1 | failures: 0, status: :ready, opened_at: nil})}
  def handle_cast({:report, provider, {:error, _}}, state) do
    now = System.monotonic_time(:millisecond)
    next = update(state, provider, fn e ->
      n = e.failures + 1
      if n >= state.threshold, do: %{e | failures: n, status: :open, opened_at: now},
        else: %{e | failures: n, status: :degraded}
    end)
    {:noreply, next}
  end

  defp update(state, provider, fun) do
    case state.providers do
      %{^provider => entry} -> put_in(state, [:providers, provider], fun.(entry))
      _ -> state
    end
  end
  defp refresh_open(state) do
    now = System.monotonic_time(:millisecond)
    providers = Map.new(state.providers, fn {p, e} ->
      e = if e.status == :open and now - e.opened_at >= state.cooldown_ms,
        do: %{e | status: :degraded, opened_at: nil}, else: e
      {p, e}
    end)
    %{state | providers: providers}
  end
  defp rank(:ready), do: 0
  defp rank(:degraded), do: 1
  defp rank(:open), do: 2
end
