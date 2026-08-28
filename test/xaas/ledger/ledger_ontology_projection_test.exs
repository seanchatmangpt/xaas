defmodule Xaas.Ledger.LedgerOntologyProjectionTest do
  @moduledoc """
  Chicago-style qualification of the real public-ontology projection contract
  (`Xaas.Resource`'s `ontology_projection!/0`/`ontology_projection_hash/0`) for the
  Ledger domain.

  Before this file, `test/xaas/ledger/` did not exist -- `Xaas.Ledger.Balance`,
  `Xaas.Ledger.Account`, and `Xaas.Ledger.Transfer` had zero dedicated tests despite
  `/Users/sac/xaas/CLAUDE.md` naming the Ledger domain a "deliberate exposure
  decision" that warrants care. This exercises the real `AshR2RML`-delegated mapping
  path (`Xaas.Semantics.Registry.r2rml_mapping/1`) against these three real resources
  for the first time -- they use non-trivial primary-key/attribute types
  (`AshDoubleEntry.ULID`, `:money`) that the Provider-only coverage in
  `Xaas.ActuationTest` never exercised.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ledger.{Account, Balance, Transfer}
  alias Xaas.Semantics.Registry

  for resource <- [Account, Balance, Transfer] do
    describe "#{inspect(resource)}" do
      test "admits a real public-ontology projection with only public IRIs" do
        assert {:ok, projection} = Registry.admit(unquote(resource))

        iris =
          projection.classes ++
            Enum.map(projection.attributes, & &1.predicate) ++
            Enum.map(projection.relationships, & &1.predicate)

        assert iris != []
        assert Enum.all?(iris, &Registry.public_iri?/1)
      end

      test "resolves a real ash_r2rml R2RML mapping with a logical table bound to its real Postgres table" do
        assert {:ok, mapping} = Registry.r2rml_mapping(unquote(resource))

        assert %AshR2RML.Mapping.LogicalTable{table_name: table} = mapping.logical_table
        assert is_binary(table) and table != ""
      end

      test "ontology_projection_hash/0 is deterministic across repeated calls" do
        assert unquote(resource).ontology_projection_hash() ==
                 unquote(resource).ontology_projection_hash()
      end
    end
  end

  test "Balance is projected as a schema:MonetaryAmount" do
    assert "https://schema.org/MonetaryAmount" in Balance.ontology_projection!().classes
  end

  test "Transfer is projected as both a schema:MoneyTransfer and a prov:Activity" do
    classes = Transfer.ontology_projection!().classes

    assert "https://schema.org/MoneyTransfer" in classes
    assert "http://www.w3.org/ns/prov#Activity" in classes
  end
end
