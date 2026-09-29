defmodule Xaas.Runtime.Supervisor do
  use Supervisor
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(opts) do
    Supervisor.init(
      [
        {Xaas.Runtime.ProviderRegistry, Keyword.get(opts, :registry, [])},
        {Xaas.Runtime.Reconciler, Keyword.get(opts, :reconciler, [])}
      ],
      strategy: :rest_for_one
    )
  end
end
