defmodule Xaas.Governance.W984cy4OverrideDecisionCourtTest do
  @moduledoc """
  Lane W984cy4 depth court (v26.10.6): the most safety-relevant uncovered
  policy-support module in the governance checks/+policy-support class —
  `Xaas.Governance.Types.OverrideDecision`, the denied-party (sanctions)
  screening decision enum backing
  `Xaas.Governance.ApprovalDeniedPartyOverride.decision`.

  Census finding (this lane, method of docs/sjira/v26.10.6/plans/
  w984cj-coverage-map.md): all four non-excluded `lib/xaas/governance/
  checks/` modules already carry real direct courts (see the lane receipt
  for the module→test map), so the checks class contributed no court
  subject. `OverrideDecision` had zero direct test references; this court
  exercises its only live consumer as-real: authorized Ash actions over
  real sandboxed Postgres rows, real `Xaas.SystemAuthority` actors, typed
  Ash errors. No mocks, no GraphQL.

  Per-test mutation rationale is in each test's comment.
  """

  use ExUnit.Case, async: true

  alias Xaas.Governance.ApprovalDeniedPartyOverride
  alias Xaas.SystemAuthority

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org, do: "org-w984cy4-#{System.unique_integer([:positive])}"
  defp screening, do: "screening-w984cy4-#{System.unique_integer([:positive])}"
  defp actor, do: SystemAuthority.new(:internal_api)

  # Ash returns the outer splode error class struct (e.g. %Ash.Error.Invalid{})
  # whose `errors` list holds the field-keyed inner errors.
  defp inner_errors(%_{} = outer), do: Map.get(outer, :errors, [])
  defp inner_errors(list) when is_list(list), do: list

  defp field_error?(errors, field, substring \\ nil) do
    inner_errors(errors)
    |> Enum.any?(fn e ->
      is_map(e) and Map.get(e, :field) == field and
        (is_nil(substring) or (Map.get(e, :message) || "") =~ substring)
    end)
  end

  defp create_cs(decision, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          org_id: org(),
          requested_by: "requester-w984cy4",
          screening_record_id: screening(),
          decision: decision,
          justification: "manual review confirmed false positive match"
        },
        overrides
      )

    ApprovalDeniedPartyOverride
    |> Ash.Changeset.for_create(:create, attrs)
  end

  test "authorized create stores a cleared_to_proceed decision as the real typed enum atom" do
    # Mutation rationale: proves the sanctions-clearance path persists the
    # enum through storage with a real system actor (the only actor the
    # SystemActor bypass admits) and returns it as the typed atom, not a
    # string — the value later consumers branch on.
    assert {:ok, %ApprovalDeniedPartyOverride{} = record} =
             create_cs(:cleared_to_proceed)
             |> Ash.create(authorize?: true, actor: actor())

    assert record.decision == :cleared_to_proceed

    persisted = Ash.get!(ApprovalDeniedPartyOverride, record.id, authorize?: false)
    assert persisted.decision == :cleared_to_proceed
    assert persisted.approved_by == nil
  end

  test "confirmed_blocked decision survives the maker-checker approve unchanged" do
    # Mutation rationale: the maker-checker flow must not be able to flip
    # the filed decision — :approve accepts only :approved_by — and the
    # distinct-second-owner rule must hold on the same real row.
    org_id = org()

    assert {:ok, filed} =
             create_cs(:confirmed_blocked, %{org_id: org_id, requested_by: "requester-a"})
             |> Ash.create(authorize?: true, actor: actor())

    assert {:ok, approved} =
             filed
             |> Ash.Changeset.for_update(:approve, %{approved_by: "owner-b"})
             |> Ash.update(authorize?: true, actor: actor())

    assert approved.approved_by == "owner-b"

    persisted = Ash.get!(ApprovalDeniedPartyOverride, filed.id, authorize?: false)
    assert persisted.decision == :confirmed_blocked
    assert persisted.requested_by == "requester-a"
  end

  test "approving with the requester as the approver is refused by the distinct-owner rule" do
    # Mutation rationale: kills a mutation of RequiresApprover that drops
    # the distinct-owner comparison — a requester self-approving a
    # sanctions override would collapse maker-checker to maker-checker-less.
    assert {:ok, filed} =
             create_cs(:cleared_to_proceed, %{requested_by: "requester-self"})
             |> Ash.create(authorize?: true, actor: actor())

    assert {:error, _errors} =
             filed
             |> Ash.Changeset.for_update(:approve, %{approved_by: "requester-self"})
             |> Ash.update(authorize?: true, actor: actor())

    persisted = Ash.get!(ApprovalDeniedPartyOverride, filed.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "invalid decision value is refused with a typed enum error naming the field" do
    # Mutation rationale: kills a mutation of the enum's values list (e.g.
    # a rename drifting away from platform-console's OVERRIDE_DECISIONS) —
    # the constraint must refuse at storage with a typed, field-keyed error.
    assert {:error, errors} =
             create_cs("not_a_real_decision")
             |> Ash.create(authorize?: true, actor: actor())

    # Real Ash.Type.Enum rejection: typed, field-keyed, value-carrying.
    assert field_error?(errors, :decision, "is invalid")

    assert Enum.any?(inner_errors(errors), fn e ->
             is_map(e) and Map.get(e, :field) == :decision and
               Map.get(e, :value) == "not_a_real_decision"
           end)
  end

  test "nil decision is refused by allow_nil? and non-system actors hit the policy floor" do
    # Mutation rationale: two-layer guard in one court — (a) the enum
    # attribute may not be silently omitted (a decision-less sanctions
    # row is meaningless), and (b) the deny-by-default policy floor still
    # refuses non-system actors even though :create carries a SystemActor
    # bypass (the bypass is a carve-out, not an ambient allow).
    assert {:error, errors} =
             create_cs(:cleared_to_proceed, %{decision: nil})
             |> Ash.create(authorize?: true, actor: actor())

    assert field_error?(errors, :decision)

    assert {:error, _forbidden} =
             create_cs(:cleared_to_proceed)
             |> Ash.create(authorize?: true, actor: %{org_id: org()})
  end
end
