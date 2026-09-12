defmodule Xaas.Generation.Validations.NoManualPatch do
  @moduledoc """
  Real Ash admission validation enforcing this ticket's key invariant at
  an actual Ash resource boundary: `CanonicalGraph + ManualPatch` is a
  forbidden path unless the projection is a registered irreducible
  handwritten residue.

  Wired onto `Xaas.Generation.ProjectionRecord`'s `:admit` create action.
  On admission, this validation:

    1. Reads `projection_path` off the changeset.
    2. Computes the *real* current on-disk hash of that file
       (`Xaas.Generation.HashManifest.compute_hash/1` — no mocking, a
       genuinely missing/unreadable file is a real validation error).
    3. Compares it to the changeset's declared `recorded_hash`.
    4. If they differ and the path is not in
       `Xaas.Generation.ResidueRegistry`, refuses the admission — this is
       the forbidden `CanonicalGraph + ManualPatch` path, caught at the
       Ash boundary rather than discovered later.
    5. If they differ but the path *is* registered residue, admission
       proceeds (the divergence is a declared, reasoned exception, not a
       silent one).
  """
  use Ash.Resource.Validation

  alias Xaas.Generation.{HashManifest, ResidueRegistry}

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    projection_path = Ash.Changeset.get_attribute(changeset, :projection_path)
    recorded_hash = Ash.Changeset.get_attribute(changeset, :recorded_hash)

    case HashManifest.compute_hash(projection_path) do
      {:ok, actual_hash} when actual_hash == recorded_hash ->
        :ok

      {:ok, _actual_hash} ->
        if ResidueRegistry.registered?(projection_path) do
          :ok
        else
          {:error,
           field: :recorded_hash,
           message:
             "projection at #{projection_path} diverges from its recorded generation hash " <>
               "and is not a registered irreducible handwritten residue -- this is the " <>
               "forbidden CanonicalGraph + ManualPatch path; regenerate from the canonical " <>
               "graph, or register the divergence in Xaas.Generation.ResidueRegistry with a reason"}
        end

      {:error, reason} ->
        {:error,
         field: :projection_path,
         message: "could not read projection at #{projection_path}: #{inspect(reason)}"}
    end
  end
end
