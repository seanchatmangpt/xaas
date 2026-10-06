defmodule Xaas.Graphlaw.Catalog do
  @moduledoc """
  Ingest graphlaw's capability registry into the `Xaas.Graphlaw` resources.

  The registry JSON is the canonical source. `ingest/1` maps:

  - `limits` (a map of name -> integer value) joined with `limit_meta`
    (scope/source/unit and the optional engine refusal name) into
    `Xaas.Graphlaw.EngineLimit` rows;
  - `authorities` (capability/authority pairs) into
    `Xaas.Graphlaw.Capability` rows, with the graphlaw version as the
    ingestion profile and `supported_in` derived by matching the authority's
    engine prefix (e.g. `purrdf::sparql` -> `PurRdf`) against the registry's
    declared engine list.

  Ingest is idempotent per (name[, algorithm]) identity via upserts.
  """

  require Ash.Query

  @default_registry_path "/Users/sac/graphlaw/registry/capability-registry.json"

  @spec default_registry_path() :: Path.t()
  def default_registry_path, do: @default_registry_path

  @doc """
  Ingests the registry at `path` (default: the graphlaw checkout's
  capability-registry.json). Returns `{:ok, counts}` with
  `%{limits: n, capabilities: m}` on success.
  """
  @spec ingest(Path.t()) :: {:ok, %{limits: non_neg_integer(), capabilities: non_neg_integer()}} | {:error, term()}
  def ingest(path \\ default_registry_path()) do
    with {:ok, body} <- File.read(path),
         {:ok, registry} <- Jason.decode(body) do
      limits = ingest_limits(registry)
      capabilities = ingest_capabilities(registry)

      {:ok, %{limits: limits, capabilities: capabilities}}
    end
  end

  @doc "All engine limits whose scope is `scope`."
  @spec limits_by_scope(String.t()) :: [Xaas.Graphlaw.EngineLimit.t()]
  def limits_by_scope(scope) when is_binary(scope) do
    Xaas.Graphlaw.EngineLimit
    |> Ash.Query.filter(scope == ^scope)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!()
  end

  ## Ingest internals

  defp ingest_limits(registry) do
    limits = registry["limits"] || %{}
    meta = registry["limit_meta"] || %{}

    limits
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.map(fn {name, value} ->
      info = meta[name] || %{}

      %{
        name: name,
        value: value,
        scope: info["scope"] || "unknown",
        source: info["source"] || "unknown",
        unit: info["unit"] || "count",
        refusal_name: Map.get(info, "refusal_name")
      }
    end)
    |> Enum.map(&create_engine_limit!/1)
    |> length()
  end

  defp create_engine_limit!(attrs) do
    Xaas.Graphlaw.EngineLimit
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  defp ingest_capabilities(registry) do
    engines = registry["engines"] || []
    version = registry["graphlaw_version"]
    authorities = registry["authorities"] || []

    authorities
    |> Enum.sort_by(fn %{"capability" => cap, "authority" => alg} -> {cap, alg} end)
    |> Enum.map(fn %{"capability" => cap, "authority" => alg} ->
      %{
        name: cap,
        algorithm: alg,
        profile: version,
        supported_in: supporting_engines(alg, engines)
      }
    end)
    |> Enum.map(&create_capability!/1)
    |> length()
  end

  # `purrdf::sparql` -> engine `PurRdf`; case-insensitive match against the
  # registry's declared engine list. Unknown prefixes support nothing.
  defp supporting_engines(authority, engines) do
    base =
      authority
      |> String.split("::")
      |> List.first()
      |> String.downcase()

    Enum.filter(engines, fn engine ->
      String.downcase(engine) == base
    end)
  end

  defp create_capability!(attrs) do
    Xaas.Graphlaw.Capability
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end
end
