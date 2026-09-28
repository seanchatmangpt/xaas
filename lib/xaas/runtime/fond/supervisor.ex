defmodule Xaas.Runtime.FOND.Supervisor do
 use Supervisor
 def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__,opts,name:__MODULE__)
 def init(_), do: Supervisor.init([],strategy: :one_for_one)
end
