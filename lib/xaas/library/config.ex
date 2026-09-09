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

  @doc """
  Returns the 6-factor recommendation weights, optionally merging with runtime overrides.
  """
  @spec weights(keyword() | map()) :: map()
  def weights(opts \\ []) do
    configured =
      Application.get_env(:xaas, :library_ranker_weights, @default_weights)

    case opts do
      %{} = override_map -> Map.merge(configured, override_map)
      kw when is_list(kw) ->
        case Keyword.get(kw, :weights) do
          nil -> configured
          %{} = override_map -> Map.merge(configured, override_map)
        end
    end
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

  @doc """
  Returns the default school identifier.
  """
  @spec default_school_id() :: String.t()
  def default_school_id do
    Application.get_env(:xaas, :library_default_school_id, "willow-creek")
  end

  @doc """
  Returns the default student grade level for recommendation previews.
  """
  @spec default_grade() :: integer()
  def default_grade do
    Application.get_env(:xaas, :library_default_grade, 6)
  end

  @doc """
  Returns the selectable grade level range.
  """
  @spec grade_range() :: Range.t()
  def grade_range do
    Application.get_env(:xaas, :library_grade_range, 1..12)
  end
end
