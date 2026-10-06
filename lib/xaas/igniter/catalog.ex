defmodule Xaas.Igniter.Catalog do
  @moduledoc """
  Context over ggen_igniter's machine/pack surface
  (`Xaas.Igniter.RefusalCode`, `Xaas.Igniter.PackManifest`).

  * `ingest/1` loads the REAL ggen_igniter refusals schema
    (default `/Users/sac/ggen_igniter/priv/schema/refusals.schema.json`,
    137 codes) into `RefusalCode` projections.
  * `ingest_packs/1` loads a pack manifest inventory into `PackManifest`
    projections (path | raw JSON binary | decoded map; `packs` entries carry
    `pack_name`, `version`, `profile`, `gate_count`, `verify_count`,
    `misfiled_count`).

  Both upsert on their primary key, so re-ingesting is idempotent. Malformed
  input produces a typed `{:error, %Xaas.Igniter.Catalog.Error{}}`, never an
  exception crossing the boundary.
  """

  require Ash.Query

  alias Xaas.Igniter.PackManifest
  alias Xaas.Igniter.RefusalCode

  defmodule Error do
    @moduledoc "Typed igniter catalog ingest error."
    defexception([:reason, :detail])

    @type t :: %__MODULE__{
            reason: :invalid_json | :invalid_schema | :invalid_refusal | :invalid_manifest,
            detail: term
          }

    def message(%__MODULE__{reason: reason, detail: detail}) do
      "igniter catalog ingest refused (#{reason}): #{inspect(detail)}"
    end
  end

  @default_schema_path "/Users/sac/ggen_igniter/priv/schema/refusals.schema.json"

  @doc "Path of the canonical ggen_igniter refusals schema."
  @spec default_schema_path() :: Path.t()
  def default_schema_path, do: @default_schema_path

  # -- refusal projections ---------------------------------------------------

  @doc "All refusal codes, ordered by code."
  @spec list_refusals() :: [RefusalCode.t()]
  def list_refusals do
    RefusalCode
    |> Ash.Query.sort(:code)
    |> Ash.read!(authorize?: false)
  end

  @doc "Refusal codes filtered by retryability, ordered by code."
  @spec refusals_by_retryable(boolean()) :: [RefusalCode.t()]
  def refusals_by_retryable(retryable?) when is_boolean(retryable?) do
    RefusalCode
    |> Ash.Query.filter(retryable == ^retryable?)
    |> Ash.Query.sort(:code)
    |> Ash.read!(authorize?: false)
  end

  @doc "Refusal codes owned by the given module (exact match), ordered by code."
  @spec refusals_by_owner(String.t()) :: [RefusalCode.t()]
  def refusals_by_owner(owner) when is_binary(owner) do
    RefusalCode
    |> Ash.Query.filter(owner == ^owner)
    |> Ash.Query.sort(:code)
    |> Ash.read!(authorize?: false)
  end

  @doc "Count of refusal codes per family, as a sorted keyword list."
  @spec count_by_family() :: [{String.t(), non_neg_integer()}]
  def count_by_family do
    list_refusals()
    |> Enum.frequencies_by(& &1.family)
    |> Enum.sort()
  end

  @doc """
  Ingest the ggen_igniter refusals schema (path | raw JSON binary | decoded
  map). Returns `{:ok, count}` of refusal codes now projected.
  """
  @spec ingest(String.t() | map()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def ingest(path) when is_binary(path) do
    if File.regular?(path) do
      with {:ok, body} <- File.read(path), do: ingest(body)
    else
      ingest_as_json(path)
    end
  end

  def ingest(%{"refusals" => refusals} = schema) when is_list(refusals) do
    if is_binary(Map.get(schema, "$schema")) do
      case validate_refusals(refusals) do
        :ok ->
          Enum.each(refusals, &upsert_refusal!/1)
          {:ok, Enum.count(list_refusals())}

        error ->
          error
      end
    else
      {:error, %Error{reason: :invalid_schema, detail: {:missing_json_schema_key, schema}}}
    end
  end

  def ingest(other), do: {:error, %Error{reason: :invalid_schema, detail: other}}

  defp ingest_as_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> ingest(decoded)
      {:error, reason} -> {:error, %Error{reason: :invalid_json, detail: reason}}
    end
  end

  defp validate_refusals(refusals) do
    refusals
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {entry, i}, :ok ->
      required = ["code", "family", "retryable"]
      missing = required -- Map.keys(entry)

      if missing == [] and is_binary(entry["code"]) and is_boolean(entry["retryable"]) do
        {:cont, :ok}
      else
        {:halt, {:error, %Error{reason: :invalid_refusal, detail: {i, missing, entry["code"]}}}}
      end
    end)
  end

  defp upsert_refusal!(entry) do
    attrs = %{
      code: entry["code"],
      family: entry["family"],
      retryable: entry["retryable"],
      broken_term: entry["broken_term"],
      owner: entry["owner"],
      fix_hint: entry["fix_hint"]
    }

    case Ash.get(RefusalCode, attrs.code, authorize?: false) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, Map.delete(attrs, :code), authorize?: false)
        |> Ash.update!(authorize?: false)

      _ ->
        RefusalCode
        |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
        |> Ash.create!(authorize?: false)
    end
  end

  # -- pack manifest projections ----------------------------------------------

  @doc "All pack manifests, ordered by pack name."
  @spec list_packs() :: [PackManifest.t()]
  def list_packs do
    PackManifest
    |> Ash.Query.sort(:pack_name)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Ingest a pack manifest inventory (path | raw JSON binary | decoded map).
  Accepts `{"packs": [...]}` or a bare top-level list. Returns `{:ok, count}`
  of packs now projected.
  """
  @spec ingest_packs(String.t() | map() | list()) ::
          {:ok, non_neg_integer()} | {:error, Error.t()}
  def ingest_packs(path) when is_binary(path) do
    if File.regular?(path) do
      with {:ok, body} <- File.read(path), do: ingest_packs(body)
    else
      ingest_packs_as_json(path)
    end
  end

  def ingest_packs(%{"packs" => packs}) when is_list(packs), do: do_ingest_packs(packs)
  def ingest_packs(packs) when is_list(packs), do: do_ingest_packs(packs)

  def ingest_packs(other), do: {:error, %Error{reason: :invalid_manifest, detail: other}}

  defp ingest_packs_as_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> ingest_packs(decoded)
      {:error, reason} -> {:error, %Error{reason: :invalid_json, detail: reason}}
    end
  end

  defp do_ingest_packs(packs) do
    case validate_packs(packs) do
      :ok ->
        Enum.each(packs, &upsert_pack!/1)
        {:ok, Enum.count(list_packs())}

      error ->
        error
    end
  end

  defp validate_packs(packs) do
    packs
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {pack, i}, :ok ->
      required = ["pack_name", "version"]
      missing = required -- Map.keys(pack)

      if missing == [] and is_binary(pack["pack_name"]) do
        {:cont, :ok}
      else
        {:halt,
         {:error, %Error{reason: :invalid_manifest, detail: {i, missing, pack["pack_name"]}}}}
      end
    end)
  end

  defp upsert_pack!(pack) do
    attrs = %{
      pack_name: pack["pack_name"],
      version: pack["version"],
      profile: pack["profile"],
      gate_count: pack["gate_count"] || 0,
      verify_count: pack["verify_count"] || 0,
      misfiled_count: pack["misfiled_count"] || 0
    }

    case Ash.get(PackManifest, attrs.pack_name, authorize?: false) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, Map.delete(attrs, :pack_name), authorize?: false)
        |> Ash.update!(authorize?: false)

      _ ->
        PackManifest
        |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
        |> Ash.create!(authorize?: false)
    end
  end
end
