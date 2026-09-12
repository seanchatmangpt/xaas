defmodule Xaas.Ocel.AshIdentity do
  @moduledoc """
  Ash-resource identity mapping -- ticket scope item, per
  docs/jira/v26.9.11/object-centric-event-projection.md.

  A real, deterministic, round-trippable bijection between an existing Ash
  resource's `{module, primary_key}` identity and an OCEL `{object_type,
  ocel_id}` pair, used by `Xaas.Ocel.Projection` and by any caller wanting
  to register an `Xaas.Ocel.Object` that represents a real Ash resource
  instance (e.g. `Xaas.Library.Book`) rather than an object that only ever
  existed inside this OCEL log.

  `object_type/1` uses `Ash.Resource.Info.resource?/1` (real Ash
  introspection, not a hand-maintained lookup table) so it stays correct as
  new resources are added without this module needing an update.
  """

  @doc """
  Maps a real Ash resource module + primary key value to a deterministic
  `{object_type, ocel_id}` pair.

  Returns `{:error, :not_an_ash_resource}` if `resource` is not a module
  Ash recognizes as a resource -- a real, checkable admission boundary
  rather than assuming every atom/module passed in is valid.
  """
  @spec object_ref(module(), term()) ::
          {:ok, %{object_type: String.t(), ocel_id: String.t()}}
          | {:error, :not_an_ash_resource}
  def object_ref(resource, primary_key) do
    if Ash.Resource.Info.resource?(resource) do
      {:ok, %{object_type: inspect(resource), ocel_id: to_string(primary_key)}}
    else
      {:error, :not_an_ash_resource}
    end
  end

  @doc """
  The inverse of `object_ref/2`: given an `object_type` string previously
  produced by `object_ref/2`, resolves it back to the real Ash resource
  module, if that module still exists and is still a real Ash resource.

  Returns `{:error, :unresolvable}` rather than raising when the string
  does not name a loaded, real Ash resource module -- e.g. the module was
  renamed/removed since the object was registered, or the object was never
  Ash-resource-backed in the first place (`ash_resource` nil on
  `Xaas.Ocel.Object`).
  """
  @spec resolve_object_type(String.t()) :: {:ok, module()} | {:error, :unresolvable}
  def resolve_object_type(object_type) when is_binary(object_type) do
    with {:ok, module} <- safe_to_existing_module(object_type),
         true <- Ash.Resource.Info.resource?(module) do
      {:ok, module}
    else
      _ -> {:error, :unresolvable}
    end
  end

  defp safe_to_existing_module(string) do
    # `inspect/1` on a module renders "Elixir.Foo.Bar" without the
    # "Elixir." prefix stripped for atoms already starting with an
    # uppercase letter -- real `Module.concat/1` roundtrip, guarded by
    # `to_existing_atom` semantics via String.to_existing_atom rescue below
    # so an unknown/never-loaded string cannot atom-bomb the atom table.
    {:ok, String.to_existing_atom("Elixir." <> string)}
  rescue
    ArgumentError -> {:error, :unresolvable}
  end
end
