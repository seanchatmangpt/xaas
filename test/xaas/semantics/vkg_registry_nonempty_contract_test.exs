defmodule Xaas.Semantics.VkgRegistryNonemptyContractTest do
  @moduledoc """
  Direct court over ash_r2rml's VKG registry non-empty-contract refusal
  (W706 trio gap fill; W625d/W378 lineage).

  `AshR2RML.VKG.Registry.admit/1` refuses `[]` and non-list inputs with a
  typed `AshR2RML.Refusal` rather than admitting an empty registry. Xaas's
  own surface (`Xaas.Semantics.VKG.observe_all/1`) exercises this edge only
  transitively (empty sources/ root -> REFUSED_VKG_MANIFEST, asserted in
  test/xaas/semantics/vkg_refusal_negative_test.exs). This test asserts the
  dependency-level fail-closed edge DIRECTLY, because it is the load-bearing
  fact in the structural proof that vkg.ex:52's `[] ->
  {:error, :REFUSED_VKG_EMPTY_CATALOG}` clause is dead:

    observe_all/1 (vkg.ex:38) is the only public entry binding `ids` through
    the `ids when ids != []` guard; the `:52` else-clause fires exactly on
    `[]`. Catalog.ids/1 = Map.keys(registry.contracts); Runtime.catalog/1 =
    Catalog.load/1 = Manifest.load_all -> Registry.admit. Since admit/1
    refuses [] (asserted below) and admits only non-empty contract lists
    into %{id => contract} maps, every {:ok, catalog} has >= 1 contract, so
    ids/1 can never yield [] and the :52 clause is unreachable defensive
    code. In-source documentation of the dead clause in lib/ is outside this
    lane's contract (test/ + plan doc only); this test file is the
    machine-greppable in-source carrier for the proof.
  """

  use ExUnit.Case, async: true

  alias AshR2RML.VKG.Registry

  describe "Registry.admit/1 non-empty contract" do
    test "empty contract list is refused with a typed Refusal" do
      assert {:error, %AshR2RML.Refusal{} = refusal} = Registry.admit([])

      assert refusal.code == :REFUSED_VKG_REGISTRY_AMBIGUOUS
      assert refusal.subject == :contracts
      assert refusal.detail == "VKG registry requires at least one contract"
      assert refusal.evidence == %{}
    end

    test "non-list input is refused with a typed Refusal" do
      for bad <- [%{}, "contracts", nil, 42] do
        assert {:error, %AshR2RML.Refusal{} = refusal} = Registry.admit(bad)

        assert refusal.code == :REFUSED_VKG_REGISTRY_AMBIGUOUS
        assert refusal.subject == :contracts
        assert refusal.detail == "VKG registry input must be a list"
      end
    end
  end
 end
