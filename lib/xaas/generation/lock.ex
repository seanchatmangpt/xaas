defmodule Xaas.Generation.Lock do
  @moduledoc """
  Deterministic generation lock — the required component that fixes, as
  a single reproducible digest, the exact set of `{projection_path,
  hash}` pairs a generation run is allowed to have produced.

  Real, deterministic: the digest is computed over the hash manifest
  sorted by path (never over map iteration order, which Elixir does not
  guarantee), so two processes computing the lock for the same real hash
  manifest always get the same digest — the actual property "deterministic"
  requires, not just an unverified claim of determinism.
  """

  alias Xaas.Generation.HashManifest

  @type t :: String.t()

  @spec build(HashManifest.t()) :: t()
  def build(hash_manifest) do
    canonical =
      hash_manifest
      |> Enum.map(fn
        {path, {:error, reason}} -> "#{path}\0error:#{inspect(reason)}"
        {path, digest} -> "#{path}\0#{digest}"
      end)
      |> Enum.sort()
      |> Enum.join("\n")

    Base.encode16(:crypto.hash(:sha256, canonical), case: :lower)
  end

  @doc "Returns :match if `hash_manifest` reproduces the given lock digest exactly."
  @spec verify(HashManifest.t(), t()) :: :match | :mismatch
  def verify(hash_manifest, expected_lock) do
    if build(hash_manifest) == expected_lock, do: :match, else: :mismatch
  end
end
