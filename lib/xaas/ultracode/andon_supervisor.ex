defmodule Xaas.Ultracode.AndonSupervisor do
  @moduledoc """
  The Andon supervision root, OPT-IN (loops-of-loops spec L4).

  A `child_spec/1` wrapper that starts `Xaas.Ultracode.Andon`. `Xaas.Application`
  appends it to the supervision tree ONLY when
  `config :xaas, :andon_enabled, true` -- default boots are byte-identical
  to before this module existed. The supervisor exists so a future
  restart-cascade policy has a real tree node to own the cord; today it
  adds exactly one child, the cord itself.
  """

  use Supervisor

  @doc "Starts the supervisor (named)."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Supervisor.init([{Xaas.Ultracode.Andon, Keyword.take(opts, [:name])}], strategy: :one_for_one)
  end
end
