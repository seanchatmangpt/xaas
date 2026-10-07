defmodule Xaas.Chicago.NegativeCourts.GraphCourtsTest do
  @moduledoc """
  Lane L8 static graph courts (wave-1 design, file 1) over the admitted RDF
  source `docs/sjira/v26.10.1/chicago.ttl` + `goal.ttl`.

  Pins the candidate-only / authority-NONE / UNKNOWN-standing law of
  RESOLUTIONS.md R2+R8 directly on the source graph, and proves the courts
  NON-VACUOUS with in-memory mutants: each mutant flips exactly one source
  fact and must be flagged. A graph court that can never refuse carries no
  bits.

  This file is pure RDF.ex over the two source files — green without
  `Xaas.Chicago.Court` (no pending tags; runs in every suite).
  """

  use ExUnit.Case, async: true

  Code.require_file("support/mutants.ex", __DIR__)
  alias Xaas.Chicago.NegativeCourts.Mutants, as: M

  setup_all do
    %{chicago: M.read_chicago(), goal: M.read_goal()}
  end

  ## Conformance on the admitted source #######################################

  test "all 10 candidate cases exist typed sj:Prediction with the exact identifier set", %{
    chicago: chicago
  } do
    preds = M.prediction_subjects(chicago)
    assert length(preds) == 10

    ids = Enum.map(preds, &M.identifier(chicago, &1))
    assert Enum.sort(ids) == Enum.sort(M.case_identifiers())

    # contract sanity: every negative case id maps to a distinct R4 refusal atom
    atoms = Enum.map(tl(M.case_identifiers()), &M.case_refusal_atom/1)
    assert Enum.sort(atoms) == Enum.sort(M.refusal_values())
  end

  test "every case is candidateOnly true / authorityClaim NONE / observedStanding UNKNOWN / exact subject literal",
       %{
         chicago: chicago
       } do
    for subject <- M.prediction_subjects(chicago) do
      assert M.literal_object(chicago, subject, M.sj(:candidateOnly)) == RDF.literal(true)
      assert M.literal_object(chicago, subject, M.sj(:authorityClaim)) == RDF.literal("NONE")
      assert M.literal_object(chicago, subject, M.sj(:observedStanding)) == RDF.literal("UNKNOWN")

      object = M.literal_object(chicago, subject, M.sj(:subject))
      assert is_struct(object, RDF.Literal), "sj:subject objects are exact LITERALS (R2)"
      assert RDF.Literal.value(object) == M.subject()
    end
  end

  test "static graph court is conformant on the admitted source (no violations)", %{
    chicago: chicago
  } do
    assert M.chicago_graph_violations(chicago) == []
  end

  test "zero authored sj:WorkOrder and sj:Receipt in either source graph", %{
    chicago: chicago,
    goal: goal
  } do
    assert M.workorder_subjects(chicago) == []
    assert M.receipt_subjects(chicago) == []
    assert M.workorder_subjects(goal) == []
    assert M.receipt_subjects(goal) == []
  end

  test "goal graph: 12 layer checkpoints with stopQuery, ceiling CONSTRUCT, root hasPart 12", %{
    chicago: chicago,
    goal: goal
  } do
    assert M.goal_graph_violations(goal, chicago) == []

    root = M.chi(M.root_checkpoint_local())
    layers = M.checkpoint_subjects(goal) |> Enum.reject(&(&1 == root))
    assert length(layers) == 12

    for layer <- layers do
      stop = M.literal_object(goal, layer, M.sj(:stopQuery))
      assert is_struct(stop, RDF.Literal)
      assert stop |> RDF.Literal.value() |> to_string() |> String.contains?("ASK")
    end
  end

  ## Anti-vacuity mutants (each MUST be flagged) ###############################

  test "mutant: case observedStanding flipped to ALIVE is flagged", %{chicago: chicago} do
    mutant = M.mutate_standing(chicago, :"case-over-limit")
    assert {:standing_not_unknown, "CHI-CASE-002"} in M.chicago_graph_violations(mutant)
  end

  test "mutant: case authorityClaim flipped to DO is flagged", %{chicago: chicago} do
    mutant = M.mutate_authority_claim(chicago, :"case-wrong-principal")
    assert {:authority_claimed, "CHI-CASE-003"} in M.chicago_graph_violations(mutant)
  end

  test "mutant: foreign subject literal is flagged", %{chicago: chicago} do
    mutant = M.mutate_subject(chicago, :"case-stale-subject")
    assert {:subject_drift, "CHI-CASE-008"} in M.chicago_graph_violations(mutant)
  end

  test "mutant: IRI-typed subject object violates the literal-only law", %{chicago: chicago} do
    mutant = M.mutate_subject_to_iri(chicago, :"case-stale-subject")
    assert {:subject_not_literal, "CHI-CASE-008"} in M.chicago_graph_violations(mutant)
  end

  test "mutant: injected sj:WorkOrder is flagged", %{chicago: chicago} do
    mutant = M.inject_workorder(chicago, :"case-over-limit")
    assert {:authored_workorder, 1} in M.goal_graph_violations(M.read_goal(), mutant)
  end

  test "mutant: injected sj:Receipt is flagged", %{chicago: chicago} do
    mutant = M.inject_receipt(M.read_goal(), :"layer-sjira")
    assert {:authored_receipt, 1} in M.goal_graph_violations(mutant, chicago)
  end

  test "mutant: authority ceiling widened past CONSTRUCT is flagged", %{chicago: chicago} do
    mutant = M.mutate_ceiling(M.read_goal())

    assert {:authority_ceiling, "GC-XAAS-26.10.1-CHICAGO", "DO"} in M.goal_graph_violations(
             mutant,
             chicago
           )
  end
end
