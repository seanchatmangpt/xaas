defmodule Xaas.Actuation.SpgGateTest do
  @moduledoc """
  Chicago-style depth court for `Xaas.Actuation.SpgGate` — the fail-closed
  Semantic Procedural Graph identity admission gate for consequential DO.

  Real invariants over real state (no mocks): gate-open/closed behavior of
  `admit/1` over real identity maps, the typed refusal shape at the exact
  boundary (`:spg_identity_required` / `:spg_not_admitted`), determinism of
  `fingerprint_token/1`, and the atom-key seam between `admit/1`'s
  projection and `fingerprint_token/1`. Mutation rationale per test: each
  test kills a specific mutant class, so flipping the fail-closed posture
  is caught.
  """

  use ExUnit.Case, async: true

  alias Xaas.Actuation.SpgGate

  defp admitted_identity(overrides \\ %{}) do
    Map.merge(
      %{
        "graph_id" => "spg-graph-1",
        "graph_version" => "v26.10.6",
        "node_id" => "node-a",
        "edge_id" => "edge-1",
        "state" => "ADMITTED",
        "projection_family" => "canonical-ash-projection-generator"
      },
      overrides
    )
  end

  defp atom_identity do
    %{
      graph_id: "spg-graph-1",
      graph_version: "v26.10.6",
      node_id: "node-a",
      edge_id: "edge-1",
      state: "ADMITTED",
      projection_family: "canonical-ash-projection-generator"
    }
  end

  test "admit/1 opens for a fully-admitted identity and projects exactly the gated fields" do
    # Mutation rationale: kills removal of any @required field (or
    # :projection_family/:state) from the returned take-list and any
    # widening of the projection shape; the gate must return the identity
    # it checked, not a wider or narrower map.
    identity = admitted_identity()

    assert {:ok, projected} = SpgGate.admit(identity)

    assert projected == %{
             graph_id: "spg-graph-1",
             graph_version: "v26.10.6",
             node_id: "node-a",
             edge_id: "edge-1",
             projection_family: "canonical-ash-projection-generator",
             state: "ADMITTED"
           }
  end

  test "admit/1 fails closed on every missing or empty required field, and on non-map input" do
    # Mutation rationale: kills any mutant that relaxes non_empty?/1 for
    # any single required field (accepting nil or "") — the fail-closed
    # posture is per-field, not aggregate — and kills removal of the
    # non-map head (`admit/1` returning :spg_identity_required for any
    # non-map term).
    for field <- [:graph_id, :graph_version, :node_id, :edge_id] do
      missing = Map.delete(admitted_identity(), Atom.to_string(field))
      assert {:error, :spg_identity_required} = SpgGate.admit(missing),
             "expected fail-closed on missing #{field}"

      empty = Map.put(admitted_identity(), Atom.to_string(field), "")
      assert {:error, :spg_identity_required} = SpgGate.admit(empty),
             "expected fail-closed on empty #{field}"
    end

    assert {:error, :spg_identity_required} = SpgGate.admit(nil)
    assert {:error, :spg_identity_required} = SpgGate.admit("ADMITTED")
  end

  test "admit/1's state vocabulary is exactly :admitted or uppercase ADMITTED; anything else is refused :spg_not_admitted" do
    # Mutation rationale: kills mutants that drop the state check entirely
    # (unadmitted graphs would flow to DO) and pins the exact accepted
    # vocabulary {:admitted, "ADMITTED"} — a case-normalizing mutant
    # (accepting "admitted") is killed by the refusal assertion on the
    # lowercase spelling.
    not_admitted = admitted_identity(%{"state" => "PENDING"})
    assert {:error, :spg_not_admitted} = SpgGate.admit(not_admitted)

    lowercase = admitted_identity(%{"state" => "admitted"})
    assert {:error, :spg_not_admitted} = SpgGate.admit(lowercase)

    for spelling <- [:admitted, "ADMITTED"] do
      assert {:ok, _} = SpgGate.admit(admitted_identity(%{"state" => spelling}))
    end
  end

  test "fingerprint_token/1 is deterministic over atom-keyed identities and projection_family-sensitive" do
    # Mutation rationale: kills mutants that drop a tuple component (a
    # fingerprint collision across distinct graphs would let one admitted
    # identity replay as another) or that reorder the tuple.
    token = SpgGate.fingerprint_token(atom_identity())

    assert token == SpgGate.fingerprint_token(atom_identity())

    assert token ==
             {"spg-graph-1", "v26.10.6", "node-a", "edge-1",
              "canonical-ash-projection-generator"}

    family_b = %{atom_identity() | projection_family: "other-family"}
    assert SpgGate.fingerprint_token(family_b) != token
  end

  test "seam: fingerprint_token/1 returns typed refusal on string-keyed input; admit/1's atom-keyed projection fingerprints identically to its atom-keyed source" do
    # Mutation rationale: pins the F2-refined (W984dq5 work order §2)
    # fail-closed boundary of the fingerprint seam — string-keyed
    # identities (the raw ontology/JSON shape) get the typed refusal
    # `{:error, :spg_fingerprint_atom_keyed}`, never a raise — and kills
    # drift between admit/1's check-surface and projection-surface.
    assert {:error, :spg_fingerprint_atom_keyed} =
             SpgGate.fingerprint_token(admitted_identity())

    assert {:error, :spg_fingerprint_atom_keyed} =
             SpgGate.fingerprint_token(%{"graph_id" => "g"})

    assert {:ok, projected} = SpgGate.admit(admitted_identity())
    assert SpgGate.fingerprint_token(projected) == SpgGate.fingerprint_token(atom_identity())
  end
end
