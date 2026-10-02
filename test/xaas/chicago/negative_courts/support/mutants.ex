defmodule Xaas.Chicago.NegativeCourts.Mutants do
  @moduledoc """
  Lane L8 negative-court support: static graph courts + in-memory anti-vacuity
  mutants over `docs/sjira/v26.10.1/{chicago,goal}.ttl`, and the runtime
  harness against `Xaas.Chicago.Court` (RESOLUTIONS.md R4).

  Loaded via `Code.require_file/2` from the sibling `*_test.exs` files (this
  directory is not on `elixirc_paths`; each test file pulls it in explicitly).

  Standing law (R8): every case is a candidate with standing UNKNOWN; no court
  in this module ever promotes standing — even admitted candidate outcomes
  keep `standing: "UNKNOWN"`.
  """

  import ExUnit.Assertions

  alias Xaas.Chicago.Court

  @repo_root Path.expand("../../../../..", __DIR__)
  @subject "urn:chicago:agentic-payment:purchase-001"
  @foreign_subject "urn:chicago:agentic-payment:purchase-999"
  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @chi "https://ggen-igniter.dev/sjira/v26.10.1/chicago#"
  @root_checkpoint :"GC-XAAS-26.10.1-CHICAGO"

  # Contract refusal atoms (RESOLUTIONS.md R4, exact set).
  @refusal_values [
    :above_delegated_limit,
    :wrong_principal,
    :delegation_expired,
    :provider_unavailable,
    :unknown_after_dispatch,
    :missing_evidence,
    :stale_subject,
    :policy_drift,
    :authority_none
  ]

  # The ten candidate cases of chicago.ttl, in graph order.
  @case_locals [
    :"case-authorized-bounded",
    :"case-over-limit",
    :"case-wrong-principal",
    :"case-expired-delegation",
    :"case-provider-unavailable",
    :"case-unknown-after-dispatch",
    :"case-missing-evidence",
    :"case-stale-subject",
    :"case-policy-drift",
    :"case-surface-no-authority"
  ]

  ## Contract accessors #######################################################

  def refusal_values, do: @refusal_values
  def subject, do: @subject
  def foreign_subject, do: @foreign_subject
  def case_locals, do: @case_locals
  def root_checkpoint_local, do: @root_checkpoint

  def case_identifiers do
    Enum.map(1..10, &"CHI-CASE-#{&1 |> Integer.to_string() |> String.pad_leading(3, "0")}")
  end

  @doc "Negative case identifier -> its contract refusal atom (R4)."
  def case_refusal_atom(id) do
    %{
      "CHI-CASE-002" => :above_delegated_limit,
      "CHI-CASE-003" => :wrong_principal,
      "CHI-CASE-004" => :delegation_expired,
      "CHI-CASE-005" => :provider_unavailable,
      "CHI-CASE-006" => :unknown_after_dispatch,
      "CHI-CASE-007" => :missing_evidence,
      "CHI-CASE-008" => :stale_subject,
      "CHI-CASE-009" => :policy_drift,
      "CHI-CASE-010" => :authority_none
    }
    |> Map.fetch!(id)
  end

  ## Graph IO + vocabulary ####################################################

  def read_chicago, do: RDF.Turtle.read_file!(Path.join(@repo_root, "docs/sjira/v26.10.1/chicago.ttl"))
  def read_goal, do: RDF.Turtle.read_file!(Path.join(@repo_root, "docs/sjira/v26.10.1/goal.ttl"))

  def sj(name), do: RDF.iri(@sj <> Atom.to_string(name))
  def chi(local), do: RDF.iri(@chi <> Atom.to_string(local))
  def dcterms(name), do: RDF.iri("http://purl.org/dc/terms/" <> Atom.to_string(name))
  def rdf_type, do: RDF.NS.RDF.type()

  def triples(graph), do: RDF.Graph.triples(graph)

  def typed_subjects(graph, type_iri) do
    graph
    |> triples()
    |> Enum.filter(fn {_s, p, o} -> p == rdf_type() and o == type_iri end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
  end

  def prediction_subjects(graph), do: typed_subjects(graph, sj(:Prediction))
  def workorder_subjects(graph), do: typed_subjects(graph, sj(:WorkOrder))
  def receipt_subjects(graph), do: typed_subjects(graph, sj(:Receipt))
  def checkpoint_subjects(graph), do: typed_subjects(graph, sj(:GoalCheckpoint))

  def identifier(graph, subject) do
    graph |> RDF.Graph.get(subject) |> RDF.Description.first(dcterms(:identifier)) |> RDF.Literal.value()
  end

  @doc "Single-valued literal object of `{subject, predicate}`, or nil."
  def literal_object(graph, subject, predicate) do
    graph |> RDF.Graph.get(subject) |> RDF.Description.first(predicate)
  end

  ## Static graph courts (violation lists; [] == conformant) ##################

  @doc "Court over chicago.ttl: candidate-only case law (R2/R8)."
  def chicago_graph_violations(graph) do
    preds = prediction_subjects(graph)

    Enum.concat([
      if(length(preds) == 10, do: [], else: [{:prediction_count, length(preds)}]),
      identifier_set_violation(graph, preds),
      Enum.flat_map(preds, &case_violations(graph, &1))
    ])
  end

  @doc "Court over goal.ttl (+chicago.ttl): no authored WorkOrder/Receipt, 12 layers, stopQuery, ceiling CONSTRUCT."
  def goal_graph_violations(goal, chicago) do
    root = chi(@root_checkpoint)
    layers = checkpoint_subjects(goal) |> Enum.reject(&(&1 == root))

    Enum.concat([
      authored_violations(goal),
      authored_violations(chicago),
      if(length(layers) == 12, do: [], else: [{:layer_count, length(layers)}]),
      stop_query_violations(goal, layers),
      ceiling_violations(goal, [root | layers]),
      has_part_violations(goal, root)
    ])
  end

  defp identifier_set_violation(graph, preds) do
    ids = Enum.map(preds, &identifier(graph, &1)) |> Enum.sort()

    if ids == Enum.sort(case_identifiers()) do
      []
    else
      [{:case_identifier_set, ids}]
    end
  end

  defp case_violations(graph, subject) do
    id = identifier(graph, subject)

    [
      standing_violation(graph, subject, id),
      authority_violation(graph, subject, id),
      candidate_violation(graph, subject, id),
      subject_violation(graph, subject, id)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp standing_violation(graph, subject, id) do
    if literal_object(graph, subject, sj(:observedStanding)) == RDF.literal("UNKNOWN") do
      nil
    else
      {:standing_not_unknown, id}
    end
  end

  defp authority_violation(graph, subject, id) do
    if literal_object(graph, subject, sj(:authorityClaim)) == RDF.literal("NONE") do
      nil
    else
      {:authority_claimed, id}
    end
  end

  defp candidate_violation(graph, subject, id) do
    if literal_object(graph, subject, sj(:candidateOnly)) == RDF.literal(true) do
      nil
    else
      {:candidate_only_false, id}
    end
  end

  # `sj:subject` objects are exact LITERALS (R2); a foreign value drifts, an
  # IRI-typed object violates the literal-only law even at the same string.
  defp subject_violation(graph, subject, id) do
    object = literal_object(graph, subject, sj(:subject))

    cond do
      is_struct(object, RDF.Literal) and RDF.Literal.value(object) == @subject -> nil
      is_struct(object, RDF.IRI) -> {:subject_not_literal, id}
      true -> {:subject_drift, id}
    end
  end

  defp authored_violations(graph) do
    Enum.concat([
      case Enum.count(workorder_subjects(graph)) do
        0 -> []
        n -> [{:authored_workorder, n}]
      end,
      case Enum.count(receipt_subjects(graph)) do
        0 -> []
        n -> [{:authored_receipt, n}]
      end
    ])
  end

  defp stop_query_violations(goal, layers) do
    Enum.flat_map(layers, fn layer ->
      value =
        goal
        |> RDF.Graph.get(layer)
        |> RDF.Description.first(sj(:stopQuery))
        |> case do
          %RDF.Literal{} = literal -> RDF.Literal.value(literal) |> to_string() |> String.trim()
          _ -> nil
        end

      if is_binary(value) and value != "" do
        []
      else
        [{:missing_stop_query, identifier(goal, layer)}]
      end
    end)
  end

  defp ceiling_violations(goal, subjects) do
    Enum.flat_map(subjects, fn subject ->
      value =
        goal
        |> RDF.Graph.get(subject)
        |> RDF.Description.first(sj(:authorityCeiling))
        |> RDF.Literal.value()

      if value == "CONSTRUCT" do
        []
      else
        [{:authority_ceiling, identifier(goal, subject), value}]
      end
    end)
  end

  defp has_part_violations(goal, root) do
    parts = goal |> RDF.Graph.get(root) |> RDF.Description.get(dcterms(:hasPart), [])

    case Enum.count(parts) do
      12 -> []
      n -> [{:has_part_count, n}]
    end
  end

  ## In-memory anti-vacuity mutants ###########################################
  ## A court that can never refuse carries no bits: each mutant flips exactly
  ## one source fact and MUST be flagged by the matching court.

  def mutate_standing(graph, local, new \\ "ALIVE"),
    do: replace_literal(graph, chi(local), sj(:observedStanding), RDF.literal(new))

  def mutate_authority_claim(graph, local, new \\ "DO"),
    do: replace_literal(graph, chi(local), sj(:authorityClaim), RDF.literal(new))

  def mutate_subject(graph, local),
    do: replace_literal(graph, chi(local), sj(:subject), RDF.literal(@foreign_subject))

  def mutate_subject_to_iri(graph, local),
    do: replace_literal(graph, chi(local), sj(:subject), RDF.iri(@foreign_subject))

  def inject_workorder(graph, local), do: RDF.Graph.add(graph, {chi(local), rdf_type(), sj(:WorkOrder)})

  def inject_receipt(graph, local), do: RDF.Graph.add(graph, {chi(local), rdf_type(), sj(:Receipt)})

  def mutate_ceiling(graph, new \\ "DO", local \\ @root_checkpoint),
    do: replace_literal(graph, chi(local), sj(:authorityCeiling), RDF.literal(new))

  defp replace_literal(graph, subject, predicate, new_object) do
    old = graph |> RDF.Graph.get(subject) |> RDF.Description.first(predicate)
    graph = if old, do: RDF.Graph.delete(graph, {subject, predicate, old}), else: graph

    RDF.Graph.add(graph, {subject, predicate, new_object})
  end

  ## Runtime court harness against the REAL Xaas.Chicago.Court (R4) ###########

  @doc "Decide one Chicago case by identifier: the negative fact of that case law, everything else valid."
  def decide_case(case_id) do
    {request, policy} = case_request_and_policy(case_id)
    Court.decide(request, policy)
  end

  @doc "Per-case (request, policy): exactly one flipped input per negative case id, baseline otherwise."
  def case_request_and_policy("CHI-CASE-001"), do: {Court.bounded_purchase(), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-002"),
    do: {Court.bounded_purchase(%{amount: 150}), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-003"),
    do: {Court.bounded_purchase(%{principal: "principal-mallory"}), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-004"),
    do:
      {Court.bounded_purchase(),
       Court.baseline_policy(%{delegation_expires_at: ~U[2020-01-01 00:00:00Z]})}

  def case_request_and_policy("CHI-CASE-005"),
    do:
      {Court.bounded_purchase(%{provider_available: false, dispatch: nil, alternative_available: false}),
       Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-006"),
    do: {Court.bounded_purchase(%{dispatch: :unknown}), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-007"),
    do: {Court.bounded_purchase(%{evidence: nil}), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-008"),
    do:
      {Court.bounded_purchase(%{evidence: %{subject: @foreign_subject, kind: :exact_subject_observation}}),
       Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-009"),
    do: {Court.bounded_purchase(%{plan_policy_digest: "stale-policy-digest"}), Court.baseline_policy()}

  def case_request_and_policy("CHI-CASE-010"),
    do: {Court.bounded_purchase(%{authority_claim: "DO"}), Court.baseline_policy()}

  @doc "CHI-CASE-005 alternative branch: provider down BEFORE dispatch, an admitted alternative remains."
  def decide_provider_unavailable_alternative_preserved do
    {request, policy} =
      {Court.bounded_purchase(%{provider_available: false, dispatch: nil}), Court.baseline_policy()}

    Court.decide(request, policy)
  end

  @doc "The ORIGINAL consequence of the baseline bounded purchase."
  def original_consequence, do: Court.bounded_purchase().consequence

  @doc "reconcile/1 over the CHI-CASE-006 unknown-after-dispatch refusal."
  def reconcile_unknown_after_dispatch do
    Court.reconcile(decide_case("CHI-CASE-006"))
  end

  ## Assertion helpers ########################################################

  @doc "Refusal-shape conformance: `{:refused, atom, details}` with a contract atom and a map."
  def assert_refusal(result, expected_atom) do
    assert match?({:refused, _, _}, result),
           "expected a {:refused, atom, details} refusal, got: #{inspect(result)}"

    {:refused, atom, details} = result

    assert atom in @refusal_values,
           "refusal atom #{inspect(atom)} is outside the R4 contract #{inspect(@refusal_values)}"

    assert atom == expected_atom,
           "expected {:refused, #{inspect(expected_atom)}, _}, got: #{inspect(result)}"

    assert is_map(details), "refusal details must be a map, got: #{inspect(details)}"

    result
  end

  @doc "Positive control: the court admits as {:ok, _}."
  def assert_admitted(result) do
    assert match?({:ok, _}, result),
           "expected the positive control to admit as {:ok, _}, got: #{inspect(result)}"

    result
  end

  @doc "R8: even an admitted candidate outcome keeps standing UNKNOWN — never a promotion."
  def assert_standing_unknown({:ok, result} = admitted) do
    assert result[:standing] == "UNKNOWN",
           "expected candidate standing UNKNOWN, got: #{inspect(result)}"

    admitted
  end

  @doc "Standing law (R8): no court result ever mints ALIVE standing."
  def assert_no_standing_promotion(result) do
    refute match?({:ok, :alive}, result)
    refute match?({:ok, %{standing: :alive}}, result)
    refute match?({:ok, %{standing: "ALIVE"}}, result)
    refute match?({:ok, %{observed_standing: :alive}}, result)
    refute match?({:ok, %{observed_standing: "ALIVE"}}, result)
    refute match?({:ok, %{observedStanding: "ALIVE"}}, result)

    inspected = inspect(result)
    refute String.contains?(inspected, "ALIVE"),
           "court result must never mint ALIVE standing, got: #{inspected}"

    result
  end

  @doc "R4 determinism: two identical calls return identical results."
  def assert_deterministic(fun) when is_function(fun, 0) do
    a = fun.()
    b = fun.()

    assert a == b, "court must be deterministic (R4); got #{inspect(a)} then #{inspect(b)}"

    a
  end

  @doc "R4 reconcile/1: the ORIGINAL consequence, original-identity replay, zero new consequence, standing UNKNOWN."
  def assert_original_consequence_reconciled(result, original) do
    assert match?({:ok, _}, result),
           "expected reconcile to succeed with the original consequence, got: #{inspect(result)}"

    {:ok, reconciled} = result

    assert reconciled.consequence == original,
           "reconcile must return the ORIGINAL consequence unchanged, got: #{inspect(reconciled.consequence)}"

    assert reconciled.replay == :original_identity,
           "reconcile must never blind-replay, got replay: #{inspect(reconciled.replay)}"

    assert reconciled.standing == "UNKNOWN",
           "reconcile must not promote standing, got: #{inspect(reconciled.standing)}"

    result
  end
end
