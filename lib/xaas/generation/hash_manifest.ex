defmodule Xaas.Generation.HashManifest do
  @moduledoc """
  Projection hash manifest — the required component recording a real
  SHA-256 digest of each generated projection's on-disk content, so a
  later run can detect drift without re-running any generator.

  Real, no mocking: hashes are computed by actually reading the file from
  disk (`File.read/1`) and hashing its bytes (`:crypto.hash/2`) — the same
  pattern as `Xaas.Ontology.Ex4pmStaleness.compare_content/2` elsewhere in
  this repo, generalized from a single vendored file to an arbitrary set
  of projection paths.
  """

  alias Xaas.Generation.Manifest

  @type digest :: String.t()
  @type t :: %{String.t() => digest() | {:error, term()}}

  @spec compute_hash(String.t()) :: {:ok, digest()} | {:error, term()}
  def compute_hash(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, Base.encode16(:crypto.hash(:sha256, content), case: :lower)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds a hash manifest for every projection path declared in the given
  generation manifest. Never raises: a missing/unreadable file is
  recorded as `{:error, reason}` under its own path rather than aborting
  the whole build, so one bad entry doesn't hide the rest.
  """
  @spec build(Manifest.t()) :: t()
  def build(entries) do
    entries
    |> Manifest.projection_paths()
    |> Map.new(fn path ->
      case compute_hash(path) do
        {:ok, digest} -> {path, digest}
        {:error, reason} -> {path, {:error, reason}}
      end
    end)
  end

  @doc """
  Verifies a projection's current on-disk hash against a recorded digest.
  Real falsifier target from the ticket: "the regeneration verifier
  passes on a projection whose hash does not match the projection hash
  manifest" — this function is the one honest check that must return
  `:mismatch` in exactly that case, never `:match`.
  """
  @spec verify(String.t(), digest()) :: :match | :mismatch | {:error, term()}
  def verify(path, expected_digest) do
    case compute_hash(path) do
      {:ok, ^expected_digest} -> :match
      {:ok, _other} -> :mismatch
      {:error, reason} -> {:error, reason}
    end
  end

  @spec persist(t(), String.t()) :: :ok | {:error, term()}
  def persist(hash_manifest, target_path) do
    serializable =
      Map.new(hash_manifest, fn
        {path, {:error, reason}} -> {path, "error: #{inspect(reason)}"}
        {path, digest} -> {path, digest}
      end)

    File.write(target_path, Jason.encode!(serializable, pretty: true))
  end

  @spec load(String.t()) :: {:ok, %{String.t() => digest()}} | {:error, term()}
  def load(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded} <- Jason.decode(content) do
      {:ok, decoded}
    end
  end
end
