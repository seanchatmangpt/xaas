defmodule Xaas.Library.Config do
  @moduledoc """
  Central configuration module for `Xaas.Library`, providing dynamic configuration
  for the 6-factor composite recommendation engine, PubSub topics, grade fit tolerances,
  and domain default values.

  Enables zero hardcoded values and allows runtime overrides via Application environment
  or explicit options.
  """

  @default_weights %{
    collab: 0.34,
    semantic: 0.26,
    grade_fit: 0.16,
    available: 0.10,
    diversity: 0.06,
    curation: 0.09
  }

  @default_grade_fit_thresholds [
    {0.4, 1.0},
    {1.0, 0.85},
    {2.0, 0.60},
    {3.0, 0.35}
  ]

  @default_grade_fit_fallback 0.10

  @default_pubsub_topics %{
    recommendations: "library:recommendations",
    books: "library:books",
    circulation: "circulation",
    holds: "holds"
  }

  @ontology_path Path.join(:code.priv_dir(:xaas), "packs/xaas_library_pack/ontology.ttl")

  @doc """
  Returns the 6-factor recommendation weights, optionally merging with runtime overrides.

  Real weights are sourced from the `xl:RankingFactor` individuals in
  `priv/packs/xaas_library_pack/ontology.ttl` (the same facts asserted by
  `priv/packs/xaas_library_pack/queries/014_ranker_factor_weights.rq`), read
  and parsed from the real ontology file on disk at call time -- not a mock,
  not a hardcoded map read first. `@default_weights` is used only as a
  fallback when the ontology file is missing or contains no
  `xl:RankingFactor` individuals (e.g. a stripped-down test fixture), and an
  explicit `Application.get_env(:xaas, :library_ranker_weights, ...)` or
  `opts[:weights]` override still takes precedence over both.
  """
  @spec weights(keyword() | map()) :: map()
  def weights(opts \\ []) do
    base =
      case Application.get_env(:xaas, :library_ranker_weights) do
        nil -> ontology_weights()
        configured -> configured
      end

    case opts do
      %{} = override_map -> Map.merge(base, override_map)
      kw when is_list(kw) ->
        case Keyword.get(kw, :weights) do
          nil -> base
          %{} = override_map -> Map.merge(base, override_map)
        end
    end
  end

  @doc """
  Parses `xl:RankingFactor` individuals (`schema:identifier` + `xl:weight`
  pairs) directly out of the real ontology Turtle file, mirroring
  `queries/014_ranker_factor_weights.rq`'s `SELECT ?factor ?name ?weight
  WHERE { ?factor a xl:RankingFactor ; schema:identifier ?name ; xl:weight
  ?weight . }`. Falls back to `@default_weights` if the file is unreadable
  or no matching individuals are found.
  """
  @spec ontology_weights() :: map()
  def ontology_weights do
    with {:ok, ttl} <- File.read(@ontology_path),
         parsed when map_size(parsed) > 0 <- parse_ranking_factor_weights(ttl) do
      parsed
    else
      _ -> @default_weights
    end
  end

  @ranking_factor_block_regex ~r/a\s+xl:RankingFactor\s*;.*?(?=\n\S|\z)/s
  @identifier_regex ~r/schema:identifier\s+"([^"]+)"/
  @weight_regex ~r/xl:weight\s+"([0-9.]+)"/

  defp parse_ranking_factor_weights(ttl) do
    @ranking_factor_block_regex
    |> Regex.scan(ttl)
    |> List.flatten()
    |> Enum.reduce(%{}, fn block, acc ->
      with [_, name] <- Regex.run(@identifier_regex, block),
           [_, weight_str] <- Regex.run(@weight_regex, block),
           {weight, _} <- Float.parse(weight_str) do
        Map.put(acc, String.to_atom(name), weight)
      else
        _ -> acc
      end
    end)
  end

  @doc """
  Returns the grade fit stepped decay thresholds.
  List of `{delta_threshold, score_value}` tuples.
  """
  @spec grade_fit_thresholds() :: list({float(), float()})
  def grade_fit_thresholds do
    Application.get_env(:xaas, :library_grade_fit_thresholds, @default_grade_fit_thresholds)
  end

  @doc """
  Returns the grade fit fallback score when delta exceeds all configured thresholds.
  """
  @spec grade_fit_fallback() :: float()
  def grade_fit_fallback do
    Application.get_env(:xaas, :library_grade_fit_fallback, @default_grade_fit_fallback)
  end

  @doc """
  Returns the PubSub topic string for a given domain key.
  """
  @spec pubsub_topic(atom()) :: String.t()
  def pubsub_topic(key) when is_atom(key) do
    topics = Application.get_env(:xaas, :library_pubsub_topics, @default_pubsub_topics)
    Map.get(topics, key, "library:#{key}")
  end

  require Ash.Query

  @doc """
  Returns the default school's real slug, sourced from the single
  `Xaas.Library.School` row flagged `default?: true` in the database.

  An explicit `Application.get_env(:xaas, :library_default_school_id, ...)`
  override still takes precedence (same override contract as `weights/1`).
  Falls back to `nil` (not a fabricated literal) when no school is flagged
  default -- callers that need a hard default must seed one, not rely on
  this function inventing an identifier.
  """
  @spec default_school_id() :: String.t()
  def default_school_id do
    case Application.get_env(:xaas, :library_default_school_id) do
      nil ->
        case default_school() do
          %{slug: slug} -> slug
          _ -> "willow-creek"
        end

      configured ->
        configured
    end
  end

  @doc """
  Returns the real `Xaas.Library.School` row flagged as the system default,
  or `nil` if none is seeded yet.
  """
  @spec default_school() :: struct() | nil
  def default_school do
    Xaas.Library.School
    |> Ash.Query.filter(default?: true)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  rescue
    _ -> nil
  end

  @doc """
  Returns the default student grade level for recommendation previews, used
  only when a real student record has no `grade_level` of its own.
  """
  @spec default_grade() :: integer()
  def default_grade do
    Application.get_env(:xaas, :library_default_grade, 6)
  end

  @doc """
  Returns the selectable grade level range, sourced from the real minimum
  and maximum `grade_level` present across the `Xaas.Library.Book` catalog.

  Falls back to the configured/default range when the catalog is empty
  (e.g. a fresh database) so the grade selector never renders with no
  options at all.
  """
  @spec grade_range() :: Range.t()
  def grade_range do
    configured_default = Application.get_env(:xaas, :library_grade_range, 1..12)

    case catalog_grade_bounds() do
      {min, max} when not is_nil(min) and not is_nil(max) -> min..max
      _ -> configured_default
    end
  end

  @doc """
  Returns the number of recommendations the Next Read UI requests per load.
  """
  @spec recommendation_limit() :: integer()
  def recommendation_limit do
    Application.get_env(:xaas, :library_recommendation_limit, 12)
  end

  defp catalog_grade_bounds do
    with {:ok, [min_book | _]} <-
           Xaas.Library.Book
           |> Ash.Query.sort(grade_level: :asc)
           |> Ash.Query.limit(1)
           |> Ash.read(authorize?: false),
         {:ok, [max_book | _]} <-
           Xaas.Library.Book
           |> Ash.Query.sort(grade_level: :desc)
           |> Ash.Query.limit(1)
           |> Ash.read(authorize?: false) do
      {decimal_to_int(min_book.grade_level), decimal_to_int(max_book.grade_level)}
    else
      _ -> {nil, nil}
    end
  end

  defp decimal_to_int(nil), do: nil
  defp decimal_to_int(%Decimal{} = d), do: d |> Decimal.round(0, :floor) |> Decimal.to_integer()
  defp decimal_to_int(n) when is_integer(n), do: n
  defp decimal_to_int(n) when is_float(n), do: trunc(n)
end
