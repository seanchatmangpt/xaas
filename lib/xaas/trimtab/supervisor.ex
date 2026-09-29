defmodule Xaas.Trimtab.Supervisor do
  use Supervisor

  def start_link(opts \\ []),
    do: Supervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  def init(opts),
    do:
      Supervisor.init(
        [
          {Xaas.Trimtab.Coordinator,
           [
             name: Keyword.get(opts, :coordinator, Xaas.Trimtab.Coordinator),
             max_attempts: Keyword.get(opts, :max_attempts, 3)
           ]}
        ],
        strategy: :one_for_one
      )
end
