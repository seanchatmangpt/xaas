defmodule Xaas.Actuation.Validations.ReactorContext do
  @moduledoc """
  Rejects consequential Ash actions that were not manufactured by the Reactor
  actuation kernel.

  `authorize?: false` is never sufficient authority by itself. Reactor must first
  admit an intent and prepare a receipt, then inject the resulting immutable
  identifiers into the Ash changeset context. Consequential actions opt into this
  validation, making a direct `Ash.update/2` call fail closed even from internal
  application code.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    reactor_context = Map.get(changeset.context, :xaas_actuation)

    with %{} = reactor_context <- reactor_context,
         receipt_id when is_binary(receipt_id) <- Map.get(reactor_context, :receipt_id),
         intent_id when is_binary(intent_id) <- Map.get(reactor_context, :intent_id),
         projection_hash when is_binary(projection_hash) <-
           Map.get(reactor_context, :ontology_projection_hash),
         true <- projection_hash == changeset.resource.ontology_projection_hash() do
      :ok
    else
      _ ->
        {:error,
         message:
           "consequential action requires an admitted Ash.Reactor intent and prepared receipt"}
    end
  end
end
