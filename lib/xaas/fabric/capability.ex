defmodule Xaas.Fabric.Capability do
  @moduledoc """
  Common capability bus. A realization implements `describe/0` and only the operations its
  effect class allows; the rest default to `{:error, {:unsupported, op}}` via `use`.

  Failure classes: `:realization_failed | :capability_unavailable | :semantic_refusal |
  :authority_refusal | :process_invalid | :transport_failed | :evidence_insufficient | :unsupported`.
  Only `:realization_failed | :transport_failed | :unsupported` close an edge and fall over.
  """

  alias Xaas.Fabric.Contract

  @type facts :: map()
  @type err :: {atom(), term()}

  @callback describe() :: Contract.t()
  @callback qualify(env :: map()) :: :ok | {:error, err()}
  @callback observe(env :: map(), facts()) :: {:ok, facts()} | {:error, err()}
  @callback select(env :: map(), facts()) :: {:ok, facts()} | {:error, err()}
  @callback construct(env :: map(), facts()) :: {:ok, facts()} | {:error, err()}
  @callback execute(env :: map(), facts()) :: {:ok, facts()} | {:error, err()}
  @callback receipt(env :: map(), facts()) :: {:ok, map()} | {:error, err()}
  @callback replay(env :: map(), receipt :: map()) :: :ok | {:error, err()}
  @callback health() :: :ok | {:error, err()}

  defmacro __using__(_) do
    quote do
      @behaviour Xaas.Fabric.Capability
      def qualify(_env), do: :ok
      def observe(_env, _facts), do: {:error, {:unsupported, :observe}}
      def select(_env, _facts), do: {:error, {:unsupported, :select}}
      def construct(_env, _facts), do: {:error, {:unsupported, :construct}}
      def execute(_env, _facts), do: {:error, {:unsupported, :execute}}
      def receipt(_env, _facts), do: {:error, {:unsupported, :receipt}}
      def replay(_env, _receipt), do: {:error, {:unsupported, :replay}}
      def health, do: :ok

      defoverridable qualify: 1,
                     observe: 2,
                     select: 2,
                     construct: 2,
                     execute: 2,
                     receipt: 2,
                     replay: 2,
                     health: 0
    end
  end

  def falls_over?(class), do: class in [:realization_failed, :transport_failed, :unsupported]
end
