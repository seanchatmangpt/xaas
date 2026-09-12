defmodule Xaas.Generation.ResidueRegistry do
  @moduledoc """
  Irreducible handwritten-residue registry — the required component
  naming the (hopefully small) set of files that are allowed to diverge
  from what regenerating them from the canonical graph would produce,
  each with an explicit, real reason.

  This is the ticket's designated escape valve: per the key invariant,
  `CanonicalGraph + ManualPatch` is forbidden *unless* the patched file is
  registered here. Anything not registered here that still diverges from
  its manifest hash is a real violation, not an accepted exception.

  Real, no mocking: entries are a static list edited by hand (the only
  honest way to record "a human decided this file is a deliberate
  exception") and `validate!/0` really re-checks, against the live
  filesystem, that every registered path exists — so a stale registry
  entry (residue that was since deleted or renamed) is caught rather than
  silently trusted.
  """

  @entries []

  @type entry :: %{path: String.t(), reason: String.t()}

  @spec entries() :: [entry()]
  def entries, do: @entries

  @spec registered?(String.t()) :: boolean()
  def registered?(path), do: Enum.any?(@entries, &(&1.path == path))

  @spec reason_for(String.t()) :: String.t() | nil
  def reason_for(path) do
    case Enum.find(@entries, &(&1.path == path)) do
      %{reason: reason} -> reason
      nil -> nil
    end
  end

  @doc """
  Re-validates the registry against the real filesystem: every entry
  must have a non-empty `reason` and must point at a file that actually
  exists. Returns the list of problems found (empty list = clean).
  """
  @spec validate() :: [{String.t(), :missing_reason | :file_not_found}]
  def validate do
    Enum.flat_map(@entries, fn %{path: path, reason: reason} ->
      cond do
        is_nil(reason) or reason == "" -> [{path, :missing_reason}]
        not File.exists?(path) -> [{path, :file_not_found}]
        true -> []
      end
    end)
  end
end
