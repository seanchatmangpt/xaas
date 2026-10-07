defmodule Xaas.Semantics.EuAiActAdmission do
  @moduledoc """
  Typed admission profile over candidate intent maps, rendering the eight
  prohibited-practice partitions of EU AI Act Art. 5(1)(a)-(h) as
  *unrepresentable inputs* rather than content-screened verdicts.

  ## Constructive nullification, not content sniffing

  The dissertation equation realized here is: a prohibited practice is not a
  string to be classified but a *shape* that the admission schema cannot
  express. Each Art. 5(1) partition maps to a structural disjointness check
  over schema-level fields of the candidate intent map:

  | Art. 5(1) | refusal atom | structural invariant (field/context disjointness) |
  |---|---|---|
  | (a) manipulative/subliminal/deceptive | `REFUSED_EUAIA_MANIPULATIVE` | no `:manipulate_behavior`/`:deceptive`/`:subliminal` technique class |
  | (a) vulnerability exploit | `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | no cross-join of an audience slice with a vulnerability predicate |
  | (b) social scoring | `REFUSED_EUAIA_SOCIAL_SCORING` | no join of `:social_behavior` data into an unrelated decision context |
  | (c) predictive policing | `REFUSED_EUAIA_PREDICTIVE_POLICING` | no individualized join under a `:predict_offending` purpose |
  | (d) untargeted facial scraping | `REFUSED_EUAIA_FACIAL_SCRAPING` | `:facial_images` domain admits only `:consented` provenance |
  | (e) emotion recognition | `REFUSED_EUAIA_EMOTION_RECOGNITION` | no `:affective` data domain in `:workplace`/`:education` settings |
  | (f) biometric categorization | `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | biometric match tokens are boolean-only; no sensitive `:inferences` |
  | (g)/(h) realtime RBI | `REFUSED_EUAIA_REALTIME_RBI` | no `:realtime` latency goal under biometric identification in `:public_space` |

  A candidate that expresses none of the prohibited shapes is admitted
  regardless of its content. The check never inspects free text, model
  output, or user data — only the declared intent schema.

  This module is an admission surface only. It never grants authority, never
  actuates, and is wired into no live route (integration is a later lane).
  """

  @typedref_atoms [
    :REFUSED_EUAIA_MANIPULATIVE,
    :REFUSED_EUAIA_VULNERABILITY_EXPLOIT,
    :REFUSED_EUAIA_SOCIAL_SCORING,
    :REFUSED_EUAIA_PREDICTIVE_POLICING,
    :REFUSED_EUAIA_FACIAL_SCRAPING,
    :REFUSED_EUAIA_EMOTION_RECOGNITION,
    :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
    :REFUSED_EUAIA_REALTIME_RBI
  ]

  @type refusal_atom ::
          :REFUSED_EUAIA_MANIPULATIVE
          | :REFUSED_EUAIA_VULNERABILITY_EXPLOIT
          | :REFUSED_EUAIA_SOCIAL_SCORING
          | :REFUSED_EUAIA_PREDICTIVE_POLICING
          | :REFUSED_EUAIA_FACIAL_SCRAPING
          | :REFUSED_EUAIA_EMOTION_RECOGNITION
          | :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION
          | :REFUSED_EUAIA_REALTIME_RBI

  @typedoc "Structural intent schema. Only these fields are inspected."
  @type candidate :: %{
          optional(:id) => term(),
          optional(:techniques) => [atom()],
          optional(:purpose) => atom(),
          optional(:data_domains) => [atom()],
          optional(:provenance) => atom(),
          optional(:context_joins) => [atom()],
          optional(:setting) => atom(),
          optional(:latency_goal) => atom(),
          optional(:inferences) => [atom()],
          optional(:match_token_type) => atom(),
          optional(atom()) => term()
        }

  @type verdict :: {:ok, :admitted} | {:error, refusal_atom()}

  @doc "The eight typed Art. 5(1) refusal atoms, in article order."
  @spec refusal_atoms() :: [refusal_atom(), ...]
  def refusal_atoms, do: @typedref_atoms

  @doc "Human-readable Art. 5(1) partition for a refusal atom."
  @spec describe(refusal_atom()) :: String.t()
  def describe(:REFUSED_EUAIA_MANIPULATIVE),
    do: "Art. 5(1)(a) manipulative, deceptive or subliminal techniques"

  def describe(:REFUSED_EUAIA_VULNERABILITY_EXPLOIT),
    do: "Art. 5(1)(a) exploitation of vulnerabilities (age, disability, social/economic situation)"

  def describe(:REFUSED_EUAIA_SOCIAL_SCORING),
    do: "Art. 5(1)(b) social scoring by unrelated contexts"

  def describe(:REFUSED_EUAIA_PREDICTIVE_POLICING),
    do: "Art. 5(1)(c) individualized predictive policing"

  def describe(:REFUSED_EUAIA_FACIAL_SCRAPING),
    do: "Art. 5(1)(d) untargeted scraping of facial images"

  def describe(:REFUSED_EUAIA_EMOTION_RECOGNITION),
    do: "Art. 5(1)(e) emotion recognition in workplace/education"

  def describe(:REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION),
    do: "Art. 5(1)(f) biometric categorization inferring sensitive attributes"

  def describe(:REFUSED_EUAIA_REALTIME_RBI),
    do: "Art. 5(1)(g)-(h) realtime remote biometric identification in public space"

  @doc """
  Admit one candidate intent map. Checks run in article order (a)-(h) and the
  first violated structural invariant returns its exact typed refusal atom.
  """
  @spec admit(candidate() | term()) :: verdict()
  def admit(candidate) when is_map(candidate) do
    Enum.reduce_while(checks(candidate), {:ok, :admitted}, fn {check, refusal}, acc ->
      if check.(candidate) do
        {:halt, {:error, refusal}}
      else
        {:cont, acc}
      end
    end)
  end

  def admit(_other), do: {:error, :REFUSED_EUAIA_MALFORMED_CANDIDATE}

  # -- structural invariants (a)-(h), in article order ------------------------

  defp checks(_candidate) do
    [
      # (a) manipulative / deceptive / subliminal technique class
      {fn c -> manipulative_technique?(c) end, :REFUSED_EUAIA_MANIPULATIVE},
      # (a) vulnerability exploit: audience slice joined with a vulnerability predicate
      {fn c -> vulnerability_join?(c) end, :REFUSED_EUAIA_VULNERABILITY_EXPLOIT},
      # (b) social scoring: social-behavior data joined into an unrelated decision context
      {fn c -> social_scoring_join?(c) end, :REFUSED_EUAIA_SOCIAL_SCORING},
      # (c) predictive policing: offend-prediction purpose with an individualized join
      {fn c -> predictive_policing_join?(c) end, :REFUSED_EUAIA_PREDICTIVE_POLICING},
      # (d) facial images of non-consented (scraped) provenance
      {fn c -> scraped_facial?(c) end, :REFUSED_EUAIA_FACIAL_SCRAPING},
      # (e) affective-state domain present in workplace/education settings
      {fn c -> affective_in_context?(c) end, :REFUSED_EUAIA_EMOTION_RECOGNITION},
      # (f) biometric surface with sensitive inference fields or non-boolean match tokens
      {fn c -> biometric_inference?(c) end, :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION},
      # (g)/(h) realtime biometric identification goal in public space
      {fn c -> realtime_rbi?(c) end, :REFUSED_EUAIA_REALTIME_RBI}
    ]
  end

  defp manipulative_technique?(c) do
    techniques = wrap_field(Map.get(c, :techniques, []))

    Enum.any?(techniques, &(&1 in [:manipulate_behavior, :deceptive, :subliminal]))
  end

  defp vulnerability_join?(c) do
    techniques = wrap_field(Map.get(c, :techniques, []))

    Enum.any?(techniques, &(&1 in [:exploit_vulnerability, :target_vulnerable_audience]))
  end

  defp social_scoring_join?(c) do
    domains = wrap_field(Map.get(c, :data_domains, []))
    joins = wrap_field(Map.get(c, :context_joins, []))

    :social_behavior in domains and :unrelated_context_join in joins
  end

  defp predictive_policing_join?(c) do
    Map.get(c, :purpose) == :predict_offending and
      :individualized_profile_join in wrap_field(Map.get(c, :context_joins, []))
  end

  defp scraped_facial?(c) do
    :facial_images in wrap_field(Map.get(c, :data_domains, [])) and
      Map.get(c, :provenance) != :consented
  end

  defp affective_in_context?(c) do
    :affective in wrap_field(Map.get(c, :data_domains, [])) and
      Map.get(c, :setting) in [:workplace, :education]
  end

  defp biometric_inference?(c) do
    biometric_surface?(c) and
      (Map.get(c, :inferences, []) != [] or Map.get(c, :match_token_type, :boolean) != :boolean)
  end

  defp realtime_rbi?(c) do
    Map.get(c, :setting) == :public_space and
      :biometric_identification in wrap_field(Map.get(c, :data_domains, [])) and
      Map.get(c, :latency_goal) == :realtime
  end

  defp biometric_surface?(c) do
    domains = wrap_field(Map.get(c, :data_domains, []))
    :biometric in domains or :facial_images in domains
  end

  # W630 totality: List.wrap/1 passes IMPROPER lists (e.g. [1 | 2]) straight
  # through, and Enumerable is not implemented for them — Enum.any?/2 would
  # raise Protocol.UndefinedError. An improper list is normalized here as an
  # OPAQUE LEAF (wrapped in a proper singleton list), so the structural
  # checks run and return their typed atoms.
  defp wrap_field(value) do
    if proper_list?(value), do: value, else: [value]
  end

  defp proper_list?(list) do
    # :lists.reverse/1 raises ArgumentError on an improper list; the rescue
    # keeps this total without a hand-rolled hare/tortoise walk.
    try do
      is_list(:lists.reverse(list))
    rescue
      # improper lists raise ArgumentError; binaries/non-lists raise FunctionClauseError
      _e in [ArgumentError, FunctionClauseError] -> false
    end
  end
end
