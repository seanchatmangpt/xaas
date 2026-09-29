defmodule Xaas.Trimtab.Coordinator do
  use GenServer
  alias Xaas.Trimtab.{ProviderAdapter, Recovery, Receipt, Telemetry}
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))

  def run(s, sub, ps, c, r, opts \\ []),
    do: GenServer.call(s, {:run, sub, ps, c, r, opts}, Keyword.get(opts, :timeout, 5000))

  def init(opts), do: {:ok, %{max_attempts: Keyword.get(opts, :max_attempts, 3)}}

  def handle_call({:run, s, ps, c, r, o}, _, st),
    do: {:reply, attempt(s, ps, c, r, o, [], st.max_attempts), st}

  defp attempt(_, _, _, _, _, fs, 0), do: {:error, {:attempt_budget_exhausted, fs}}

  defp attempt(s, ps, c, r, o, fs, left) do
    with {:ok, p} <- Recovery.next(ps, c, fs) do
      case ProviderAdapter.invoke(p, r, o) do
        {:ok, result} ->
          rec = Receipt.seal(s, p.id, r, result, failed_edges: Enum.map(fs, & &1.provider_id))

          Telemetry.emit(:completed, %{attempts: length(fs) + 1}, %{
            provider: p.id,
            subject: s.digest
          })

          {:ok, result, rec}

        {:error, reason} ->
          {:ok, next} = Recovery.record(fs, p.id, :transient, reason)
          attempt(s, ps, c, r, o, next, left - 1)
      end
    end
  end
end
