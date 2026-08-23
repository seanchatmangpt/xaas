defmodule Xaas.Resource do
  @moduledoc """
  Shared Ash resource entry point.

  In addition to delegating to `Ash.Resource`, every resource receives a
  reversible public-ontology projection contract. Application modules remain
  the executable Ash surface; semantic identity is manufactured by
  `Xaas.Semantics.Registry` and is therefore available uniformly to Reactor,
  receipts, generators, R2RML exporters, and future ggen projections.
  """

  defmacro __using__(opts) do
    quote do
      use Ash.Resource, unquote(opts)

      @doc "Returns this resource's reversible projection onto public ontologies."
      def ontology_projection do
        Xaas.Semantics.Registry.projection(__MODULE__)
      end

      @doc "Returns the admitted public-ontology projection or raises on semantic refusal."
      def ontology_projection! do
        case Xaas.Semantics.Registry.admit(__MODULE__) do
          {:ok, projection} -> projection
          {:error, reason} -> raise ArgumentError, "ontology projection refused: #{inspect(reason)}"
        end
      end

      @doc "Returns the deterministic semantic identity bound into actuation receipts."
      def ontology_projection_hash do
        __MODULE__
        |> ontology_projection!()
        |> Xaas.Semantics.Registry.hash()
      end

      defoverridable ontology_projection: 0, ontology_projection!: 0, ontology_projection_hash: 0
    end
  end
end
