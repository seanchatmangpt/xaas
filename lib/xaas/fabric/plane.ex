defmodule Xaas.Fabric.Plane do
  @moduledoc """
  Adapter contract between the fabric and one `ash_*` capability plane. A plane is
  semantics reached through a `capability://` URI; a realization is the module (and opts)
  that serves it. Stages a realization does not serve return `{:error, :unsupported}`.

  `facts` is the run's shared state; planes exchange data only through it, never directly.
  Errors are raw: the fabric normalizes them with `Xaas.Fabric.Failure.normalize/2`.
  """

  @type stage :: :observe | :construct | :execute | :receipt | :replay
  @type contract :: %{
          uri: String.t(),
          semantic_id: String.t(),
          realization: String.t(),
          ceiling: :observe | :construct | :do
        }

  @callback contract() :: contract()
  @callback call(stage(), env :: map(), facts :: map(), opts :: keyword()) ::
              {:ok, map()} | :ok | {:error, term()}

  @ceiling_rank %{observe: 0, construct: 1, do: 2}
  @stage_rank %{observe: 0, receipt: 0, replay: 0, construct: 1, execute: 2}

  @doc "A stage may only be driven up to the realization's declared ceiling."
  def permit(%{ceiling: ceiling}, stage), do: @stage_rank[stage] <= @ceiling_rank[ceiling]
end
