defmodule Xaas.Semantics.AutomationBiasCountermeasure do
  @moduledoc """
  EU AI Act Art. 14.4.b automation-bias countermeasure: mandatory
  causal-anatomy presentation for every admission decision.

  Art. 14.4.b requires measures so that natural persons using the system are
  aware that they are interacting with an AI system and can correctly
  interpret its output. Structurally, the strongest anti-over-reliance
  measure is to make blind acceptance *impossible by construction*: every
  decision arrives with its full causal anatomy — which checks fired, with
  what exact Shapley blame, and what the refusal anatomy is — and this is
  emitted for EVERY decision, including full admits. Over-reliance on the
  system is countered because admits also show their anatomy, not just
  refusals.

  This module is pure composition of the real lane surfaces:

    * `Xaas.Semantics.AdmissionAttribution` (W505) — exact Shapley blame per
      admission check over the discrete check lattice (Art. 13).
    * `Xaas.Semantics.Counterfactual` (W506) — deterministic counterfactual
      replay over the recorded decision (Art. 86); the recorded per-check
      verdict log is the structural recourse variable set.

  `briefing/2` is deterministic: same record + attributions => byte-identical
  briefing. No randomness, no wall-clock, no environment reads.
  """

  alias Xaas.Semantics.Counterfactual

  @typedoc "Recorded admission decision (W506 `decision_record` shape)."
  @type decision_record :: Counterfactual.decision_record()

  @typedoc "W505 exact-Shapley attribution map: %{check_name => phi}."
  @type attributions :: %{optional(term) => float}

  @typedoc "Operator briefing for one decision."
  @type briefing :: %{
          required(:verdict) => :admit | :refuse,
          required(:per_check_causes) => [
            %{
              required(:name) => atom() | binary(),
              required(:verdict) => :pass | :fail,
              required(:refusal) => atom() | nil,
              required(:shapley) => float()
            }
          ],
          required(:refusal_anatomy) => [
            %{required(:name) => atom() | binary(), required(:refusal) => atom() | nil}
          ],
          required(:counterfactual_available) => boolean(),
          required(:interpretability) => String.t()
        }

  @interpretability """
  counterfactual replay + exact Shapley attribution — deterministic, receipt-backed\
  """

  @doc """
  Emit the operator briefing for a recorded decision.

  Arguments:

    * `record` — the W506 decision record: `%{input:, admitted?:, refusal:,
      checks: [%{name:, verdict:, refusal:}]}` — the ordered per-check verdict
      log (the recovered structural recourse variables).
    * `attributions` — the W505 attribution map `%{check_name => φ_i}`
      (the result of `AdmissionAttribution.shapley/2` over the same checks).

  Returns `{:ok, briefing}` where:

    * `:verdict` — `:admit` when `record.admitted?` is true, else `:refuse`.
    * `:per_check_causes` — one entry per recorded check, in recorded order,
      carrying its verdict, refusal (if any), and its exact Shapley value.
    * `:refusal_anatomy` — the exact flipped checks: for a refusal, the
      recorded checks whose verdict is `:fail` (the causal delta under the
      first-refusal pipeline — flipping all of them to `:pass` flips the
      decision); for an admit, `[]` (nothing flipped, nothing caused it).
    * `:counterfactual_available` — true iff the record carries a non-empty
      ordered per-check log over the same names as the attributions, i.e. the
      receipt is faithful enough for `Counterfactual.evaluate/3` replay.
    * `:interpretability` — fixed deterministic string naming the method.

  The briefing is emitted for EVERY decision — including full admits, where
  `:refusal_anatomy` is empty but `:per_check_causes` still lists every check
  green with its (zero) attribution. That is the Art. 14.4.b structural
  countermeasure: the operator never sees an unexplained verdict.
  """
  @spec briefing(decision_record(), attributions()) ::
          {:ok, briefing()} | {:error, {:record_outcome_mismatch, term()}}
  def briefing(
        %{admitted?: admitted?, checks: checks} = record,
        attributions
      )
      when is_boolean(admitted?) and is_list(checks) and is_map(attributions) do
    with :ok <- verify_replayable(record) do
      per_check_causes =
        Enum.map(checks, fn check ->
          %{
            name: check.name,
            verdict: check.verdict,
            refusal: Map.get(check, :refusal),
            shapley: Map.get(attributions, check.name, 0.0)
          }
        end)

      refusal_anatomy = refusal_anatomy(admitted?, checks)

      {:ok,
       %{
         verdict: verdict(admitted?),
         per_check_causes: per_check_causes,
         refusal_anatomy: refusal_anatomy,
         counterfactual_available: counterfactual_available?(checks, attributions),
         interpretability: interpretability_text()
       }}
    end
  end

  defp verdict(true), do: :admit
  defp verdict(false), do: :refuse

  # Refusal anatomy = exact flipped checks: every recorded check with a
  # failing verdict. Under the W506 first-refusal pipeline, flipping all
  # failing checks to pass flips the decision; the first one in order is the
  # proximate cause.
  defp refusal_anatomy(false, checks) do
    checks
    |> Enum.filter(&(&1.verdict == :fail))
    |> Enum.map(&%{name: &1.name, refusal: Map.get(&1, :refusal)})
  end

  defp refusal_anatomy(true, _checks), do: []

  # The record is counterfactual-replayable when the full ordered per-check
  # log is present (the structural recourse variables U are witnessed) and
  # every logged name is covered by the attribution map, so replay + blame
  # are both computable from the receipt alone.
  defp counterfactual_available?(checks, attributions) do
    checks != [] and
      Enum.all?(checks, fn c ->
        Map.has_key?(attributions, c.name) and
          c.verdict in [:pass, :fail]
      end)
  end

  # The record must be a faithful witness: a recorded admit carries no
  # refusal; a recorded refusal carries its reason on the first failing
  # check. Otherwise the briefing is refused — typed, no silent presentation.
  defp verify_replayable(%{admitted?: true, refusal: refusal}) do
    if is_nil(refusal), do: :ok, else: {:error, {:admit_with_refusal, refusal}}
  end

  defp verify_replayable(%{admitted?: false, refusal: refusal, checks: checks}) do
    first_fail = Enum.find(checks, &(&1.verdict == :fail))

    cond do
      is_nil(refusal) -> {:error, {:refusal_missing_reason, checks}}
      is_nil(first_fail) -> {:error, {:refusal_without_failing_check, refusal}}
      Map.get(first_fail, :refusal) != refusal -> {:error, {:refusal_mismatch, refusal}}
      true -> :ok
    end
  end

  defp verify_replayable(_), do: {:error, :invalid_record}

  defp interpretability_text, do: @interpretability |> String.trim() |> String.replace("\n", " ")
end
