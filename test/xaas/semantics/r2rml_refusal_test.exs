defmodule Xaas.Semantics.R2RMLRefusalTest do
  @moduledoc """
  W176 delta closure, R2RML degenerate-resource refusals
  (`lib/xaas/semantics/r2rml.ex`).

  `REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY` (subject_map/1, r2rml.ex:185): an Ash
  resource without a primary key has no lawful R2RML semantic identity and is
  refused. `REFUSED_UNKNOWN_ATTRIBUTE` (predicate_object_maps/2, r2rml.ex:212)
  is documented as structurally unreachable through the public entry points —
  see the call-graph evidence in the module docstring note below.

  Method: real `Xaas.Resource` modules compiled in the test tree, real
  `Xaas.Semantics.Registry` admission, real ash_r2rml introspection. No DB rows
  (`mapping/1` never queries the database), no mocks.
  """

  use ExUnit.Case, async: true

  alias AshR2RML.Refusal
  alias Xaas.Semantics.R2RML

  defmodule NoPkResource do
    use Xaas.Resource,
      otp_app: :xaas,
      domain: Xaas.Billing,
      data_layer: AshPostgres.DataLayer

    postgres do
      table("r2rml_no_pk_resources")
      repo(Xaas.Repo)
    end

    resource do
      # Legitimately degenerate: this fixture exists to prove the R2RML
      # projection refuses a resource with no semantic identity at all.
      require_primary_key?(false)
    end

    attributes do
      attribute :name, :string do
        allow_nil?(false)
        public?(true)
      end
    end
  end

  test "a resource with no primary key refuses with REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY" do
    assert {:error,
            %Refusal{code: :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY, detail: detail} = refusal} =
             R2RML.mapping(NoPkResource)

    assert detail == "R2RML projection requires an admitted Ash primary key"
    assert refusal.subject == NoPkResource

    # The refusal propagates through the bundle facade unchanged.
    assert {:error, %Refusal{code: :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY}} =
             R2RML.bundle(NoPkResource)
  end

  # Local pk resource so the audit test is self-contained when only this file
  # (and not ash_r2rml_test.exs) is compiled/run.
  defmodule PkResource do
    use Xaas.Resource,
      otp_app: :xaas,
      domain: Xaas.Billing,
      data_layer: AshPostgres.DataLayer

    postgres do
      table("r2rml_pk_resources")
      repo(Xaas.Repo)
    end

    attributes do
      uuid_primary_key(:id)

      attribute :name, :string do
        allow_nil?(false)
        public?(true)
      end
    end
  end

  test "the same refusal is visible through audit standing, isolated from admitted resources" do
    audit = R2RML.audit([NoPkResource, PkResource])

    assert [
             %{
               resource: NoPkResource,
               reason: %Refusal{code: :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY}
             }
           ] =
             audit.refused

    assert [%{resource: PkResource, mapping_hash: hash, mapping_identity: ident}] =
             audit.admitted

    assert is_binary(hash) and ident != nil
  end
end
