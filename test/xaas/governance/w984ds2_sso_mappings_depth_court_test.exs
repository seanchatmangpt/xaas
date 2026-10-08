defmodule Xaas.Governance.W984ds2SsoMappingsDepthCourtTest do
  @moduledoc """
  W984ds2 lane — depth court for
  `Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings`
  (75 lines) through its live consumer resource
  `Xaas.Governance.ApprovalSsoRoleMappingUpdate` `:create` action.

  The existing coverage is HTTP-level and single-scenario (one invalid
  role via the controller test); this court drives the real resource
  action against real sandboxed Postgres and pins every branch of the
  validation: cap, entry shape, duplicate, happy path, and the
  non-list type guard. Real Postgres, real Ash actions, zero mocks.
  """
  use ExUnit.Case, async: true

  alias Xaas.Governance.ApprovalSsoRoleMappingUpdate

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_attrs(mappings) do
    %{
      org_id: "org-sso-#{System.unique_integer([:positive])}",
      requested_by: "requester-#{System.unique_integer([:positive])}",
      requested_mappings: mappings
    }
  end

  defp create(attrs), do:
    ApprovalSsoRoleMappingUpdate
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(authorize?: false)

  defp mapping_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.filter(errors, fn
      %{field: :requested_mappings} -> true
      _ -> false
    end)
  end

  test "valid mapping set passes the real action and round-trips through Postgres" do
    attrs =
      create_attrs([
        %{"ssoGroup" => "eng", "role" => "member"},
        %{"ssoGroup" => "exec", "role" => "owner"}
      ])

    assert {:ok, record} = create(attrs)

    re_read = Ash.get!(ApprovalSsoRoleMappingUpdate, record.id, authorize?: false)
    assert length(re_read.requested_mappings) == 2

    assert Enum.any?(re_read.requested_mappings, fn m ->
      is_map(m) and (m["ssoGroup"] == "eng" or m[:ssoGroup] == "eng")
    end)
  end

  test "role outside OrgRole refused with typed message; nothing persisted" do
    attrs =
      create_attrs([
        %{"ssoGroup" => "eng", "role" => "admin"}
      ])

    assert {:error, %Ash.Error.Invalid{} = error} = create(attrs)

    assert [
             %{message: "role must be one of: viewer, member, owner"} | _
           ] = mapping_errors(error)

    persisted =
      ApprovalSsoRoleMappingUpdate
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == attrs.org_id))

    assert persisted == []
  end

  test "ssoGroup violations: empty via non-map entry, and 257-char name, both typed-refused" do
    long_group = String.duplicate("g", 257)
    assert {:error, %Ash.Error.Invalid{} = err1} =
             create(create_attrs([%{"ssoGroup" => long_group, "role" => "viewer"}]))

    assert [%{message: "ssoGroup is required and must be at most 256 characters"} | _] =
             mapping_errors(err1)

    # The non-map-entry branch (normalize_entry -> %{} -> empty ssoGroup) is
    # unreachable through normal casting ({:array, :map} rejects non-maps at
    # cast time), so it is courted directly against the real validation on a
    # real changeset, bypassing only the cast.
    alias Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings

    cs =
      ApprovalSsoRoleMappingUpdate
      |> Ash.Changeset.for_create(:create, create_attrs([%{"ssoGroup" => "eng", "role" => "viewer"}]))
      |> then(fn cs -> %{cs | attributes: Map.put(cs.attributes, :requested_mappings, [42])} end)

    assert {:error,
            [field: :requested_mappings, message: "ssoGroup is required and must be at most 256 characters"]} =
             ApprovalSsoRoleMappingUpdateValidMappings.validate(cs, [], %{})
  end

  test "duplicate ssoGroup in the same submitted set refused; distinct groups pass" do
    dup = %{"ssoGroup" => "eng-#{System.unique_integer([:positive])}", "role" => "viewer"}

    assert {:error, %Ash.Error.Invalid{} = err} =
             create(create_attrs([dup, dup]))

    assert [%{message: msg} | _] = mapping_errors(err)
    assert msg =~ "duplicate ssoGroup in mapping set"

    # Distinct groups with the same role pass — proving the duplicate
    # clause keys on ssoGroup, not the whole entry.
    g1 = "eng-#{System.unique_integer([:positive])}"
    g2 = "eng-#{System.unique_integer([:positive])}"

    assert {:ok, _} = create(create_attrs([
      %{"ssoGroup" => g1, "role" => "viewer"},
      %{"ssoGroup" => g2, "role" => "viewer"}
    ]))
  end

  test "boundary cap: 100 entries pass, 101 refused with the typed cap message; non-list payload refused" do
    group = "eng-#{System.unique_integer([:positive])}"

    ok_entries =
      Enum.map(1..100, fn i -> %{"ssoGroup" => "#{group}-#{i}", "role" => "viewer"} end)

    assert {:ok, _} = create(create_attrs(ok_entries))

    over_entries =
      Enum.map(1..101, fn i -> %{"ssoGroup" => "#{group}-x-#{i}", "role" => "viewer"} end)

    assert {:error, %Ash.Error.Invalid{} = err} = create(create_attrs(over_entries))

    assert [%{message: "must contain at most 100 entries"} | _] = mapping_errors(err)

    # The non-list branch is unreachable through normal casting ({:array,
    # :map} rejects non-lists at cast time, and force_change_attribute
    # still casts); prove the validation's own type guard is real and
    # fail-closed by calling it directly on a real changeset bypassing
    # only the cast.
    alias Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings

    cs =
      ApprovalSsoRoleMappingUpdate
      |> Ash.Changeset.for_create(:create, create_attrs([%{"ssoGroup" => "eng", "role" => "viewer"}]))
      |> then(fn cs -> %{cs | attributes: Map.put(cs.attributes, :requested_mappings, "not-a-list")} end)

    assert {:error, [field: :requested_mappings, message: "must be an array"]} =
             ApprovalSsoRoleMappingUpdateValidMappings.validate(cs, [], %{})
  end
end
