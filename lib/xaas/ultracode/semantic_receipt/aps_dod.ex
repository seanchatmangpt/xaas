defmodule Xaas.Ultracode.SemanticReceipt.ApsDod do
  @moduledoc """
  Court adapter for the `aps-dod` suite: turns the gate verdicts of
  `priv/verifiers/aps_dod_court.py` (its receipt's `observation.gates`) into
  the `acceptance_results` / `falsifier_results` the canonical work graph asks
  for. Only gates the court actually reported are used.

  A required acceptance or falsifier string is mapped when it is

    * a court gate id (`CHI-ASSERT`, ...): true only when that gate passed;
    * an observation-edge criterion (`...-acceptance-delta`): every content
      gate (`CHI-EXACT-HEAD`, `CHI-INDEPENDENT`, `CHI-SCOPE`, `CHI-MOCK`,
      `CHI-ASSERT`, `CHI-CANONICAL`) passed;
    * `...-acceptance-guard`: `CHI-MUTATION` passed;
    * `...-falsifier-delta`: `CHI-ASSERT` and `CHI-MUTATION` passed, i.e. the
      condition that was observed no longer reproduces at the candidate head.

  Anything else is left out, which the graph side reads as unobserved.
  Falsifiers are `"survived"` when the mapped gates passed and `"killed"` when
  every mapped gate was reported and one failed; a gate the court did not
  report leaves the falsifier out.
  """

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @court_iri @sj <> "court-aps-dod"
  @evidence_iri @sj <> "aps-dod-court-receipt-evidence"
  @suite_step "court"

  @doc "The WorkOrder `sj:Court` node this suite stands for."
  @spec court_iri() :: String.t()
  def court_iri, do: @court_iri

  @doc "The `sj:EvidenceRequirement` node satisfied by an ALIVE court receipt."
  @spec evidence_iri() :: String.t()
  def evidence_iri, do: @evidence_iri

  @delta_gates ~w(CHI-EXACT-HEAD CHI-INDEPENDENT CHI-SCOPE CHI-MOCK CHI-ASSERT CHI-CANONICAL)
  @guard_gates ~w(CHI-MUTATION)
  @falsifier_delta_gates ~w(CHI-ASSERT CHI-MUTATION)

  @doc """
  Binds the suite's `court` step to the WorkOrder court nodes it stands for.
  A required court IRI equal to `court_iri/0` is satisfied by the
  real result of the suite step `court`: an entry with that IRI as its `id`
  and the step's own status is appended. No step, no entry.
  """
  @spec court_steps([map()], [term()]) :: [map()]
  def court_steps(steps, required_courts) when is_list(steps) and is_list(required_courts) do
    case Enum.find(steps, &(&1["id"] == @suite_step)) do
      nil ->
        []

      %{"status" => status} ->
        for court <- required_courts,
            is_binary(court),
            court == @court_iri,
            do: %{"id" => court, "status" => status}
    end
  end

  @spec observe(map(), map()) :: map() | nil
  def observe(court_receipt, requires) when is_map(court_receipt) and is_map(requires) do
    case get_in(court_receipt, ["observation", "gates"]) do
      gates when is_list(gates) ->
        verdicts = Map.new(gates, &{&1["id"], &1["pass"] == true})

        %{
          "acceptance_results" => acceptance(requires["acceptance"] || [], verdicts),
          "falsifier_results" => falsifiers(requires["falsifiers"] || [], verdicts),
          "evidence_types" => evidence_types(court_receipt),
          "source" => Map.take(court_receipt, ~w(receiptId resultDigest standing))
        }

      _ ->
        nil
    end
  end

  def observe(_, _), do: nil

  # The court's own receipt is the observed evidence, and only an ALIVE one.
  defp evidence_types(%{"standing" => "ALIVE", "receiptId" => id}) when is_binary(id),
    do: [@evidence_iri]

  defp evidence_types(_), do: []

  defp acceptance(required, verdicts) do
    for criterion <- required,
        gates = acceptance_gates(criterion),
        gates != nil,
        into: %{} do
      {criterion, Enum.all?(gates, &(Map.get(verdicts, &1) == true))}
    end
  end

  defp falsifiers(required, verdicts) do
    for falsifier <- required,
        gates = falsifier_gates(falsifier),
        gates != nil,
        verdict = falsifier_verdict(gates, verdicts),
        verdict != nil,
        into: %{} do
      {falsifier, verdict}
    end
  end

  defp acceptance_gates(criterion) do
    cond do
      String.starts_with?(criterion, "CHI-") -> [criterion]
      String.ends_with?(criterion, "-acceptance-delta") -> @delta_gates
      String.ends_with?(criterion, "-acceptance-guard") -> @guard_gates
      true -> nil
    end
  end

  defp falsifier_gates(falsifier) do
    cond do
      String.starts_with?(falsifier, "CHI-") -> [falsifier]
      String.ends_with?(falsifier, "-falsifier-delta") -> @falsifier_delta_gates
      true -> nil
    end
  end

  defp falsifier_verdict(gates, verdicts) do
    reported = Enum.map(gates, &Map.fetch(verdicts, &1))

    cond do
      Enum.any?(reported, &(&1 == :error)) -> nil
      Enum.all?(reported, &(&1 == {:ok, true})) -> "survived"
      true -> "killed"
    end
  end
end
