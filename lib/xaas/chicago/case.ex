defmodule Xaas.Chicago.Case do
  @moduledoc """
  Chicago candidate cases (`sj:Prediction` individuals rendered into the
  machine projection's `cases` array).

  Standing law (R8): every rendered case is a candidate prediction whose
  `observedStanding` is `"UNKNOWN"`. A case is never an observation, receipt,
  authority grant or standing claim. The loader refuses any projection whose
  cases pre-judge an outcome (hardcoded outcomes, fake receipts, standing
  inherited across layers) — the `origin/feat/pradyot-monday-surface-v26.10.1`
  failure class stays out of the demo source by construction.
  """

  @case_keys ~w(id label description subject candidateOnly authorityClaim observedStanding)

  @spec required_keys :: [String.t()]
  def required_keys, do: @case_keys

  @doc "All machine cases in rendered order; validated input assumed."
  @spec list(map) :: [map]
  def list(machine), do: machine["cases"]

  @spec fetch(map, String.t()) :: {:ok, map} | {:refused, {:chicago_case_unknown, term}}
  def fetch(machine, id) do
    case Enum.find(list(machine), fn c -> c["id"] == id end) do
      nil -> {:refused, {:chicago_case_unknown, id}}
      case_map -> {:ok, case_map}
    end
  end

  @doc """
  Baseline court request built from a machine case: the case supplies the exact
  subject and `authorityClaim: "NONE"`; the caller supplies the request-specific
  params (principal, amount, dispatch outcome, evidence, receipt).
  """
  @spec request_from_case(map, map) :: map
  def request_from_case(case_map, overrides \\ %{}) do
    Map.merge(
      %{
        case_id: case_map["id"],
        subject: case_map["subject"],
        authority_claim: case_map["authorityClaim"],
        dispatch: nil,
        evidence: nil,
        receipt: nil
      },
      overrides
    )
  end
end
