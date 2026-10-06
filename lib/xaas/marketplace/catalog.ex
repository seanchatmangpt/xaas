defmodule Xaas.Marketplace.Catalog do
  @moduledoc """
  Context over the ggen-marketplace catalog projection
  (`Xaas.Marketplace.Pack`).

  `ingest/1` accepts any of:

    * a file path (binary containing a path to a real catalog file),
    * a raw catalog JSON binary,
    * an already-decoded catalog map.

  and upserts one `Pack` per `packs` entry. Upsert is keyed on `name`, so
  re-ingesting the same catalog is idempotent. Malformed input produces a
  typed `{:error, %Xaas.Marketplace.Catalog.Error{}}`, never an exception
  crossing the boundary.
  """

  require Ash.Query

  alias Xaas.Marketplace.Pack

  defmodule Error do
    @moduledoc "Typed catalog ingest error."
    defexception([:reason, :detail])

    @type t :: %__MODULE__{reason: :invalid_json | :invalid_catalog | :invalid_pack, detail: term}

    def message(%__MODULE__{reason: reason, detail: detail}) do
      "catalog ingest refused (#{reason}): #{inspect(detail)}"
    end
  end

  @catalog_schema_url "https://ggen.dev/marketplace/catalog/v2"
  @ready_flags [:gates, :readme, :verify, :witnesses]

  def catalog_schema_url, do: @catalog_schema_url

  @doc "All packs, ordered by name."
  @spec list_packs() :: [Pack.t()]
  def list_packs do
    Pack
    |> Ash.Query.sort(:name)
    |> Ash.read!(authorize?: false)
  end

  @doc "Fetch one pack by its name (primary key). Raises when absent."
  @spec get_pack!(String.t()) :: Pack.t()
  def get_pack!(name) do
    Ash.get!(Pack, name, authorize?: false)
  end

  @doc """
  Case-insensitive substring search over `name` and `description`.
  """
  @spec search(String.t()) :: [Pack.t()]
  def search(term) when is_binary(term) do
    downcased = String.downcase(term)

    Pack
    |> Ash.Query.filter(
      string_downcase(name) == ^downcased or
        contains(string_downcase(name), ^downcased) or
        contains(string_downcase(description), ^downcased)
    )
    |> Ash.Query.sort(:name)
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Ingest a catalog (path | raw JSON binary | decoded map). Returns
  `{:ok, count}` of packs now in the projection.
  """
  @spec ingest(String.t() | map()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def ingest(path) when is_binary(path) do
    if File.regular?(path) do
      with {:ok, body} <- File.read(path), do: ingest(body)
    else
      ingest_as_json(path)
    end
  end

  def ingest(%{"packs" => packs} = catalog) when is_list(packs) do
    schema = Map.get(catalog, "schema")

    if schema != @catalog_schema_url do
      {:error, %Error{reason: :invalid_catalog, detail: {:unexpected_schema, schema}}}
    else
      with :ok <- validate_packs(packs) do
        Enum.each(packs, &upsert_pack!/1)
        {:ok, Enum.count(list_packs())}
      end
    end
  end

  def ingest(other), do: {:error, %Error{reason: :invalid_catalog, detail: other}}

  defp ingest_as_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> ingest(decoded)
      {:error, reason} -> {:error, %Error{reason: :invalid_json, detail: reason}}
    end
  end

  # -- ingesters -------------------------------------------------------------

  defp validate_packs(packs) do
    packs
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {pack, i}, :ok ->
      required = ["name", "version", "digest", "download_url", "description"]

      missing = required -- Map.keys(pack)

      if missing == [] and is_binary(pack["name"]) do
        {:cont, :ok}
      else
        {:halt, {:error, %Error{reason: :invalid_pack, detail: {i, missing, pack["name"]}}}}
      end
    end)
  end

  defp upsert_pack!(pack) do
    attrs = pack_attrs(pack)

    case Ash.get(Pack, attrs.name, authorize?: false) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, Map.delete(attrs, :name), authorize?: false)
        |> Ash.update!(authorize?: false)

      _ ->
        Pack
        |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
        |> Ash.create!(authorize?: false)
    end
  end

  defp pack_attrs(pack) do
    %{
      name: pack["name"],
      version: pack["version"],
      digest: pack["digest"],
      download_url: pack["download_url"],
      lifecycle_tier: pack["lifecycle_tier"] || pack["tier"] || "unclassified",
      readiness: readiness_string(pack["readiness"]),
      pack_class: pack["pack_class"],
      ontology_fingerprint: pack["ontology_fingerprint_sha256"],
      description: pack["description"],
      deprecated: Map.get(pack, "deprecated", false)
    }
  end

  defp readiness_string(%{} = readiness) do
    @ready_flags
    |> Enum.filter(fn flag -> Map.get(readiness, to_string(flag)) == true end)
    |> Enum.join("+")
  end

  defp readiness_string(readiness) when is_binary(readiness), do: readiness
  defp readiness_string(_), do: ""
end
